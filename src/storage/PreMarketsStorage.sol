// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {UpgradeableStorage} from "./UpgradeableStorage.sol";

import {OfferStatus} from "./OfferStatus.sol";
import {OfferInfo, HoldingInfo, MakerInfo} from "../interfaces/IPreMarkets.sol";

/**
 * @title PreMarketsStorage
 * @notice This contrct serves as the storage of PerMarkets
 * @notice The top 50 storage slots are used for upgradeable storage.
 * @notice The 50th to 150th storage slots are used for PerMarkets.
 */
contract PreMarketsStorage is UpgradeableStorage {
    /// @dev the last offer id. increment by 1
    /// @notice the storage slot is 50
    uint256 public offerId;

    /// @dev offer account => offer info.
    /// @notice the storage slot is 51
    mapping(address => OfferInfo) public offerInfoMap;

    /// @dev holding account => holding info.
    /// @notice the storage slot is 52
    mapping(address => HoldingInfo) public holdingInfoMap;

    /// @dev maker account => maker info.
    /// @notice the storage slot is 53
    mapping(address => MakerInfo) public makerInfoMap;

    /// @dev rollin at
    /// @notice the storage slot is 54
    mapping(address => uint256) public rollinAtMap;

    /// @dev empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    /// start from slot 55, end at slot 149
    uint256[95] private __gap;
}
