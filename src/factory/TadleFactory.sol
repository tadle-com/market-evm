// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ITadleFactory} from "./ITadleFactory.sol";
import {Address} from "../libraries/Address.sol";
import {UpgradeableProxy} from "../proxy/UpgradeableProxy.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title TadleFactory
 * @notice This contrct serves as the factory of Tadle.
 * @notice guardian address in constructor is a msig.
 */
contract TadleFactory is Context, ITadleFactory {
    using Address for address;

    /// @dev address of guardian, who can deploy some contracts
    /// @notice guardian only can be used to deploy and upgrade related contract
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
     * @notice deploy related contract
     * @dev guardian can deploy related contract
     * @param _relatedContractIndex index of related contract
     * @param _logic address of logic contract
     * @param _manager the owner of related contract
     */
    function deployUpgradeableProxy(
        uint256 _relatedContractIndex,
        address _logic,
        address _manager
    ) external onlyGuardian returns (address) {
        /// @dev the logic address must be a contract
        if (!_logic.isContract()) {
            revert LogicAddrIsNotContract(_logic);
        }

        /// @notice guardian only can be used to deploy and upgrade related contract
        if (_manager == guardian) {
            revert Errors.InvalidManager(_manager);
        }

        /// @dev deploy proxy
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
}

interface IUpgradeableProxy {
    function initializeOwnership(address _newOwner) external;
}
