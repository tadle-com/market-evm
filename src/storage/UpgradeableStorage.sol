// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {ITadleFactory} from "../factory/ITadleFactory.sol";

/**
 * @title UpgradeableStorage
 * @notice This contrct serves as the storage of SystemConfig, PreMarkets, DeliveryPlace, CapitalPool and TradingHall.
 * @notice the first storage slot is used as admin.
 * @notice the second storage slot is used as tadle factory.
 * @notice Total Storage Gaps: 50, UnUsed Storage Slots: 48.
 */
contract UpgradeableStorage {
    /// @dev storage slot is 0
    address public admin;

    /// @dev storage slot is 1
    ITadleFactory public tadleFactory;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
