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
 * @notice Contracts for the deposit of funds
 */
contract CapitalPool is CapitalPoolStorage, Rescuable, ICapitalPool {
    constructor() Rescuable() {}

    /**
     * @dev Approve token for token manager
     * @notice Only can be called by token manager
     * @param tokenAddr Address of token
     */
    function approve(
        address tokenAddr,
        uint256 _allowance,
        uint256 _amount
    ) external {
        address tokenManager = tadleFactory.relatedContracts(
            RelatedContractLibraries.TOKEN_MANAGER
        );

        if (msg.sender != tokenManager) {
            revert Errors.Unauthorized();
        }

        if (_allowance != 0x0) {
            _approve(tokenAddr, tokenManager, 0x0);
        }

        _approve(tokenAddr, tokenManager, _amount);
    }

    function _approve(
        address _tokenAddr,
        address _spender,
        uint256 _amount
    ) internal {
        (bool success, ) = _tokenAddr.call(
            abi.encodeCall(IERC20.approve, (_spender, _amount))
        );

        if (!success) {
            revert ApproveFailed();
        }
    }
}
