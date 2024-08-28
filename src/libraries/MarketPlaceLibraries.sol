// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {MarketplaceInfo, MarketplaceStatus} from "../interfaces/ISystemConfig.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title MarketplaceLibraries
 * @dev Library of market place
 * @dev Get status of market place
 * @dev Check status of market place
 */
library MarketplaceLibraries {
    /**
     * @dev Get status of market place
     * @dev block timestamp is larger than tge + settlementPeriod, return `BidSettling`
     * @dev block timestamp is larger than tge, return `AskSettling`
     */
    function getMarketplaceStatus(
        uint256 _blockTimestamp,
        MarketplaceInfo memory _marketPlaceInfo
    ) internal pure returns (MarketplaceStatus) {
        if (_marketPlaceInfo.status == MarketplaceStatus.Offline) {
            return MarketplaceStatus.Offline;
        }

        /// @dev settle not active
        if (_marketPlaceInfo.tge == 0) {
            return _marketPlaceInfo.status;
        }

        if (
            _blockTimestamp >
            _marketPlaceInfo.tge + _marketPlaceInfo.settlementPeriod
        ) {
            return MarketplaceStatus.BidSettling;
        }

        if (_blockTimestamp > _marketPlaceInfo.tge) {
            return MarketplaceStatus.AskSettling;
        }

        return _marketPlaceInfo.status;
    }

    /**
     * @dev Check status of market place
     * @dev true if marketStatus == `_status`
     */
    function checkMarketplaceStatus(
        MarketplaceInfo memory _marketPlaceInfo,
        uint256 _blockTimestamp,
        MarketplaceStatus _status
    ) internal pure {
        MarketplaceStatus status = getMarketplaceStatus(
            _blockTimestamp,
            _marketPlaceInfo
        );

        if (status != _status) {
            revert Errors.MismatchedMarketplaceStatus();
        }
    }
}
