// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @title IWrappedNativeToken
 * @dev Interface of WrappedNativeToken, such as WETH
 */
interface IWrappedNativeToken {
    /**
     * @dev Deposit WrappedNativeToken
     * @dev transfer native token to this contract and get WETH
     */
    function deposit() external payable;

    /**
     * @dev Withdraw WrappedNativeToken
     * @dev Transfer WETH to native token
     * @param wad Amount of WETH
     */
    function withdraw(uint256 wad) external;
}
