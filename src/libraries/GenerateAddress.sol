// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @title GenerateAddress
 * @dev Library of generate address
 * @dev Generate address for maker, offer, holding and market place
 */
library GenerateAddress {
    /// @dev Generate address for maker address with id
    function generateMakerAddress(uint256 _id) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(_id, "maker")))));
    }

    /// @dev Generate address for offer address with id
    function generateOfferAddress(uint256 _id) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(_id, "offer")))));
    }

    /// @dev Generate address for holding address with id
    function generateHoldingAddress(uint256 _id) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(_id, "holding")))));
    }

    /// @dev Generate address for market place address with name
    function generateMarketplaceAddress(
        string memory _marketPlaceName
    ) internal pure returns (address) {
        return
            address(uint160(uint256(keccak256(abi.encode(_marketPlaceName)))));
    }
}
