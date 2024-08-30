// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {OfferStatus, AbortOfferStatus, OfferType, OfferSettleType} from "../storage/OfferStatus.sol";
import {HoldingStatus, HoldingType} from "../storage/OfferStatus.sol";

/**
 * @title IPreMarkets
 * @dev Interface of PerMarkets
 */
interface IPreMarkets {
    /**
     * @dev Get offer info by offer address
     */
    function getOfferInfo(
        address _offer
    ) external view returns (OfferInfo memory _offerInfo);

    /**
     * @dev Get holding info by holding address
     */
    function getHoldingInfo(
        address _holding
    ) external view returns (HoldingInfo memory _holdingInfo);

    /**
     * @dev Get maker info by maker address
     */
    function getMakerInfo(
        address _maker
    ) external view returns (MakerInfo memory _makerInfo);

    /**
     * @dev Update offer status
     * @notice Only called by DeliveryPlace
     * @param _offer Offer address
     * @param _status New status
     */
    function updateOfferStatus(address _offer, OfferStatus _status) external;

    /**
     * @dev Update holding status
     * @notice Only called by DeliveryPlace
     * @param _holding Holding address
     * @param _status New status
     */
    function updateHoldingStatus(
        address _holding,
        HoldingStatus _status
    ) external;

    /**
     * @dev Settled ask offer
     * @notice Only called by DeliveryPlace
     */
    function settledAskOffer(
        address _offer,
        uint256 _settledCollateralAmount,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount
    ) external;

    /**
     * @dev Settle ask holding
     * @notice Only called by DeliveryPlace
     */
    function settleAskHolding(
        address _offer,
        address _holding,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount
    ) external;

    /// @dev Event when offer created
    event CreateOffer(
        address indexed _offer,
        address indexed _maker,
        address indexed _holding,
        address _marketPlace,
        address _authority,
        uint256 _projectPoints,
        uint256 _quoteTokenAmount
    );

    /// @dev Event when holding created
    event CreateHolding(
        address indexed offer,
        address authority,
        address holding,
        uint256 projectPoints,
        uint256 quoteTokenAmount,
        uint256 tradeTax,
        uint256 platformFee
    );

    /// @dev Event when referrer updated
    event ReferralBonus(
        address indexed holding,
        address authority,
        address referrer,
        uint256 authorityReferralBonus,
        uint256 referrerReferralBonus,
        uint256 tradingVolume,
        uint256 tradingFee
    );

    /// @dev Event when offer listed
    event ListHolding(
        address indexed offer,
        address indexed holding,
        address authority,
        uint256 projectPoints,
        uint256 quoteTokenAmount
    );

    /// @dev Event when offer closed
    event CloseOffer(address indexed offer, address indexed authority);

    /// @dev Event when offer relisted
    event RelistHolding(address indexed offer, address indexed authority);

    /// @dev Event when offer aborted
    event AbortAskOffer(address indexed offer, address indexed authority);

    /// @dev Event when holding aborted
    event AbortBidHolding(
        address indexed offer,
        address indexed holding,
        address indexed authority
    );

    /// @dev Event when offer status updated
    event OfferStatusUpdated(address _offer, OfferStatus _status);

    /// @dev Event when holding status updated
    event HoldingStatusUpdated(address _holding, HoldingStatus _status);

    /// @dev Event when ask offer settled
    event SettledAskOffer(
        address _offer,
        uint256 _settledCollateralAmount,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount
    );

    /// @dev Event when ask holding settled
    event SettledBidHolding(
        address _offer,
        address _holding,
        uint256 _settledProjectPoints,
        uint256 _settledPointTokenAmount
    );

    /// @dev Event when rollin
    event Rollin(address indexed authority, uint256 timestamp);

    /// @dev Error when invalid each trade tax rate
    error InvalidEachTradeTaxRate(uint256 eachTradeTaxRate);

    /// @dev Error when invalid collateral rate
    error InvalidCollateralRate(uint256 collateralRate);

    /// @dev Error when invalid offer account
    error InvalidOfferAccount(address _targetAccount, address _currentAccount);

    /// @dev Error when maker is already exist
    error MakerAlreadyExist();

    /// @dev Error when offer is already exist
    error OfferAlreadyExist();

    /// @dev Error when holding is already exist
    error HoldingAlreadyExist();

    /// @dev Error when invalid offer
    error InvalidOffer();

