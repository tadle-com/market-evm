// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {SystemConfigStorage} from "../storage/SystemConfigStorage.sol";
import {ISystemConfig, ReferralInfo, MarketplaceInfo, MarketplaceStatus} from "../interfaces/ISystemConfig.sol";
import {Constants} from "../libraries/Constants.sol";
import {GenerateAddress} from "../libraries/GenerateAddress.sol";
import {Rescuable} from "../utils/Rescuable.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title SystemConfig
 * @dev Contract of SystemConfig.
 * @dev Contains markets setting, referral setting, etc.
 */
contract SystemConfig is SystemConfigStorage, Rescuable, ISystemConfig {
    constructor() Rescuable() {}

    /**
     * @notice Set base platform fee rate and base referral rate
     * @dev Caller must be mamanger
     * @param _basePlatformFeeRate Base platform fee rate, default is 0.5%
     * @param _baseReferralRate Base referral rate, default is 30%
     */
    function initialize(
        uint256 _basePlatformFeeRate,
        uint256 _baseReferralRate
    ) external onlyOwner {
        basePlatformFeeRate = _basePlatformFeeRate;
        baseReferralRate = _baseReferralRate;

        emit Initialize(_basePlatformFeeRate, _baseReferralRate);
    }

    /**
     * @notice Create referral code
     * @param _referralCode Referral code
     * @param _referrerRate Referrer rate
     * @param _refereeRate Authority rate
     * @notice `_referrerRate` + `_refereeRate` = `baseReferralRate` + `referralExtraRate`
     */
    function createReferralCode(
        string calldata _referralCode,
        uint256 _referrerRate,
        uint256 _refereeRate
    ) external whenNotPaused {
        if (_referrerRate < baseReferralRate) {
            revert InvalidReferrerRate(_referrerRate);
        }

        uint256 referralExtraRate = referralExtraRateMap[msg.sender];
        uint256 totalRate = baseReferralRate + referralExtraRate;

        if (totalRate > Constants.REFERRAL_RATE_DECIMAL_SCALER) {
            revert InvalidTotalRate(totalRate);
        }

        if (_referrerRate + _refereeRate != totalRate) {
            revert InvalidRate(_referrerRate, _refereeRate, totalRate);
        }

        bytes32 referralCodeId = keccak256(abi.encode(_referralCode));
        if (referralCodeMap[referralCodeId].referrer != address(0x0)) {
            revert ReferralCodeExist(_referralCode);
        }

        referralCodeMap[referralCodeId] = ReferralInfo(
            msg.sender,
            _referrerRate,
            _refereeRate
        );

        emit CreateReferralCode(
            msg.sender,
            _referralCode,
            _referrerRate,
            _refereeRate
        );
    }

    /**
     * @notice Remove referral code
     * @param _referralCode Referral code
     * @notice `_referrer` == `msg.sender`
     */
    function removeReferralCode(
        string calldata _referralCode
    ) external whenNotPaused {
        bytes32 referralCodeId = keccak256(abi.encode(_referralCode));

        if (referralCodeMap[referralCodeId].referrer != msg.sender) {
            revert Errors.Unauthorized();
        }

        delete referralCodeMap[referralCodeId];

        emit RemoveReferralCode(msg.sender, _referralCode);
    }

    /**
     * @notice Update referrer setting
     * @param _referralCode Referral code
     * @notice `_referrer` != `msg.sender`
     */
    function updateReferrerInfo(
        string calldata _referralCode
    ) external whenNotPaused {
        bytes32 referralCodeId = keccak256(abi.encode(_referralCode));

        ReferralInfo storage referralInfo = referralCodeMap[referralCodeId];

        if (msg.sender == referralInfo.referrer) {
            revert InvalidReferrer(referralInfo.referrer);
        }

        if (referralInfo.referrer == address(0x0)) {
            revert Errors.ZeroAddress();
        }

        referralInfoMap[msg.sender] = referralInfo;

        emit UpdateReferrerInfo(
            msg.sender,
            referralInfo.referrer,
            referralInfo.referrerRate,
            referralInfo.refereeRate
        );
    }

    /**
     * @notice Create a new marketplace
     * @param _marketPlaceName Market name
     * @notice Caller must be manager
     * @notice The market must be unique
     * @notice If the offer is subject to arbitration, the fixedratio is `false`, and vice versa `true`
     */
    function createMarketplace(
        string calldata _marketPlaceName
    ) external onlyOwner {
        address marketPlace = GenerateAddress.generateMarketplaceAddress(
            _marketPlaceName
        );
        MarketplaceInfo storage marketPlaceInfo = marketPlaceInfoMap[
            marketPlace
        ];

        if (marketPlaceInfo.status != MarketplaceStatus.UnInitialized) {
            revert MarketplaceAlreadyInitialized();
        }

        marketPlaceInfo.status = MarketplaceStatus.Online;
        emit CreateMarketplaceInfo(marketPlace, _marketPlaceName);
    }

    /**
     * @notice Update market when settlement time is passed
     * @param _marketPlaceName Market place name
     * @param _projectTokenAddr Token address
     * @param _isSpecial The market is a unfixed-rate market
     * @param _tokenPerPoint Token per point
     * @param _tge TGE (Token Generation Event)
     * @param _settlementPeriod Settlement period
     * @notice Caller must be manager
     */
    function updateMarket(
        string calldata _marketPlaceName,
        address _projectTokenAddr,
        bool _isSpecial,
        uint256 _tokenPerPoint,
        uint256 _tge,
        uint256 _settlementPeriod
    ) external onlyOwner {
        address marketPlace = GenerateAddress.generateMarketplaceAddress(
            _marketPlaceName
        );

        MarketplaceInfo storage marketPlaceInfo = marketPlaceInfoMap[
            marketPlace
        ];

        if (marketPlaceInfo.status != MarketplaceStatus.Online) {
            revert MarketplaceNotOnline(marketPlaceInfo.status);
        }

        marketPlaceInfo.projectTokenAddr = _projectTokenAddr;
        marketPlaceInfo.isSpecial = _isSpecial;
        marketPlaceInfo.tokenPerPoint = _tokenPerPoint;
        marketPlaceInfo.tge = _tge;
        marketPlaceInfo.settlementPeriod = _settlementPeriod;

        emit UpdateMarket(
            marketPlace,
            _projectTokenAddr,
            _isSpecial,
            _marketPlaceName,
            _tokenPerPoint,
            _tge,
            _settlementPeriod
        );
    }

    /**
     * @notice Update market place status
     * @param _marketPlaceName Market place name
     * @param _status Market place status
     * @notice Caller must be manager
     */
    function updateMarketplaceStatus(
        string calldata _marketPlaceName,
        MarketplaceStatus _status
    ) external onlyOwner {
        address marketPlace = GenerateAddress.generateMarketplaceAddress(
            _marketPlaceName
        );
        MarketplaceInfo storage marketPlaceInfo = marketPlaceInfoMap[
            marketPlace
        ];
        marketPlaceInfo.status = _status;

        emit UpdateMarketplaceStatus(marketPlace, _status);
    }

    /**
     * @notice Update base platform fee rate
     * @param _accountAddress Account address
     * @param _platformFeeRate Platform fee rate of user
     * @notice Caller must be manager
     */
    function updateUserPlatformFeeRate(
        address _accountAddress,
        uint256 _platformFeeRate
    ) external onlyOwner {
        require(
            _platformFeeRate <= Constants.PLATFORM_FEE_DECIMAL_SCALER,
            "Invalid platform fee rate"
        );
        userPlatformFeeRate[_accountAddress] = _platformFeeRate;

        emit UpdateUserPlatformFeeRate(_accountAddress, _platformFeeRate);
    }

    /**
     * @notice Update referrer extra rate
     * @param _referrer Referrer address
     * @param _extraRate Extra rate
     * @notice Caller must be manager
     * @notice `_extraRate` + `baseReferralRate` <= REFERRAL_RATE_DECIMAL_SCALER
     */
    function updateReferralExtraRateMap(
        address _referrer,
        uint256 _extraRate
    ) external onlyOwner {
        uint256 totalRate = _extraRate + baseReferralRate;
        if (totalRate > Constants.REFERRAL_RATE_DECIMAL_SCALER) {
            revert InvalidTotalRate(totalRate);
        }
        referralExtraRateMap[_referrer] = _extraRate;
        emit UpdateReferralExtraRateMap(_referrer, _extraRate);
    }

    /// @dev Get base platform fee rate.
    function getBaseReferralRate() external view returns (uint256) {
        return baseReferralRate;
    }

    /**
     * @dev Get base platform fee rate.
     */
    function getPlatformFeeRate(address _user) external view returns (uint256) {
        if (userPlatformFeeRate[_user] == 0) {
            return basePlatformFeeRate;
        }

        return userPlatformFeeRate[_user];
    }

    /// @dev Get referral info by referrer
    function getReferralInfo(
        address _referrer
    ) external view returns (ReferralInfo memory) {
        return referralInfoMap[_referrer];
    }

    /// @dev Get `marketPlaceInfo` by marketPlace
    function getMarketplaceInfo(
        address _marketPlace
    ) external view returns (MarketplaceInfo memory) {
        return marketPlaceInfoMap[_marketPlace];
    }
}
