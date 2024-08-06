// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DeliveryPlaceStorage} from "../storage/DeliveryPlaceStorage.sol";
import {OfferStatus, StockStatus, OfferType, StockType, OfferSettleType} from "../storage/OfferStatus.sol";
import {ITadleFactory} from "../factory/ITadleFactory.sol";
import {IDeliveryPlace} from "../interfaces/IDeliveryPlace.sol";
import {ISystemConfig, MarketPlaceInfo, MarketPlaceStatus} from "../interfaces/ISystemConfig.sol";
import {IPerMarkets, OfferInfo, StockInfo, MakerInfo} from "../interfaces/IPerMarkets.sol";
import {TokenBalanceType, ITokenManager} from "../interfaces/ITokenManager.sol";
import {RelatedContractLibraries} from "../libraries/RelatedContractLibraries.sol";
import {MarketPlaceLibraries} from "../libraries/MarketPlaceLibraries.sol";
import {OfferLibraries} from "../libraries/OfferLibraries.sol";
import {Rescuable} from "../utils/Rescuable.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title DeliveryPlace
 * @notice Implement the delivery place
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
     * @dev caller must be offer authority
     * @dev offer type must Bid
     * @dev offer status must be Settling
     * @dev refund amount = offer amount - used amount
     */
    function closeBidOffer(address _offer) external nonReentrant {
        (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            ,
            MarketPlaceStatus status
        ) = _getOfferInfo(_offer);

        if (msg.sender != offerInfo.authority) {
            revert Errors.Unauthorized();
        }

        if (offerInfo.offerType == OfferType.Ask) {
            revert InvalidOfferType(OfferType.Bid, OfferType.Ask);
        }

        if (
            status != MarketPlaceStatus.AskSettling &&
            status != MarketPlaceStatus.BidSettling
        ) {
            revert InvaildMarketPlaceStatus();
        }

        if (offerInfo.offerStatus != OfferStatus.Virgin) {
            revert InvalidOfferStatus();
        }

        uint256 refundAmount = OfferLibraries.getRefundAmount(
            offerInfo.offerType,
            offerInfo.amount,
            offerInfo.points,
            offerInfo.usedPoints,
            offerInfo.collateralRate
        );

        ITokenManager tokenManager = tadleFactory.getTokenManager();
        tokenManager.addTokenBalance(
            TokenBalanceType.MakerRefund,
            msg.sender,
            makerInfo.tokenAddress,
            refundAmount
        );

        IPerMarkets perMarkets = tadleFactory.getPerMarkets();
        perMarkets.updateOfferStatus(_offer, OfferStatus.Settled);

        emit CloseBidOffer(
            makerInfo.marketPlace,
            offerInfo.maker,
            _offer,
            msg.sender
        );
    }

    /**
     * @notice Close bid taker
     * @dev caller must be stock authority
     * @dev stock type must Bid
     * @dev offer status must be Settled
     * @param _stock stock address
     */
    function closeBidTaker(address _stock) external nonReentrant {
        IPerMarkets perMarkets = tadleFactory.getPerMarkets();
        ITokenManager tokenManager = tadleFactory.getTokenManager();
        StockInfo memory stockInfo = perMarkets.getStockInfo(_stock);

        if (stockInfo.preOffer == address(0x0)) {
            revert InvalidStock();
        }

        if (stockInfo.stockType == StockType.Ask) {
            revert InvalidStockType();
        }

        if (msg.sender != stockInfo.authority) {
            revert Errors.Unauthorized();
        }

        (
            OfferInfo memory preOfferInfo,
            MakerInfo memory makerInfo,
            ,

        ) = _getOfferInfo(stockInfo.preOffer);

        OfferInfo memory offerInfo;
        uint256 userRemainingPoints;
        if (makerInfo.offerSettleType == OfferSettleType.Protected) {
            offerInfo = preOfferInfo;
            userRemainingPoints = stockInfo.points;
        } else {
            offerInfo = perMarkets.getOfferInfo(makerInfo.originOffer);
            if (stockInfo.offer == address(0x0)) {
                userRemainingPoints = stockInfo.points;
            } else {
                OfferInfo memory listOfferInfo = perMarkets.getOfferInfo(
                    stockInfo.offer
                );
                userRemainingPoints =
                    listOfferInfo.points -
                    listOfferInfo.usedPoints;
            }
        }

        if (userRemainingPoints == 0) {
            revert InsufficientRemainingPoints();
        }

        if (offerInfo.offerStatus != OfferStatus.Settled) {
            revert InvalidOfferStatus();
        }

        if (stockInfo.stockStatus != StockStatus.Initialized) {
            revert InvalidStockStatus();
        }

        uint256 collateralFee;
        if (offerInfo.usedPoints > offerInfo.settledPoints) {
            if (offerInfo.offerStatus == OfferStatus.Virgin) {
                collateralFee = OfferLibraries.getDepositAmount(
                    offerInfo.offerType,
                    offerInfo.collateralRate,
                    offerInfo.amount,
                    true,
                    Math.Rounding.Down
                );
            } else {
                uint256 usedAmount = offerInfo.amount.mulDiv(
                    offerInfo.usedPoints,
                    offerInfo.points,
                    Math.Rounding.Down
                );

                collateralFee = OfferLibraries.getDepositAmount(
                    offerInfo.offerType,
                    offerInfo.collateralRate,
                    usedAmount,
                    true,
                    Math.Rounding.Down
                );
            }
        }

        uint256 userCollateralFee = collateralFee.mulDiv(
            userRemainingPoints,
            offerInfo.usedPoints,
            Math.Rounding.Down
        );

        tokenManager.addTokenBalance(
            TokenBalanceType.RemainingCash,
            msg.sender,
            makerInfo.tokenAddress,
            userCollateralFee
        );
        uint256 pointTokenAmount = offerInfo.settledPointTokenAmount.mulDiv(
            userRemainingPoints,
            offerInfo.usedPoints,
            Math.Rounding.Down
        );
        tokenManager.addTokenBalance(
            TokenBalanceType.PointToken,
            msg.sender,
            makerInfo.tokenAddress,
            pointTokenAmount
        );

        perMarkets.updateStockStatus(_stock, StockStatus.Finished);

        emit CloseBidTaker(
            makerInfo.marketPlace,
            offerInfo.maker,
            _stock,
            msg.sender,
            userCollateralFee,
            pointTokenAmount
        );
    }

    /**
     * @notice Settle ask maker
     * @dev caller must be offer authority
     * @dev offer status must be Virgin or Canceled
     * @dev market place status must be AskSettling
     * @param _offer offer address
     * @param _settledPoints settled points
     */
    function settleAskMaker(
        address _offer,
        uint256 _settledPoints
    ) external nonReentrant {
        (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            MarketPlaceInfo memory marketPlaceInfo,
            MarketPlaceStatus status
        ) = _getOfferInfo(_offer);

        if (_settledPoints > offerInfo.usedPoints) {
            revert InvalidPoints();
        }

        if (marketPlaceInfo.fixedratio) {
            revert FixedRatioUnsupported();
        }

        if (offerInfo.offerType == OfferType.Bid) {
            revert InvalidOfferType(OfferType.Ask, OfferType.Bid);
        }

        if (
            offerInfo.offerStatus != OfferStatus.Virgin &&
            offerInfo.offerStatus != OfferStatus.Canceled
        ) {
            revert InvalidOfferStatus();
        }

        if (status == MarketPlaceStatus.AskSettling) {
            if (msg.sender != offerInfo.authority) {
                revert Errors.Unauthorized();
            }
        } else {
            if (msg.sender != owner()) {
                revert Errors.Unauthorized();
            }
            if (_settledPoints != 0) {
                revert InvalidPoints();
            }
        }

        uint256 settledPointTokenAmount = marketPlaceInfo.tokenPerPoint *
            _settledPoints;

        ITokenManager tokenManager = tadleFactory.getTokenManager();
        if (settledPointTokenAmount != 0) {
            tokenManager.tillIn(
                msg.sender,
                marketPlaceInfo.tokenAddress,
                settledPointTokenAmount,
                true
            );
        }

        uint256 makerRefundAmount;
        if (_settledPoints == offerInfo.usedPoints) {
            if (offerInfo.offerStatus == OfferStatus.Virgin) {
                makerRefundAmount = OfferLibraries.getDepositAmount(
                    offerInfo.offerType,
                    offerInfo.collateralRate,
                    offerInfo.amount,
                    true,
                    Math.Rounding.Down
                );
            } else {
                uint256 usedAmount = offerInfo.amount.mulDiv(
                    offerInfo.usedPoints,
                    offerInfo.points,
                    Math.Rounding.Down
                );

                makerRefundAmount = OfferLibraries.getDepositAmount(
                    offerInfo.offerType,
                    offerInfo.collateralRate,
                    usedAmount,
                    true,
                    Math.Rounding.Down
                );
            }

            tokenManager.addTokenBalance(
                TokenBalanceType.SalesRevenue,
                msg.sender,
                makerInfo.tokenAddress,
                makerRefundAmount
            );
        }

        IPerMarkets perMarkets = tadleFactory.getPerMarkets();
        perMarkets.settledAskOffer(
            _offer,
            _settledPoints,
            settledPointTokenAmount
        );

        emit SettleAskMaker(
            makerInfo.marketPlace,
            offerInfo.maker,
            _offer,
            msg.sender,
            _settledPoints,
            settledPointTokenAmount,
            makerRefundAmount
        );
    }

    /**
     * @notice Settle ask taker
     * @dev caller must be stock authority
     * @dev market place status must be AskSettling
     * @param _stock stock address
     * @param _settledPoints settled points
     * @notice _settledPoints must be less than or equal to stock points
     */
    function settleAskTaker(
        address _stock,
        uint256 _settledPoints
    ) external nonReentrant {
        IPerMarkets perMarkets = tadleFactory.getPerMarkets();
        StockInfo memory stockInfo = perMarkets.getStockInfo(_stock);

        (
            OfferInfo memory offerInfo,
            MakerInfo memory makerInfo,
            MarketPlaceInfo memory marketPlaceInfo,
            MarketPlaceStatus status
        ) = _getOfferInfo(stockInfo.preOffer);

        if (stockInfo.stockStatus != StockStatus.Initialized) {
            revert InvalidStockStatus();
        }

        if (marketPlaceInfo.fixedratio) {
            revert FixedRatioUnsupported();
        }
        if (stockInfo.stockType == StockType.Bid) {
            revert InvalidStockType();
        }
        if (_settledPoints > stockInfo.points) {
            revert InvalidPoints();
        }

        if (status == MarketPlaceStatus.AskSettling) {
            if (msg.sender != offerInfo.authority) {
                revert Errors.Unauthorized();
            }
        } else {
            if (msg.sender != owner()) {
                revert Errors.Unauthorized();
            }
            if (_settledPoints != 0) {
                revert InvalidPoints();
            }
        }

        uint256 settledPointTokenAmount = marketPlaceInfo.tokenPerPoint *
            _settledPoints;
        ITokenManager tokenManager = tadleFactory.getTokenManager();
        if (settledPointTokenAmount != 0) {
            tokenManager.tillIn(
                msg.sender,
                marketPlaceInfo.tokenAddress,
                settledPointTokenAmount,
                true
            );

            tokenManager.addTokenBalance(
                TokenBalanceType.PointToken,
                offerInfo.authority,
                makerInfo.tokenAddress,
                settledPointTokenAmount
            );
        }

        uint256 collateralFee = OfferLibraries.getDepositAmount(
            offerInfo.offerType,
            offerInfo.collateralRate,
            stockInfo.amount,
            false,
            Math.Rounding.Down
        );

        if (_settledPoints == stockInfo.points) {
            tokenManager.addTokenBalance(
                TokenBalanceType.RemainingCash,
                msg.sender,
                makerInfo.tokenAddress,
                collateralFee
            );
        } else {
            tokenManager.addTokenBalance(
                TokenBalanceType.MakerRefund,
                offerInfo.authority,
                makerInfo.tokenAddress,
                collateralFee
            );
        }

        perMarkets.settleAskTaker(
            stockInfo.preOffer,
            _stock,
            _settledPoints,
            settledPointTokenAmount
        );

        emit SettleAskTaker(
            makerInfo.marketPlace,
            offerInfo.maker,
            _stock,
            stockInfo.preOffer,
            msg.sender,
            _settledPoints,
            settledPointTokenAmount,
            collateralFee
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
            MarketPlaceInfo memory marketPlaceInfo,
            MarketPlaceStatus status
        )
    {
        IPerMarkets perMarkets = tadleFactory.getPerMarkets();
        ISystemConfig systemConfig = tadleFactory.getSystemConfig();

        offerInfo = perMarkets.getOfferInfo(_offer);
        makerInfo = perMarkets.getMakerInfo(offerInfo.maker);
        marketPlaceInfo = systemConfig.getMarketPlaceInfo(
            makerInfo.marketPlace
        );

        status = MarketPlaceLibraries.getMarketPlaceStatus(
            block.timestamp,
            marketPlaceInfo
        );
    }
}
