// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {AbortOfferStatus} from "../storage/OfferStatus.sol";

/**
 * @title Errors
 * @dev Library of errors
 * @notice Add new errors here
 */
library Errors {
    /// @dev Error when contract is not deployed
    error ContractIsNotDeployed();

    /**
     * @dev Error when not enough msg value
     * @param _msgValue msg value
     * @param _amount transfer amount
     */
    error NotEnoughMsgValue(uint256 _msgValue, uint256 _amount);

    /// @dev Error when zero address
    error ZeroAddress();

    /// @dev Error when amount is zero
    error AmountIsZero();

    /// @dev Error when unauthorized
    error Unauthorized();

    /// @dev Error when invalid manager
    error InvalidManager(address _manager);

    /// @dev Error when mismatched market place status
    error MismatchedMarketplaceStatus();

    error RollinTooSoon(uint256);

    /// @dev Error when invalid receipt address
    error InvalidReceiptAddress(address);

    error InvalidAbortOfferStatus(
        AbortOfferStatus _expected,
        AbortOfferStatus _actual
    );
}
