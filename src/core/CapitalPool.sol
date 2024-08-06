// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CapitalPoolStorage} from "../storage/CapitalPoolStorage.sol";
import {ICapitalPool} from "../interfaces/ICapitalPool.sol";
import {RelatedContractLibraries} from "../libraries/RelatedContractLibraries.sol";
import {Rescuable} from "../utils/Rescuable.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title CapitalPool
 * @notice Implement the capital pool
 */
contract CapitalPool is CapitalPoolStorage, Rescuable, ICapitalPool {
    constructor() Rescuable() {}

    /**
     * @dev Approve token for token manager
     * @notice only can be called by token manager
     * @param tokenAddr address of token
     */
    function approve(address tokenAddr) external {
        address tokenManager = tadleFactory.relatedContracts(
            RelatedContractLibraries.TOKEN_MANAGER
        );

        if (msg.sender != tokenManager) {
            revert Errors.Unauthorized();
        }

        (bool success, ) = tokenAddr.call(
            abi.encodeCall(IERC20.approve, (tokenManager, type(uint256).max))
        );

        if (!success) {
            revert ApproveFailed();
        }
    }
}
