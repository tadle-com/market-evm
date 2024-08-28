// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ITadleFactory} from "./ITadleFactory.sol";
import {Address} from "../libraries/Address.sol";
import {UpgradeableProxy} from "../proxy/UpgradeableProxy.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title TadleFactory
 * @dev The factory deployment contract for the Tadle project
 * @notice Guardian address in constructor is a msig.
 */
contract TadleFactory is Context, ITadleFactory {
    using Address for address;

    /// @dev Address of guardian, who can deploy related contracts
    /// @notice Guardian only can be used to deploy and upgrade related contract
    address public guardian;

    /**
     * @dev mapping of related contracts, deployed by factory
     *      1 => SystemConfig
     *      2 => PreMarkets
     *      3 => DeliveryPlace
     *      4 => CapitalPool
     *      5 => TokenManager
     */
    mapping(uint256 => address) public relatedContracts;

    modifier onlyGuardian() {
        if (msg.sender != guardian) {
            revert CallerIsNotGuardian(guardian, msg.sender);
        }
        _;
    }

    constructor(address _guardian) {
        if (_guardian == address(0x0)) {
            revert Errors.ZeroAddress();
        }

        guardian = _guardian;
    }

    /**
     * @dev Deploy related contract
     * @notice Only call by guardian
     * @param _relatedContractIndex Index of related contract
     * @param _logic Address of logic contract
     * @param _manager The manager of related contract
     */
    function deployUpgradeableProxy(
        uint256 _relatedContractIndex,
        address _logic,
        address _manager
    ) external onlyGuardian returns (address) {
        /// @dev The logic address must be a contract
        if (!_logic.isContract()) {
            revert LogicAddrIsNotContract(_logic);
        }

        if (relatedContracts[_relatedContractIndex] != address(0x0)) {
            revert RelatedContractExist(_relatedContractIndex);
        }

        /// @notice Manager must not the guardian
        if (_manager == guardian) {
            revert Errors.InvalidManager(_manager);
        }

        /// @dev Deploy upgrade proxy
        UpgradeableProxy _proxy = new UpgradeableProxy(
            _logic,
            guardian,
            address(this),
            abi.encodeCall(IUpgradeableProxy.initializeOwnership, (_manager))
        );
        emit RelatedContractDeployed(_relatedContractIndex, address(_proxy));

        relatedContracts[_relatedContractIndex] = address(_proxy);
        return address(_proxy);
    }

    function setGuardian(address _newGuardian) external onlyGuardian {
        guardian = _newGuardian;
        emit GuardianChanged(guardian);
    }
}

interface IUpgradeableProxy {
    function initializeOwnership(address _newOwner) external;
}
