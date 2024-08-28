// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PreMarketsStorage} from "../storage/PreMarketsStorage.sol";
import {OfferStatus, AbortOfferStatus, OfferType, OfferSettleType} from "../storage/OfferStatus.sol";
import {HoldingStatus, HoldingType} from "../storage/OfferStatus.sol";
import {ITadleFactory} from "../factory/ITadleFactory.sol";
import {ITokenManager, TokenBalanceType} from "../interfaces/ITokenManager.sol";
import {ISystemConfig, MarketplaceInfo, MarketplaceStatus, ReferralInfo} from "../interfaces/ISystemConfig.sol";
import {IPreMarkets, OfferInfo, HoldingInfo, MakerInfo, CreateOfferParams} from "../interfaces/IPreMarkets.sol";
import {IWrappedNativeToken} from "../interfaces/IWrappedNativeToken.sol";
import {RelatedContractLibraries} from "../libraries/RelatedContractLibraries.sol";
import {MarketplaceLibraries} from "../libraries/MarketplaceLibraries.sol";
import {OfferLibraries} from "../libraries/OfferLibraries.sol";
import {GenerateAddress} from "../libraries/GenerateAddress.sol";
import {Constants} from "../libraries/Constants.sol";
import {Rescuable} from "../utils/Rescuable.sol";
import {Related} from "../utils/Related.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title PreMarkets
 * @dev The contract contains all trading actions from the time the market goes live until delivery.
 *      such as create offer, create holding, list offer, close offer,
 *      relist offer, abort ask offer, abort bid holding, rollin etc.
 */