    /// @dev Error when invalid offer type
    error InvalidOfferType(OfferType _targetType, OfferType _currentType);

    /// @dev Error when invalid holding status
    error InvalidHoldingType(HoldingType _targetType, HoldingType _currentType);

    /// @dev Error when invalid offer status
    error InvalidOfferStatus();
    
    /// @dev Error when invalid holding status
    error InvalidHoldingStatus(
        HoldingStatus _targetStatus,
        HoldingStatus _currentStatus
    );

    /// @dev Error when not enough projectPoints
    error NotEnoughPoints(
        uint256 _totalPoints,
        uint256 _usedProjectPoints,
        uint256 _projectPoints
    );
}

/**
 * @title MakerInfo
 * @dev Struct of MakerInfo
 * @param offerSettleType The settle type of offer.
 * @param authority The owner of maker, same as the authority of originOffer.
 * @param marketPlace The marketPlace of maker.
 */
struct MakerInfo {
    OfferSettleType offerSettleType;
    address authority;
    address marketPlace;
    address collateralTokenAddr;
    address originOffer;
    uint256 eachTradeTax;
}

/**
 * @title OfferInfo
 * @dev Struct of OfferInfo
 * @param id The unique id of offer.
 * @param authority The owner of offer.
 * @param maker The maker of offer, is a virtual address, storage as MakerInfo.
 * @param offerStatus The status of offer, detail in OfferStatus.sol.
 * @param offerType The type of offer, detail in OfferStatus.sol.
 * @param abortOfferStatus The status of abort offer, detail in OfferStatus.sol.
 * @param projectPoints The projectPoints of sell or buy offer.
 * @param quoteTokenAmount The quoteTokenAmount want to sell or buy.
 * @param collateralRate The collateral rate of offer. must be greater than 100%. decimal is 10000.
 * @param usedProjectPoints The projectPoints that already completed.
 * @param tradeTax The trade tax of offer. decimal is 10000.
 * @param settledProjectPoints The settled projectPoints of offer.
 * @param settledPointTokenAmount The settled point token amount of offer.
 * @param settledCollateralAmount The settled collateral amount of offer.
 */
struct OfferInfo {
    uint256 offerId;
    address authority;
    address maker;
    OfferStatus offerStatus;
    OfferType offerType;
    AbortOfferStatus abortOfferStatus;
    uint256 projectPoints;
    uint256 quoteTokenAmount;
    uint256 collateralRate;
    uint256 usedProjectPoints;
    uint256 tradeTax;
    uint256 settledProjectPoints;
    uint256 settledPointTokenAmount;
    uint256 settledCollateralAmount;
}

/**
 * @title HoldingInfo
 * @dev Struct of HoldingInfo
 * @param id The unique id of holding.
 * @param holdingStatus The status of holding, detail in OfferStatus.sol.
 * @param holdingType The type of holding, detail in OfferStatus.sol.
 * @param authority The owner of holding.
 * @param maker The maker of holding, is a virtual address, storage as MakerInfo.
 * @param preOffer The preOffer of holding.
 * @param projectPoints The projectPoints of sell or buy holding.
 * @param quoteTokenAmount Receive or used collateral amount when sell or buy.
 * @param offer The offer of holding, is a virtual address, storage as OfferInfo.
 */
struct HoldingInfo {
    uint256 holdingId;
    HoldingStatus holdingStatus;
    HoldingType holdingType;
    address authority;
    address maker;
    address preOffer;
    uint256 projectPoints;
    uint256 quoteTokenAmount;
    address offer;
}

/**
 * @title CreateOfferParams
 * @dev Struct of CreateOfferParams
 * @param marketPlace The marketPlace of offer.
 * @param tokenAddress The collateral token address of offer.
 * @param projectPoints The projectPoints of sell or buy offer.
 * @param quoteTokenAmount The quoteTokenAmount want to sell or buy.
 * @param collateralRate The collateral rate of offer. must be greater than 100%. decimal is 10000.
 * @param eachTradeTax The trade tax of offer. decimal is 10000.
 * @param offerType The type of offer, detail in OfferType.sol.
 * @param offerSettleType The settle type of offer, detail in OfferSettleType.sol.
 */
struct CreateOfferParams {
    address marketPlace;
    address collateralTokenAddr;
    uint256 projectPoints;
    uint256 quoteTokenAmount;
    uint256 collateralRate;
    uint256 eachTradeTax;
    OfferType offerType;
    OfferSettleType offerSettleType;
}
