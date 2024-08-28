// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {OfferType} from "../storage/OfferStatus.sol";

/**
 * @title IDeliveryPlace
 * @dev Interface of DeliveryPlace
 */
interface IDeliveryPlace {
    /**
     * @dev Emit events when close bid offer
     */
    event CloseBidOffer(
        address indexed _marketPlace,
        address indexed _maker,
        address indexed _offer,
        address _authority
    );

    /**
     * @dev Emit events when close bid holding
     */
    event CloseBidHolding(
        address indexed _marketPlace,
        address indexed _maker,
        address indexed _holding,
        address _authority,
        uint256 _userCollateralFee,
        uint256 _pointTokenAmount
    );

    /**
     * @dev Emit events when settle ask maker
     */
    event SettleAskMaker(
        address indexed _marketPlace,
        address indexed _maker,
        address indexed _offer,
        address _authority,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount,
        uint256 _makerRefundAmount
    );

    /**
     * @dev Emit events when settle ask holding
     */
    event SettleAskHolding(
        address indexed _marketPlace,
        address indexed _maker,
        address indexed _holding,
        address _preOffer,
        address _authority,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount,
        uint256 _collateralAmount
    );

    /// @dev Error when invalid offer type
    error InvalidOfferType(OfferType _targetType, OfferType _currentType);

    /// @dev Error when invalid offer status
    error InvalidOfferStatus();

    /// @dev Error when invalid holding status
    error InvalidHoldingStatus();

    /// @dev Error when invalid market place status
    error InvalidMarketplaceStatus();

    /// @dev Error when invalid holding
    error InvalidHolding();

    /// @dev Error when invalid holding type
    error InvalidHoldingType();

    /// @dev Error when insufficient remaining projectPoints
    error InsufficientRemainingPoints();

    /// @dev Error when invalid projectPoints
    error InvalidPoints();

    /// @dev Error when fixed ratio type mismatch
    error FixedRatioTypeMismatch(bool _isSpecial);

    error InvalidOfferAccount(address);
}
