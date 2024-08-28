// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

// Upgradeable Proxy contract used in OZ upgrades plugin
// @notice The version of OZ contracts is `4.9.0`
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ITadleFactory} from "../factory/ITadleFactory.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title UpgradeableProxy
 * @notice This contrct is based on TransparentUpgradeableProxy.
 * @dev This contrct serves as the proxy of SystemConfig, PreMarkets, DeliveryPlace, CapitalPool and TokenManager.
 * @notice The first storage slot is used as tadle factory.
 * @notice Total Storage Gaps: 50, UnUsed Storage Slots: 49.
 */
contract UpgradeableProxy is TransparentUpgradeableProxy {
    ITadleFactory public tadleFactory;

    /**
     * @param _logic Address of logic contract
     * @param _admin Address of admin, who can upgrade proxy
     * @param _data Call data for logic
     */
    constructor(
        address _logic,
        address _admin,
        address _tadleFactory,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, _admin, _data) {
        tadleFactory = ITadleFactory(_tadleFactory);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
