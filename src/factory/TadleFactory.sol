// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
/// @dev Proxy admin contract used in OZ upgrades plugin
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {ITadleFactory} from "./ITadleFactory.sol";
import {Address} from "../libraries/Address.sol";
import {UpgradeableProxy} from "../proxy/UpgradeableProxy.sol";

/**
 * @title TadleFactory
 * @notice This contrct serves as the factory of Tadle.
 * @notice guardian address in constructor is a msig.
 */
contract TadleFactory is Context, ITadleFactory {
    using Address for address;

    /// @dev address of guardian, who can deploy some contracts
    address internal guardian;

    /// @dev address of proxy admin
    address public proxyAdmin;

    /**
     * @dev mapping of related contracts, deployed by factory
     *      1 => SystemConfig
     *      2 => PreMarkets
     *      3 => DeliveryPlace
     *      4 => CapitalPool
     *      5 => TokenManager
     */
    mapping(uint8 => address) public relatedContracts;

    modifier onlyGuardian() {
        if (_msgSender() != guardian) {
            revert CallerIsNotGuardian(guardian, _msgSender());
        }
        _;
    }

    constructor(address _guardian) {
        guardian = _guardian;
    }

    /**
     * @notice deploy related contract
     * @dev guardian can deploy related contract
     * @param _relatedContractIndex index of related contract
     * @param _logic address of logic contract
     * @param _data call data for logic
     */
    function deployUpgradeableProxy(
        uint8 _relatedContractIndex,
        address _logic,
        bytes memory _data
    ) external onlyGuardian returns (address) {
        if (proxyAdmin == address(0x0)) {
            revert UnDepoloyedProxyAdmin();
        }

        /// @dev the logic address must be a contract
        if (!_logic.isContract()) {
            revert LogicAddrIsNotContract(_logic);
        }

        /// @dev deploy proxy
        UpgradeableProxy _proxy = new UpgradeableProxy(
            _logic,
            proxyAdmin,
            address(this),
            _data
        );
        relatedContracts[_relatedContractIndex] = address(_proxy);
        emit RelatedContractDeployed(_relatedContractIndex, address(_proxy));
        return address(_proxy);
    }

    /**
     * @notice deploy proxy admin
     * @dev guardian can deploy proxy admin
     * @param _proxyAdminInitialOwner initial owner of proxy admin
     */
    function deployProxyAdmin(
        address _proxyAdminInitialOwner
    ) external onlyGuardian returns (address) {
        /// @dev deploy proxy admin contract
        /// @notice proxy admin contract is used in OZ upgrades plugin
        /// @param _proxyAdminInitialOwner initial owner of proxy admin
        ProxyAdmin _proxyAdmin = new ProxyAdmin(_proxyAdminInitialOwner);
        proxyAdmin = address(_proxyAdmin);
        emit ProxyAdminDeployed(proxyAdmin);

        return proxyAdmin;
    }
}
