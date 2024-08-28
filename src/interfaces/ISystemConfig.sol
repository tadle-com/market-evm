// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @title ISystemConfig
 * @dev Interface of system config
 */
interface ISystemConfig {
    /// @dev Get base platform fee rate.
    function getBaseReferralRate() external view returns (uint256);

    /**
     * @dev Get base platform fee rate.
     */
    function getPlatformFeeRate(address _user) external view returns (uint256);

    /// @dev Get `ReferralInfo` by referrer
    function getReferralInfo(
        address _referrer
    ) external view returns (ReferralInfo calldata);

    /// @dev Get `MarketplaceInfo` by marketPlace
    function getMarketplaceInfo(
        address _marketPlace
    ) external view returns (MarketplaceInfo calldata);

    /// @dev Emit events when initialize
    event Initialize(uint256 _basePlatformFeeRate, uint256 _baseReferralRate);

    /// @dev Emit events when create referral code
    event CreateReferralCode(
        address indexed referrer,
        string code,
        uint256 _referrerRate,
        uint256 _refereeRate
    );

    /// @dev Emit events when remove referral code
    event RemoveReferralCode(address indexed referrer, string code);

    /// @dev Emit events when update marketPlace status
    event UpdateMarketplaceStatus(
        address indexed marketPlaceAddress,
        MarketplaceStatus status
    );

    /// @dev Emit events when base platform fee rate is updated
    event UpdateBasePlatformFeeRate(uint256 basePlatformFeeRate);

    /// @dev Emit events when base referral rate is updated
    event UpdateBaseReferralRate(uint256 baseReferralRate);

    /// @dev Emit events when user platform fee rate is updated
    event UpdateUserPlatformFeeRate(
        address indexed userAddress,
        uint256 userPlatformFeeRate
    );

    /// @dev Emit events when user referral extra rate is updated
    event UpdateReferralExtraRate(
        address indexed referrerAddress,
        uint256 referrerRate
    );

    /// @dev Emit events when user referral extra rate is updated
    event UpdateReferrerExtraRate(
        address indexed authorityAddress,
        uint256 refereeRate
    );

    /// @dev Emit events when create marketPlace
    event CreateMarketplaceInfo(
        address indexed marketPlaceAddress,
        string marketPlaceName
    );

    /// @dev Emit events when update marketPlace
    event UpdateMarket(
        address indexed marketPlaceAddress,
        address indexed tokenAddress,
        bool isSpecial,
        string marketPlaceName,
        uint256 tokenPerPoint,
        uint256 tge,
        uint256 settlementPeriod
    );

    /// @dev Emit events when update `referrerInfo`
    event UpdateReferrerInfo(
        address indexed authorityAddress,
        address indexed referrerAddress,
        uint256 referrerRate,
        uint256 refereeRate
    );

    /// @dev Emit events when update `referrerExtraRate`
    event UpdateReferralExtraRateMap(
        address indexed referrerAddress,
        uint256 referrerRate
    );

    /// Error when invalid referrer
    error InvalidReferrer(address referrer);

    /// Error when invalid `referrerRate` or `refereeRate`
    error InvalidRate(
        uint256 referrerRate,
        uint256 refereeRate,
        uint256 totalRate
    );

    /// Error when referrer rate must be greater than the base number
    error InvalidReferrerRate(uint256 referrerRate);

    /// Error when invalid total rate
    error InvalidTotalRate(uint256 totalRate);

    /// Error when invalid platform fee rate
    error InvalidPlatformFeeRate(uint256 platformFeeRate);

    /// Error when marketPlace already initialized
    error MarketplaceAlreadyInitialized();

    /// Error when marketPlace is not online
    error MarketplaceNotOnline(MarketplaceStatus status);

    /// Error when referrer code exist
    error ReferralCodeExist(string);
}

/**
 * @title MarketplaceStatus
 * @dev Enum of MarketplaceStatus
 * @param UnInitialized is the default value, when marketPlace is not created.
 * @param Online is the value when marketPlace is created and online.
 * @param AskSettling is the value when ask offer or ask holding is settled.
 * @param BidSettling is the value when bid offer or bid holding is settled.
 * @param Offline is the value when marketPlace is offline.
 */
enum MarketplaceStatus {
    UnInitialized,
    Online,
    AskSettling,
    BidSettling,
    Offline
}

/**
 * @title MarketplaceInfo
 * @dev Struct of MarketplaceInfo
 * @param isSpecial The market is a unfixed-rate market
 * @param status Marketplace status, detail see MarketplaceStatus
 * @param projectTokenAddr The point token address
 * @param tokenPerPoint Token per point
 * @param tge Token Generation Event
 * @param settlementPeriod Settlement period
 */
struct MarketplaceInfo {
    bool isSpecial;
    MarketplaceStatus status;
    address projectTokenAddr;
    uint256 tokenPerPoint;
    uint256 tge;
    uint256 settlementPeriod;
}

/**
 * @title ReferralInfo
 * @dev Struct of `ReferralInfo`
 * @param referrer referrer address
 * @param referrerRate referrer rate
 * @param refereeRate authority rate
 */
struct ReferralInfo {
    address referrer;
    uint256 referrerRate;
    uint256 refereeRate;
}
