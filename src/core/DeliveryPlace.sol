// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DeliveryPlaceStorage} from "../storage/DeliveryPlaceStorage.sol";
import {OfferStatus, HoldingStatus, OfferType, HoldingType, OfferSettleType} from "../storage/OfferStatus.sol";
import {ITadleFactory} from "../factory/ITadleFactory.sol";
import {IDeliveryPlace} from "../interfaces/IDeliveryPlace.sol";
import {ISystemConfig, MarketplaceInfo, MarketplaceStatus} from "../interfaces/ISystemConfig.sol";
import {IPreMarkets, OfferInfo, HoldingInfo, MakerInfo} from "../interfaces/IPreMarkets.sol";
import {TokenBalanceType, ITokenManager} from "../interfaces/ITokenManager.sol";
import {RelatedContractLibraries} from "../libraries/RelatedContractLibraries.sol";
import {MarketplaceLibraries} from "../libraries/MarketplaceLibraries.sol";
import {OfferLibraries} from "../libraries/OfferLibraries.sol";
import {Rescuable} from "../utils/Rescuable.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title DeliveryPlace
 * @dev The contract includes all operations after the settlement time
 *        such as settle ask offer, settle ask holding, close bid offer, close bid holding etc.
 */
contract DeliveryPlace is
    DeliveryPlaceStorage,
    ReentrancyGuard,
    Rescuable,
    IDeliveryPlace
{
    using Math for uint256;
    using RelatedContractLibraries for ITadleFactory;

    constructor() Rescuable() {}

    /**
     * @notice Close bid offer
     * @dev Caller must be offer's owner
     * @dev Offer type must `Bid`
     * @dev Market place status must be `AskSettling` or `BidSettling`
     * @dev Refund amount = offer amount - used amount
     */
    function closeBidOffer(address _offer) external nonReentrant whenNotPaused {
        (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            ,
            MarketplaceStatus status
        ) = _getOfferInfo(_offer);

        if (msg.sender != offerInfo.authority) {
            revert Errors.Unauthorized();
        }

        if (offerInfo.offerType == OfferType.Ask) {
            revert InvalidOfferType(OfferType.Bid, OfferType.Ask);
        }

        if (
            status != MarketplaceStatus.AskSettling &&
            status != MarketplaceStatus.BidSettling
        ) {
            revert InvalidMarketplaceStatus();
        }

        if (offerInfo.offerStatus != OfferStatus.Virgin) {
            revert InvalidOfferStatus();
        }

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

        IPreMarkets perMarkets = tadleFactory.getPerMarkets();
        perMarkets.updateOfferStatus(_offer, OfferStatus.Settled);

        emit CloseBidOffer(
            makerInfo.marketPlace,
            offerInfo.maker,
            _offer,
            msg.sender
        );
    }

    /**
     * @notice Close bid holding
     * @dev Caller must be holding's owner
     * @dev Holding type must `Bid`
     * @dev Offer status must be Settled
     * @param _holding Holding address
     */
    function closeBidHolding(
        address _holding
    ) external nonReentrant whenNotPaused {
        IPreMarkets perMarkets = tadleFactory.getPerMarkets();
        ITokenManager tokenManager = tadleFactory.getTokenManager();
        HoldingInfo memory holdingInfo = perMarkets.getHoldingInfo(_holding);

        if (holdingInfo.preOffer == address(0x0)) {
            revert InvalidHolding();
        }

        if (holdingInfo.holdingType == HoldingType.Ask) {
            revert InvalidHoldingType();
        }

        if (msg.sender != holdingInfo.authority) {
            revert Errors.Unauthorized();
        }

        (
            OfferInfo memory preOfferInfo,
            MakerInfo memory makerInfo,
            MarketplaceInfo memory marketPlaceInfo,

        ) = _getOfferInfo(holdingInfo.preOffer);

        OfferInfo memory offerInfo;
        uint256 userRemainingProjectPoints;
        if (makerInfo.offerSettleType == OfferSettleType.Protected) {
            offerInfo = preOfferInfo;
            userRemainingProjectPoints = holdingInfo.projectPoints;
        } else {
            offerInfo = perMarkets.getOfferInfo(makerInfo.originOffer);
            if (holdingInfo.offer == address(0x0)) {
                userRemainingProjectPoints = holdingInfo.projectPoints;
            } else {
                OfferInfo memory listOfferInfo = perMarkets.getOfferInfo(
                    holdingInfo.offer
                );
                userRemainingProjectPoints =
                    listOfferInfo.projectPoints -
                    listOfferInfo.usedProjectPoints;
            }
        }

        if (userRemainingProjectPoints == 0) {
            revert InsufficientRemainingPoints();
        }

        if (offerInfo.offerStatus != OfferStatus.Settled) {
            revert InvalidOfferStatus();
        }

        if (holdingInfo.holdingStatus != HoldingStatus.Initialized) {
            revert InvalidHoldingStatus();
        }

        uint256 userCollateralFee = 0;
        if (offerInfo.usedProjectPoints > offerInfo.settledProjectPoints) {
            userCollateralFee = offerInfo.settledCollateralAmount.mulDiv(
                userRemainingProjectPoints,
                offerInfo.projectPoints,
                Math.Rounding.Down
            );

            tokenManager.addTokenBalance(
                TokenBalanceType.RemainingCash,
                msg.sender,
                makerInfo.collateralTokenAddr,
                userCollateralFee
            );
        }

        uint256 pointTokenAmount = offerInfo.settledPointTokenAmount.mulDiv(
            userRemainingProjectPoints,
            offerInfo.usedProjectPoints,
            Math.Rounding.Down
        );

        tokenManager.addTokenBalance(
            TokenBalanceType.PointToken,
            msg.sender,
            marketPlaceInfo.projectTokenAddr,
            pointTokenAmount
        );

        perMarkets.updateHoldingStatus(_holding, HoldingStatus.Finished);

        emit CloseBidHolding(
            makerInfo.marketPlace,
            offerInfo.maker,
            _holding,
            msg.sender,
            userCollateralFee,
            pointTokenAmount
        );
    }

    /**
     * @notice Settle ask maker
     * @dev Caller must be offer's authority
     * @dev Offer status must be `Virgin` or `Canceled`
     * @dev Market place status must be `AskSettling`
     * @param _offer Offer address
     * @param _settledProjectPoints Settled projectPoints
     */
    function settleAskMaker(
        address _offer,
        uint256 _settledProjectPoints
    ) external nonReentrant whenNotPaused {
        (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            MarketplaceInfo memory marketPlaceInfo,
            MarketplaceStatus status
        ) = _getOfferInfo(_offer);

        if (_settledProjectPoints > offerInfo.usedProjectPoints) {
            revert InvalidPoints();
        }

        if (marketPlaceInfo.isSpecial) {
            revert FixedRatioTypeMismatch(marketPlaceInfo.isSpecial);
        }

        if (offerInfo.offerType == OfferType.Bid) {
            revert InvalidOfferType(OfferType.Ask, OfferType.Bid);
        }

        if (
            makerInfo.offerSettleType == OfferSettleType.Turbo &&
            _offer != makerInfo.originOffer
        ) {
            revert InvalidOfferAccount(_offer);
        }

        if (
            offerInfo.offerStatus != OfferStatus.Virgin &&
            offerInfo.offerStatus != OfferStatus.Canceled
        ) {
            revert InvalidOfferStatus();
        }

        if (status == MarketplaceStatus.AskSettling) {
            if (msg.sender != offerInfo.authority) {
                revert Errors.Unauthorized();
            }
        } else {
            if (msg.sender != owner()) {
                revert Errors.Unauthorized();
            }
            if (_settledProjectPoints != 0) {
                revert InvalidPoints();
            }
        }

        uint256 settledPointTokenAmount = marketPlaceInfo.tokenPerPoint *
            _settledProjectPoints;

        ITokenManager tokenManager = tadleFactory.getTokenManager();
        if (settledPointTokenAmount != 0) {
            tokenManager.deposit(
                msg.sender,
                marketPlaceInfo.projectTokenAddr,
                settledPointTokenAmount,
                true
            );
        }

        uint256 totalCollateralAmount;
        if (offerInfo.offerStatus == OfferStatus.Virgin) {
            totalCollateralAmount = OfferLibraries.getDepositCollateralAmount(
                offerInfo.offerType,
                offerInfo.collateralRate,
                offerInfo.quoteTokenAmount,
                true,
                Math.Rounding.Down
            );
        } else {
            uint256 usedQuoteTokenAmount = offerInfo.quoteTokenAmount.mulDiv(
                offerInfo.usedProjectPoints,
                offerInfo.projectPoints,
                Math.Rounding.Down
            );

            totalCollateralAmount = OfferLibraries.getDepositCollateralAmount(
                offerInfo.offerType,
                offerInfo.collateralRate,
                usedQuoteTokenAmount,
                true,
                Math.Rounding.Down
            );
        }

        uint256 _settledCollateralAmount = 0;
        if (_settledProjectPoints != offerInfo.usedProjectPoints) {
            _settledCollateralAmount = totalCollateralAmount;
        }

        uint256 makerRefundAmount = totalCollateralAmount -
            _settledCollateralAmount;
        if (makerRefundAmount > 0) {
            tokenManager.addTokenBalance(
                TokenBalanceType.MakerRefund,
                msg.sender,
                makerInfo.collateralTokenAddr,
                makerRefundAmount
            );
        }

        IPreMarkets perMarkets = tadleFactory.getPerMarkets();
        perMarkets.settledAskOffer(
            _offer,
            _settledCollateralAmount,
            _settledProjectPoints,
            settledPointTokenAmount
        );

        emit SettleAskMaker(
            makerInfo.marketPlace,
            offerInfo.maker,
            _offer,
            offerInfo.authority,
            _settledProjectPoints,
            settledPointTokenAmount,
            makerRefundAmount
        );
    }

    /**
     * @notice Settle ask holding
     * @dev Caller must be holding's owner
     * @dev Market place status must be `AskSettling`
     * @param _holding Holding address
     * @param _settledProjectPoints Settled projectPoints
     * @notice `_settledProjectPoints` must be less than or equal to holding projectPoints
     */
    function settleAskHolding(
        address _holding,
        uint256 _settledProjectPoints
    ) external nonReentrant whenNotPaused {
        IPreMarkets perMarkets = tadleFactory.getPerMarkets();
        HoldingInfo memory holdingInfo = perMarkets.getHoldingInfo(_holding);

        (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            MarketplaceInfo memory marketPlaceInfo,
            MarketplaceStatus status
        ) = _getOfferInfo(holdingInfo.preOffer);

        if (holdingInfo.holdingStatus != HoldingStatus.Initialized) {
            revert InvalidHoldingStatus();
        }

        if (marketPlaceInfo.isSpecial) {
            revert FixedRatioTypeMismatch(marketPlaceInfo.isSpecial);
        }
        if (holdingInfo.holdingType == HoldingType.Bid) {
            revert InvalidHoldingType();
        }
        if (_settledProjectPoints > holdingInfo.projectPoints) {
            revert InvalidPoints();
        }

        if (status == MarketplaceStatus.AskSettling) {
            if (msg.sender != holdingInfo.authority) {
                revert Errors.Unauthorized();
            }
        } else {
            if (msg.sender != owner()) {
                revert Errors.Unauthorized();
            }
            if (_settledProjectPoints != 0) {
                revert InvalidPoints();
            }
        }

        uint256 settledPointTokenAmount = marketPlaceInfo.tokenPerPoint *
            _settledProjectPoints;
        ITokenManager tokenManager = tadleFactory.getTokenManager();
        if (settledPointTokenAmount != 0) {
            tokenManager.deposit(
                holdingInfo.authority,
                marketPlaceInfo.projectTokenAddr,
                settledPointTokenAmount,
                true
            );

            tokenManager.addTokenBalance(
                TokenBalanceType.PointToken,
                offerInfo.authority,
                marketPlaceInfo.projectTokenAddr,
                settledPointTokenAmount
            );
        }

        uint256 collateralAmount = OfferLibraries.getDepositCollateralAmount(
            offerInfo.offerType,
            offerInfo.collateralRate,
            holdingInfo.quoteTokenAmount,
            false,
            Math.Rounding.Down
        );

        if (_settledProjectPoints == holdingInfo.projectPoints) {
            tokenManager.addTokenBalance(
                TokenBalanceType.MakerRefund,
                msg.sender,
                makerInfo.collateralTokenAddr,
                collateralAmount
            );
        } else {
            tokenManager.addTokenBalance(
                TokenBalanceType.RemainingCash,
                offerInfo.authority,
                makerInfo.collateralTokenAddr,
                collateralAmount
            );
        }

        perMarkets.settleAskHolding(
            holdingInfo.preOffer,
            _holding,
            _settledProjectPoints,
            settledPointTokenAmount
        );

        emit SettleAskHolding(
            makerInfo.marketPlace,
            offerInfo.maker,
            _holding,
            holdingInfo.preOffer,
            holdingInfo.authority,
            _settledProjectPoints,
            settledPointTokenAmount,
            collateralAmount
        );
    }

    function _getOfferInfo(
        address _offer
    )
        internal
        view
        returns (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            MarketplaceInfo memory marketPlaceInfo,
            MarketplaceStatus status
        )
    {
        IPreMarkets perMarkets = tadleFactory.getPerMarkets();
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();

        offerInfo = perMarkets.getOfferInfo(_offer);
        makerInfo = perMarkets.getMakerInfo(offerInfo.maker);
        marketPlaceInfo = systemConfig.getMarketplaceInfo(
            makerInfo.marketPlace
        );

        status = MarketplaceLibraries.getMarketplaceStatus(
            block.timestamp,
            marketPlaceInfo
        );
    }
}
