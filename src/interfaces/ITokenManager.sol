// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @title ITokenManager
 * @dev Interface of TokenManager
 */
interface ITokenManager {
    /**
     * @dev Till in, token from user to capital pool
     * @param accountAddress user address
     * @param tokenAddress token address
     * @param tokenAmount amount of token
     * @param isPointToken is point token
     */
    function deposit(
        address accountAddress,
        address tokenAddress,
        uint256 tokenAmount,
        bool isPointToken
    ) external payable;

    /**
     * @dev Add token balance
     * @param tokenBalanceType token balance type
     * @param accountAddress user address
     * @param tokenAddress token address
     * @param tokenAmount the claimable amount of token
     */
    function addTokenBalance(
        TokenBalanceType tokenBalanceType,
        address accountAddress,
        address tokenAddress,
        uint256 tokenAmount
    ) external;

    /**
     * @notice Update platform fee
     * @dev Caller must be related contracts
     */
    function updatePlatformFee(
        address tokenAddress,
        uint256 platformFee
    ) external;

    /// @dev Emit events when till in
    event Deposit(
        address indexed accountAddress,
        address indexed tokenAddress,
        uint256 tokenAmount,
        bool isPointToken
    );

    /// @dev Emit events when initialize
    event Initialize(address _wrappedNativeToken);

    /// @dev Emit events when add token balance
    event AddTokenBalance(
        address indexed accountAddress,
        address indexed tokenAddress,
        TokenBalanceType indexed tokenBalanceType,
        uint256 tokenAmount
    );

    /// @dev Emit events when withdraw
    event Withdraw(
        address indexed authority,
        address indexed tokenAddress,
        TokenBalanceType indexed tokenBalanceType,
        uint256 withdrawAmount
    );

    /// @dev Emit events when update token white list
    event UpdateTokenWhitelisted(
        address indexed tokenAddress,
        bool isWhitelisted
    );

    /// @dev Emit events when update platform fee
    event UpdatePlatformFee(address indexed tokenAddress, uint256 platformFee);

    /// @dev Emit events when withdraw platform fee
    event WithdrawPlatformFee(
        address indexed tokenAddress,
        address indexed receiptAddress,
        uint256 platformFee
    );

    /// @dev Error when token is not whitelisted
    error TokenIsNotWhitelisted(address tokenAddress);
}

/**
 * @dev Token balance type
 */
enum TokenBalanceType {
    TaxIncome,
    ReferralBonus,
    SalesRevenue,
    RemainingCash,
    MakerRefund,
    PointToken
}
