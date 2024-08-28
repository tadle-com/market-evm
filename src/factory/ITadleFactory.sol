// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

interface ITadleFactory {
    /// @dev Get related contract address by index
    function relatedContracts(uint256 _index) external view returns (address);

    /// @dev Emit event when related contract is deployed
    /// @param _index Index of related contract
    /// @param _contractAddr Address of related contract
    event RelatedContractDeployed(uint256 _index, address _contractAddr);

    event GuardianChanged(address _guardian);

    /// @dev Error when caller is not guardian
    error CallerIsNotGuardian(address _guardian, address _msgSender);

    /// @dev Error when logic address is not a contract
    error LogicAddrIsNotContract(address _logic);

    error RelatedContractExist(uint256 _index);
}
