// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @title ICapitalPool
 * @dev Interface of CapitalPool
 */
interface ICapitalPool {
    /**
     * @dev Approve token for token manager
     * @notice Only can be called by token manager
     */
    function approve(
        address tokenAddr,
        uint256 _allowance,
        uint256 _value
    ) external;

    /// @dev Error when approve failed
    error ApproveFailed();
}