contract PreMarkets is
    PreMarketsStorage,
    ReentrancyGuard,
    Rescuable,
    Related,
    IPreMarkets
{
    using Math for uint256;
    using RelatedContractLibraries for ITadleFactory;
    using MarketplaceLibraries for MarketplaceInfo;

    constructor() Rescuable() {}

    /**
     * @notice Create offer
     * @dev Params must be valid, details in CreateOfferParams
     * @dev ProjectPoints and quoteTokenAmount must be greater than 0
     */
    function createOffer(
        CreateOfferParams calldata params
    ) external payable whenNotPaused nonReentrant {
        /**
         * @dev ProjectPoints and quoteTokenAmount must be greater than 0
         * @dev EachTradeTax must be less than 20%, decimal scaler is 10000
         * @dev CollateralRate must be more than 100%, decimal scaler is 10000
         */
        if (params.projectPoints == 0x0 || params.quoteTokenAmount == 0x0) {
            revert Errors.AmountIsZero();
        }

        if (params.eachTradeTax > Constants.EACH_TRADE_TAX_MAXINUM) {
            revert InvalidEachTradeTaxRate(params.eachTradeTax);
        }

        if (params.collateralRate < Constants.COLLATERAL_RATE_DECIMAL_SCALER) {
            revert InvalidCollateralRate(params.collateralRate);
        }

        /// @dev The market must be online
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();
        MarketplaceInfo memory marketPlaceInfo = systemConfig
            .getMarketplaceInfo(params.marketPlace);
        marketPlaceInfo.checkMarketplaceStatus(
            block.timestamp,
            MarketplaceStatus.Online
        );

        offerId = offerId + 1;

        /// @dev Generate address for maker, offer, holding.
        address makerAddr = GenerateAddress.generateMakerAddress(offerId);
        address offerAddr = GenerateAddress.generateOfferAddress(offerId);
        address holdingAddr = GenerateAddress.generateHoldingAddress(offerId);

        /// @dev Maker, Offer, Holding must not initialized.
        if (makerInfoMap[makerAddr].authority != address(0x0)) {
            revert MakerAlreadyExist();
        }

        if (offerInfoMap[offerAddr].authority != address(0x0)) {
            revert OfferAlreadyExist();
        }

        if (holdingInfoMap[holdingAddr].authority != address(0x0)) {
            revert HoldingAlreadyExist();
        }

        {
            /// @dev Transfer collateral from msg.sender to capital pool
            uint256 collateralAmount = OfferLibraries
                .getDepositCollateralAmount(
                    params.offerType,
                    params.collateralRate,
                    params.quoteTokenAmount,
                    true,
                    Math.Rounding.Up
                );

            ITokenManager tokenManager = tadleFactory.getTokenManager();
            tokenManager.deposit{value: msg.value}(
                msg.sender,
                params.collateralTokenAddr,
                collateralAmount,
                false
            );
        }

        /// @dev Update maker info
        makerInfoMap[makerAddr] = MakerInfo({
            offerSettleType: params.offerSettleType,
            authority: msg.sender,
            marketPlace: params.marketPlace,
            collateralTokenAddr: params.collateralTokenAddr,
            originOffer: offerAddr,
            eachTradeTax: params.eachTradeTax
        });

        /// @dev Update offer info
        offerInfoMap[offerAddr] = OfferInfo({
            offerId: offerId,
            authority: msg.sender,
            maker: makerAddr,
            offerStatus: OfferStatus.Virgin,
            offerType: params.offerType,
            projectPoints: params.projectPoints,
            quoteTokenAmount: params.quoteTokenAmount,
            collateralRate: params.collateralRate,
            abortOfferStatus: AbortOfferStatus.Initialized,
            usedProjectPoints: 0,
            tradeTax: 0,
            settledProjectPoints: 0,
            settledPointTokenAmount: 0,
            settledCollateralAmount: 0
        });

        /// @dev Update holding info
        holdingInfoMap[holdingAddr] = HoldingInfo({
            holdingId: offerId,
            holdingStatus: HoldingStatus.Initialized,
            holdingType: params.offerType == OfferType.Ask
                ? HoldingType.Bid
                : HoldingType.Ask,
            authority: msg.sender,
            maker: makerAddr,
            preOffer: address(0x0),
            offer: offerAddr,
            projectPoints: params.projectPoints,
            quoteTokenAmount: params.quoteTokenAmount
        });

        emit CreateOffer(
            offerAddr,
            makerAddr,
            holdingAddr,
            params.marketPlace,
            msg.sender,
            params.projectPoints,
            params.quoteTokenAmount
        );
    }

    /**
     * @notice Create holding
     * @param _offer The offer address
     * @param _projectPoints The projectPoints of holding
     */
    function createHolding(
        address _offer,
        uint256 _projectPoints
    ) external payable whenNotPaused nonReentrant {
        /**
         * @dev Offer must be virgin
         * @dev Points must be greater than 0
         * @dev Total projectPoints must be greater than `usedProjectPoints + _projectPoints`
         */
        if (_projectPoints == 0x0) {
            revert Errors.AmountIsZero();
        }

        OfferInfo storage offerInfo = offerInfoMap[_offer];
        MakerInfo storage makerInfo = makerInfoMap[offerInfo.maker];
        if (offerInfo.offerStatus != OfferStatus.Virgin) {
            revert InvalidOfferStatus();
        }

        if (
            offerInfo.projectPoints <
            _projectPoints + offerInfo.usedProjectPoints
        ) {
            revert NotEnoughPoints(
                offerInfo.projectPoints,
                offerInfo.usedProjectPoints,
                _projectPoints
            );
        }

        /// @dev The market must be online
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();
        {
            MarketplaceInfo memory marketPlaceInfo = systemConfig
                .getMarketplaceInfo(makerInfo.marketPlace);
            marketPlaceInfo.checkMarketplaceStatus(
                block.timestamp,
                MarketplaceStatus.Online
            );
        }

        ReferralInfo memory referralInfo = systemConfig.getReferralInfo(
            msg.sender
        );

        uint256 platformFeeRate = systemConfig.getPlatformFeeRate(msg.sender);

        offerId = offerId + 1;
        /// @dev Generate holding address
        address holdingAddr = GenerateAddress.generateHoldingAddress(offerId);
        if (holdingInfoMap[holdingAddr].authority != address(0x0)) {
            revert HoldingAlreadyExist();
        }

        /// @dev Transfer token from user to capital pool as collateral
        uint256 quoteTokenAmount = _projectPoints.mulDiv(
            offerInfo.quoteTokenAmount,
            offerInfo.projectPoints,
            Math.Rounding.Up
        );
        uint256 platformFee = quoteTokenAmount.mulDiv(
            platformFeeRate,
            Constants.PLATFORM_FEE_DECIMAL_SCALER
        );
        uint256 tradeTax = quoteTokenAmount.mulDiv(
            makerInfo.eachTradeTax,
            Constants.EACH_TRADE_TAX_DECIMAL_SCALER
        );

        ITokenManager tokenManager = tadleFactory.getTokenManager();
        _depositTokenWhenCreateHolding(
            platformFee,
            quoteTokenAmount,
            tradeTax,
            makerInfo,
            offerInfo,
            tokenManager
        );

        offerInfo.usedProjectPoints =
            offerInfo.usedProjectPoints +
            _projectPoints;

        /// @dev Update holding info
        holdingInfoMap[holdingAddr] = HoldingInfo({
            holdingId: offerId,
            holdingStatus: HoldingStatus.Initialized,
            holdingType: offerInfo.offerType == OfferType.Ask
                ? HoldingType.Bid
                : HoldingType.Ask,
            authority: msg.sender,
            maker: offerInfo.maker,
            preOffer: _offer,
            projectPoints: _projectPoints,
            quoteTokenAmount: quoteTokenAmount,
            offer: address(0x0)
        });

        uint256 remainingPlatformFee = _updateReferralBonus(
            platformFee,
            quoteTokenAmount,
            holdingAddr,
            makerInfo,
            referralInfo,
            tokenManager
        );

        _updateTokenBalanceWhenCreateHolding(
            _offer,
            tradeTax,
            quoteTokenAmount,
            remainingPlatformFee,
            offerInfo,
            makerInfo,
            tokenManager
        );

        emit CreateHolding(
            _offer,
            msg.sender,
            holdingAddr,
            _projectPoints,
            quoteTokenAmount,
            tradeTax,
            remainingPlatformFee
        );
    }

    /**
     * @dev List holding
     * @param _holding Holding address
     * @param _quoteTokenAmount The amount of offer
     * @param _collateralRate Offer collateral rate
     * @dev Only holding owner can list offer
     * @dev The market must be online
     * @dev Only ask offer can be listed
     */
    function listHolding(
        address _holding,
        uint256 _quoteTokenAmount,
        uint256 _collateralRate
    ) external payable whenNotPaused nonReentrant {
        if (_quoteTokenAmount == 0x0) {
            revert Errors.AmountIsZero();
        }

        if (_collateralRate < Constants.COLLATERAL_RATE_DECIMAL_SCALER) {
            revert InvalidCollateralRate(_collateralRate);
        }

        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];
        if (msg.sender != holdingInfo.authority) {
            revert Errors.Unauthorized();
        }

        OfferInfo storage offerInfo = offerInfoMap[holdingInfo.preOffer];
        MakerInfo storage makerInfo = makerInfoMap[offerInfo.maker];

        /// @dev The market must be online
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();
        MarketplaceInfo memory marketPlaceInfo = systemConfig
            .getMarketplaceInfo(makerInfo.marketPlace);

        marketPlaceInfo.checkMarketplaceStatus(
            block.timestamp,
            MarketplaceStatus.Online
        );

        if (holdingInfo.offer != address(0x0)) {
            revert OfferAlreadyExist();
        }

        if (holdingInfo.holdingType != HoldingType.Bid) {
            revert InvalidHoldingType(HoldingType.Bid, holdingInfo.holdingType);
        }

        /// @dev Change abort offer status when offer settle type is `turbo`
        if (makerInfo.offerSettleType == OfferSettleType.Turbo) {
            address originOffer = makerInfo.originOffer;
            OfferInfo storage originOfferInfo = offerInfoMap[originOffer];

            if (_collateralRate != originOfferInfo.collateralRate) {
                revert InvalidCollateralRate(_collateralRate);
            }
            originOfferInfo.abortOfferStatus = AbortOfferStatus.AllocationPropagated;
        }

        /// @dev Transfer collateral when offer settle type is `protected`
        if (makerInfo.offerSettleType == OfferSettleType.Protected) {
            uint256 collateralAmount = OfferLibraries
                .getDepositCollateralAmount(
                    offerInfo.offerType,
                    _collateralRate,
                    _quoteTokenAmount,
                    true,
                    Math.Rounding.Up
                );

            ITokenManager tokenManager = tadleFactory.getTokenManager();
            tokenManager.deposit{value: msg.value}(
                msg.sender,
                makerInfo.collateralTokenAddr,
                collateralAmount,
                false
            );
        }

        address offerAddr = GenerateAddress.generateOfferAddress(
            holdingInfo.holdingId
        );
        if (offerInfoMap[offerAddr].authority != address(0x0)) {
            revert OfferAlreadyExist();
        }

        /// @dev Update offer info
        offerInfoMap[offerAddr] = OfferInfo({
            offerId: holdingInfo.holdingId,
            authority: msg.sender,
            maker: offerInfo.maker,
            offerStatus: OfferStatus.Virgin,
            offerType: offerInfo.offerType,
            abortOfferStatus: AbortOfferStatus.Initialized,
            projectPoints: holdingInfo.projectPoints,
            quoteTokenAmount: _quoteTokenAmount,
            collateralRate: _collateralRate,
            usedProjectPoints: 0,
            tradeTax: 0,
            settledProjectPoints: 0,
            settledPointTokenAmount: 0,
            settledCollateralAmount: 0
        });

        holdingInfo.offer = offerAddr;

        emit ListHolding(
            offerAddr,
            _holding,
            msg.sender,
            holdingInfo.projectPoints,
            _quoteTokenAmount
        );
    }

    /**
     * @notice Close offer
     * @param _holding Holding address
     * @param _offer Offer address
     * @notice Only offer owner can close offer
     * @dev The market must be online
     * @dev Only offer status is virgin can be closed
     */
    function closeOffer(
        address _holding,
        address _offer
    ) external whenNotPaused nonReentrant {
        OfferInfo storage offerInfo = offerInfoMap[_offer];
        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];

        if (holdingInfo.offer != _offer) {
            revert InvalidOfferAccount(holdingInfo.offer, _offer);
        }

        if (offerInfo.authority != msg.sender) {
            revert Errors.Unauthorized();
        }

        if (offerInfo.offerStatus != OfferStatus.Virgin) {
            revert InvalidOfferStatus();
        }

        MakerInfo storage makerInfo = makerInfoMap[offerInfo.maker];
        /// @dev The market must be online
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();
        MarketplaceInfo memory marketPlaceInfo = systemConfig
            .getMarketplaceInfo(makerInfo.marketPlace);

        marketPlaceInfo.checkMarketplaceStatus(
            block.timestamp,
            MarketplaceStatus.Online
        );

        /**
         * @dev Update refund token from capital pool to balance
         * @dev The `offerSettleType` is `protected` or the offer is the original offer
         */
        if (
            makerInfo.offerSettleType == OfferSettleType.Protected ||
            holdingInfo.preOffer == address(0x0)
        ) {
            uint256 refundCollateralAmount = OfferLibraries
                .getRefundCollateralAmount(
                    offerInfo.offerType,
                    offerInfo.quoteTokenAmount,
                    offerInfo.projectPoints,
                    offerInfo.usedProjectPoints,
                    offerInfo.collateralRate
                );

            ITokenManager tokenManager = tadleFactory.getTokenManager();
            tokenManager.addTokenBalance(
                TokenBalanceType.MakerRefund,
                msg.sender,
                makerInfo.collateralTokenAddr,
                refundCollateralAmount
            );
        }

        offerInfo.offerStatus = OfferStatus.Canceled;
        emit CloseOffer(_offer, msg.sender);
    }

    /**
     * @notice Relist offer
     * @param _holding Holding address
     * @param _offer Offer address
     * @notice Only offer owner can relist offer
     * @dev The market must be online
     * @dev Only offer status is canceled can be relisted
     */
    function relistHolding(
        address _holding,
        address _offer
    ) external payable whenNotPaused nonReentrant {
        OfferInfo storage offerInfo = offerInfoMap[_offer];
        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];

        if (holdingInfo.offer != _offer) {
            revert InvalidOfferAccount(holdingInfo.offer, _offer);
        }

        if (offerInfo.authority != msg.sender) {
            revert Errors.Unauthorized();
        }

        if (offerInfo.offerStatus != OfferStatus.Canceled) {
            revert InvalidOfferStatus();
        }

        /// @dev The market must be online
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();

        MakerInfo storage makerInfo = makerInfoMap[offerInfo.maker];
        MarketplaceInfo memory marketPlaceInfo = systemConfig
            .getMarketplaceInfo(makerInfo.marketPlace);

        marketPlaceInfo.checkMarketplaceStatus(
            block.timestamp,
            MarketplaceStatus.Online
        );

        /**
         * @dev Transfer refund token from user to capital pool
         * @dev The `offerSettleType` is `protected` or the offer is the original offer
         */
        if (
            makerInfo.offerSettleType == OfferSettleType.Protected ||
            holdingInfo.preOffer == address(0x0)
        ) {
            uint256 collateralAmount = OfferLibraries.getRefundCollateralAmount(
                offerInfo.offerType,
                offerInfo.quoteTokenAmount,
                offerInfo.projectPoints,
                offerInfo.usedProjectPoints,
                offerInfo.collateralRate
            );

            ITokenManager tokenManager = tadleFactory.getTokenManager();
            tokenManager.deposit{value: msg.value}(
                msg.sender,
                makerInfo.collateralTokenAddr,
                collateralAmount,
                false
            );
        }

        /// @dev update offer status to virgin
        offerInfo.offerStatus = OfferStatus.Virgin;
        emit RelistHolding(_offer, msg.sender);
    }

    /**
     * @notice Abort ask offer
     * @param _holding Holding address
     * @param _offer Offer address
     * @notice Only offer owner can abort ask offer
     * @dev Only offer status is virgin or canceled can be aborted
     * @dev The market must be online
     */
    function abortAskOffer(
        address _holding,
        address _offer
    ) external whenNotPaused nonReentrant {
        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];
        OfferInfo storage offerInfo = offerInfoMap[_offer];

        if (offerInfo.authority != msg.sender) {
            revert Errors.Unauthorized();
        }

        if (holdingInfo.offer != _offer) {
            revert InvalidOfferAccount(holdingInfo.offer, _offer);
        }

        if (offerInfo.offerType != OfferType.Ask) {
            revert InvalidOfferType(OfferType.Ask, offerInfo.offerType);
        }

        if (offerInfo.abortOfferStatus != AbortOfferStatus.Initialized) {
            revert InvalidAbortOfferStatus(
                AbortOfferStatus.Initialized,
                offerInfo.abortOfferStatus
            );
        }

        if (
            offerInfo.offerStatus != OfferStatus.Virgin &&
            offerInfo.offerStatus != OfferStatus.Canceled
        ) {
            revert InvalidOfferStatus();
        }

        MakerInfo storage makerInfo = makerInfoMap[offerInfo.maker];

        if (
            makerInfo.offerSettleType == OfferSettleType.Turbo &&
            holdingInfo.preOffer != address(0x0)
        ) {
            revert InvalidOffer();
        }

        /// @dev The market must be online
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();
        MarketplaceInfo memory marketPlaceInfo = systemConfig
            .getMarketplaceInfo(makerInfo.marketPlace);
        marketPlaceInfo.checkMarketplaceStatus(
            block.timestamp,
            MarketplaceStatus.Online
        );

        uint256 remainingAmount;
        if (offerInfo.offerStatus == OfferStatus.Virgin) {
            remainingAmount = offerInfo.quoteTokenAmount;
        } else {
            remainingAmount = offerInfo.quoteTokenAmount.mulDiv(
                offerInfo.usedProjectPoints,
                offerInfo.projectPoints,
                Math.Rounding.Down
            );
        }

        uint256 remainingCollateralAmount = OfferLibraries
            .getDepositCollateralAmount(
                offerInfo.offerType,
                offerInfo.collateralRate,
                remainingAmount,
                true,
                Math.Rounding.Down
            );
        uint256 totalUsedQuoteTokenAmount = offerInfo.quoteTokenAmount.mulDiv(
            offerInfo.usedProjectPoints,
            offerInfo.projectPoints,
            Math.Rounding.Up
        );
        uint256 totalUsedCollateralAmount = OfferLibraries
            .getDepositCollateralAmount(
                offerInfo.offerType,
                offerInfo.collateralRate,
                totalUsedQuoteTokenAmount,
                false,
                Math.Rounding.Up
            );

        ///@dev Update refund amount for offer's owner
        uint256 makerRefundAmount;
        if (remainingCollateralAmount > totalUsedCollateralAmount) {
            makerRefundAmount =
                remainingCollateralAmount -
                totalUsedCollateralAmount;
        } else {
            makerRefundAmount = uint256(0x0);
        }

        ITokenManager tokenManager = tadleFactory.getTokenManager();
        tokenManager.addTokenBalance(
            TokenBalanceType.MakerRefund,
            msg.sender,
            makerInfo.collateralTokenAddr,
            makerRefundAmount
        );

        offerInfo.abortOfferStatus = AbortOfferStatus.Aborted;
        offerInfo.offerStatus = OfferStatus.Settled;

        emit AbortAskOffer(_offer, msg.sender);
    }

    /**
     * @notice Abort bid holding
     * @param _holding Holding address
     * @param _offer Offer address
     * @notice Only holding owner can abort bid holding
     * @dev Only offer abort status is aborted can be aborted
     * @dev Update holding's refund amount
     */
    function abortBidHolding(
        address _holding,
        address _offer
    ) external whenNotPaused nonReentrant {
        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];
        OfferInfo storage preOfferInfo = offerInfoMap[_offer];

        if (holdingInfo.authority != msg.sender) {
            revert Errors.Unauthorized();
        }

        if (holdingInfo.preOffer != _offer) {
            revert InvalidOfferAccount(holdingInfo.preOffer, _offer);
        }

        if (holdingInfo.holdingStatus != HoldingStatus.Initialized) {
            revert InvalidHoldingStatus(
                HoldingStatus.Initialized,
                holdingInfo.holdingStatus
            );
        }

        if (preOfferInfo.abortOfferStatus != AbortOfferStatus.Aborted) {
            revert InvalidAbortOfferStatus(
                AbortOfferStatus.Aborted,
                preOfferInfo.abortOfferStatus
            );
        }

        uint256 quoteTokenAmount = holdingInfo.projectPoints.mulDiv(
            preOfferInfo.quoteTokenAmount,
            preOfferInfo.projectPoints,
            Math.Rounding.Down
        );

        uint256 collateralAmount = OfferLibraries.getDepositCollateralAmount(
            preOfferInfo.offerType,
            preOfferInfo.collateralRate,
            quoteTokenAmount,
            false,
            Math.Rounding.Down
        );

        MakerInfo storage makerInfo = makerInfoMap[preOfferInfo.maker];
        ITokenManager tokenManager = tadleFactory.getTokenManager();
        tokenManager.addTokenBalance(
            TokenBalanceType.RemainingCash,
            msg.sender,
            makerInfo.collateralTokenAddr,
            collateralAmount
        );

        holdingInfo.holdingStatus = HoldingStatus.Finished;

        emit AbortBidHolding(_offer, _holding, msg.sender);
    }

    /**
     * @notice rollin
     * @dev set rollin timestamp
     */
    function rollin() external whenNotPaused {
        if (rollinAtMap[msg.sender] + 1 hours > block.timestamp) {
            revert Errors.RollinTooSoon(rollinAtMap[msg.sender]);
        }
        rollinAtMap[msg.sender] = block.timestamp;
        emit Rollin(msg.sender, block.timestamp);
    }

    /**
     * @dev Update offer status
     * @notice Only called by DeliveryPlace
     * @param _offer Offer address
     * @param _status New status
     */
    function updateOfferStatus(
        address _offer,
        OfferStatus _status
    ) external onlyDeliveryPlace(tadleFactory, msg.sender) {
        OfferInfo storage offerInfo = offerInfoMap[_offer];
        offerInfo.offerStatus = _status;

        emit OfferStatusUpdated(_offer, _status);
    }

    /**
     * @dev Update holding status
     * @notice Only called by DeliveryPlace
     * @param _holding Holding address
     * @param _status New status
     */
    function updateHoldingStatus(
        address _holding,
        HoldingStatus _status
    ) external onlyDeliveryPlace(tadleFactory, msg.sender) {
        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];
        holdingInfo.holdingStatus = _status;

        emit HoldingStatusUpdated(_holding, _status);
    }

    /**
     * @dev Settled ask offer
     * @notice Only called by DeliveryPlace
     * @param _offer Offer address
     * @param _settledProjectPoints Settled projectPoints
     * @param _settledPointTokenAmount Settled point token amount
     */
    function settledAskOffer(
        address _offer,
        uint256 _settledCollateralAmount,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount
    ) external onlyDeliveryPlace(tadleFactory, msg.sender) {
        OfferInfo storage offerInfo = offerInfoMap[_offer];
        offerInfo.settledCollateralAmount = _settledCollateralAmount;
        offerInfo.settledProjectPoints = _settledProjectPoints;
        offerInfo.settledPointTokenAmount = _settledPointTokenAmount;
        offerInfo.offerStatus = OfferStatus.Settled;

        emit SettledAskOffer(
            _offer,
            _settledCollateralAmount,
            _settledProjectPoints,
            _settledPointTokenAmount
        );
    }

    /**
     * @dev Settle ask holding
     * @notice Only called by DeliveryPlace
     * @param _offer Offer address
     * @param _holding Holding address
     * @param _settledProjectPoints Settled projectPoints
     * @param _settledPointTokenAmount Settled point token amount
     */
    function settleAskHolding(
        address _offer,
        address _holding,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount
    ) external onlyDeliveryPlace(tadleFactory, msg.sender) {
        HoldingInfo storage holdingInfo = holdingInfoMap[_holding];
        OfferInfo storage offerInfo = offerInfoMap[_offer];

        offerInfo.settledProjectPoints =
            offerInfo.settledProjectPoints +
            _settledProjectPoints;
        offerInfo.settledPointTokenAmount =
            offerInfo.settledPointTokenAmount +
            _settledPointTokenAmount;

        holdingInfo.holdingStatus = HoldingStatus.Finished;

        emit SettledBidHolding(
            _offer,
            _holding,
            _settledProjectPoints,
            _settledPointTokenAmount
        );
    }

    /**
     * @dev Get offer info by offer address
     * @param _offer Offer address
     */
    function getOfferInfo(
        address _offer
    ) external view returns (OfferInfo memory _offerInfo) {
        return offerInfoMap[_offer];
    }

    /**
     * @dev Get holding info by holding address
     * @param _holding Holding address
     */
    function getHoldingInfo(
        address _holding
    ) external view returns (HoldingInfo memory _holdingInfo) {
        return holdingInfoMap[_holding];
    }

    /**
     * @dev Get maker info by maker address
     * @param _maker Maker address
     */
    function getMakerInfo(
        address _maker
    ) external view returns (MakerInfo memory _makerInfo) {
        return makerInfoMap[_maker];
    }

    function _depositTokenWhenCreateHolding(
        uint256 platformFee,
        uint256 quoteTokenAmount,
        uint256 tradeTax,
        MakerInfo storage makerInfo,
        OfferInfo storage offerInfo,
        ITokenManager tokenManager
    ) internal {
        uint256 collateralAmount = OfferLibraries.getDepositCollateralAmount(
            offerInfo.offerType,
            offerInfo.collateralRate,
            quoteTokenAmount,
            false,
            Math.Rounding.Up
        );

        collateralAmount = collateralAmount + platformFee + tradeTax;

        tokenManager.deposit{value: msg.value}(
            msg.sender,
            makerInfo.collateralTokenAddr,
            collateralAmount,
            false
        );
    }

    function _updateReferralBonus(
        uint256 platformFee,
        uint256 quoteTokenAmount,
        address holdingAddr,
        MakerInfo storage makerInfo,
        ReferralInfo memory referralInfo,
        ITokenManager tokenManager
    ) internal returns (uint256 remainingPlatformFee) {
        if (referralInfo.referrer == address(0x0)) {
            remainingPlatformFee = platformFee;
        } else {
            /**
             * @dev Calculate referrer's `referral bonus` and authority's `referral bonus`
             * @dev Calculate remaining platform fee
             * @dev Remaining platform fee = platform fee - referrer's `referral bonus` - authority's `referral bonus`
             * @dev Referrer referral bonus = platform fee * referrer rate
             * @dev Authority referral bonus = platform fee * authority rate
             * @dev Emit ReferralBonus
             */
            uint256 referrerReferralBonus = platformFee.mulDiv(
                referralInfo.referrerRate,
                Constants.REFERRAL_RATE_DECIMAL_SCALER,
                Math.Rounding.Down
            );

            /**
             * @dev Update referrer referral bonus
             * @dev Update authority referral bonus
             */
            tokenManager.addTokenBalance(
                TokenBalanceType.ReferralBonus,
                referralInfo.referrer,
                makerInfo.collateralTokenAddr,
                referrerReferralBonus
            );

            uint256 authorityReferralBonus = platformFee.mulDiv(
                referralInfo.refereeRate,
                Constants.REFERRAL_RATE_DECIMAL_SCALER,
                Math.Rounding.Down
            );

            tokenManager.addTokenBalance(
                TokenBalanceType.ReferralBonus,
                msg.sender,
                makerInfo.collateralTokenAddr,
                authorityReferralBonus
            );

            remainingPlatformFee =
                platformFee -
                referrerReferralBonus -
                authorityReferralBonus;

            /// @dev Emit ReferralBonus
            emit ReferralBonus(
                holdingAddr,
                msg.sender,
                referralInfo.referrer,
                authorityReferralBonus,
                referrerReferralBonus,
                quoteTokenAmount,
                platformFee
            );
        }
    }

    function _updateTokenBalanceWhenCreateHolding(
        address _offer,
        uint256 _tradeTax,
        uint256 _depositAmount,
        uint256 _remainingPlatformFee,
        OfferInfo storage offerInfo,
        MakerInfo storage makerInfo,
        ITokenManager tokenManager
    ) internal {
        if (
            _offer == makerInfo.originOffer ||
            makerInfo.offerSettleType == OfferSettleType.Protected
        ) {
            tokenManager.addTokenBalance(
                TokenBalanceType.TaxIncome,
                offerInfo.authority,
                makerInfo.collateralTokenAddr,
                _tradeTax
            );
            offerInfo.tradeTax += _tradeTax;
        } else {
            tokenManager.addTokenBalance(
                TokenBalanceType.TaxIncome,
                makerInfo.authority,
                makerInfo.collateralTokenAddr,
                _tradeTax
            );

            offerInfoMap[makerInfo.originOffer].tradeTax += _tradeTax;
        }

        /// @dev Update sales revenue
        if (offerInfo.offerType == OfferType.Ask) {
            tokenManager.addTokenBalance(
                TokenBalanceType.SalesRevenue,
                offerInfo.authority,
                makerInfo.collateralTokenAddr,
                _depositAmount
            );
        } else {
            tokenManager.addTokenBalance(
                TokenBalanceType.SalesRevenue,
                msg.sender,
                makerInfo.collateralTokenAddr,
                _depositAmount
            );
        }

        if (_remainingPlatformFee > 0) {
            tokenManager.updatePlatformFee(
                makerInfo.collateralTokenAddr,
                _remainingPlatformFee
            );
        }
    }
}
