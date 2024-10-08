// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {TokenManagerStorage} from "../storage/TokenManagerStorage.sol";
import {ITadleFactory} from "../factory/ITadleFactory.sol";
import {ITokenManager, TokenBalanceType} from "../interfaces/ITokenManager.sol";
import {ICapitalPool} from "../interfaces/ICapitalPool.sol";
import {IWrappedNativeToken} from "../interfaces/IWrappedNativeToken.sol";
import {RelatedContractLibraries} from "../libraries/RelatedContractLibraries.sol";
import {Rescuable} from "../utils/Rescuable.sol";
import {Related} from "../utils/Related.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title TokenManager
 * @dev 1. Till in: Tansfer token from msg sender to capital pool
 *      2. Withdraw: Transfer token from capital pool to msg sender
 * @notice Only support ERC20 or native token
 * @notice Only support white listed token
 */
contract TokenManager is
    TokenManagerStorage,
    ReentrancyGuard,
    Rescuable,
    Related,
    ITokenManager
{
    constructor() Rescuable() {}

    modifier onlyInTokenWhitelist(bool _isPointToken, address _tokenAddress) {
        if (!_isPointToken && !tokenWhitelisted[_tokenAddress]) {
            revert TokenIsNotWhitelisted(_tokenAddress);
        }

        _;
    }

    /**
     * @notice Set wrapped native token
     * @dev Caller must be owner
     * @param _wrappedNativeToken Wrapped native token
     */
    function initialize(address _wrappedNativeToken) external onlyOwner {
        if (wrappedNativeToken != address(0x0)) {
            revert Errors.ZeroAddress();
        }

        wrappedNativeToken = _wrappedNativeToken;

        emit Initialize(_wrappedNativeToken);
    }

    /**
     * @notice Till in, Transfer token from msg sender to capital pool
     * @param _accountAddress Account address
     * @param _tokenAddress Token address
     * @param _amount Transfer amount
     * @param _isPointToken The transfer token is pointToken
     * @notice Capital pool should be deployed
     * @dev Support ERC20 token and native token
     */
    function deposit(
        address _accountAddress,
        address _tokenAddress,
        uint256 _amount,
        bool _isPointToken
    )
        external
        payable
        nonReentrant
        onlyRelatedContracts(tadleFactory, msg.sender)
        onlyInTokenWhitelist(_isPointToken, _tokenAddress)
    {
        /// @notice amount must be greater than 0
        if (_amount == 0) {
            revert Errors.NotEnoughMsgValue(msg.value, 0);
        }

        address capitalPoolAddr = tadleFactory.relatedContracts(
            RelatedContractLibraries.CAPITAL_POOL
        );
        if (capitalPoolAddr == address(0x0)) {
            revert Errors.ContractIsNotDeployed();
        }

        if (_tokenAddress == wrappedNativeToken) {
            /**
             * @dev token is native token
             * @notice check msg value
             * @dev if msg value is less than _amount, revert
             * @dev wrap native token and transfer to capital pool
             */
            if (msg.value != _amount) {
                revert Errors.NotEnoughMsgValue(msg.value, _amount);
            }
            IWrappedNativeToken(wrappedNativeToken).deposit{value: _amount}();
            _safe_transfer(wrappedNativeToken, capitalPoolAddr, _amount);
        } else {
            if (msg.value != 0) {
                revert Errors.NotEnoughMsgValue(msg.value, 0);
            }

            /// @notice token is ERC20 token
            _transfer(
                _tokenAddress,
                _accountAddress,
                capitalPoolAddr,
                _amount,
                capitalPoolAddr
            );
        }

        emit Deposit(_accountAddress, _tokenAddress, _amount, _isPointToken);
    }

    /**
     * @notice Add token balance
     * @dev Caller must be related contracts
     * @param _tokenBalanceType Token balance type
     * @param _accountAddress Account address
     * @param _tokenAddress Token address
     * @param _amount Claimable amount
     */
    function addTokenBalance(
        TokenBalanceType _tokenBalanceType,
        address _accountAddress,
        address _tokenAddress,
        uint256 _amount
    ) external onlyRelatedContracts(tadleFactory, msg.sender) {
        userTokenBalanceMap[_accountAddress][_tokenAddress][
            _tokenBalanceType
        ] += _amount;

        emit AddTokenBalance(
            _accountAddress,
            _tokenAddress,
            _tokenBalanceType,
            _amount
        );
    }

    /**
     * @notice Update platform fee
     * @dev Caller must be related contracts
     */
    function updatePlatformFee(
        address _tokenAddress,
        uint256 _platformFee
    ) external onlyRelatedContracts(tadleFactory, msg.sender) {
        platformFeeMap[_tokenAddress] += _platformFee;

        emit UpdatePlatformFee(_tokenAddress, _platformFee);
    }

    /**
     * @notice Withdraw
     * @param _tokenAddress Token address
     * @param _tokenBalanceType Token balance type
     */
    function withdraw(
        address _tokenAddress,
        TokenBalanceType _tokenBalanceType
    ) external nonReentrant whenNotPaused {
        uint256 claimAbleAmount = userTokenBalanceMap[msg.sender][
            _tokenAddress
        ][_tokenBalanceType];

        if (claimAbleAmount == 0) {
            revert Errors.AmountIsZero();
        }

        userTokenBalanceMap[msg.sender][_tokenAddress][_tokenBalanceType] = 0;
        _withdraw(_tokenAddress, msg.sender, claimAbleAmount);

        emit Withdraw(
            msg.sender,
            _tokenAddress,
            _tokenBalanceType,
            claimAbleAmount
        );
    }

    /**
     * @notice Withdraw
     * @dev Caller must be manager
     */
    function withdrawPlatformFee(
        address _tokenAddress,
        address _receiptAddress
    ) external onlyOwner {
        if (_receiptAddress == address(0x0)) {
            revert Errors.InvalidReceiptAddress(_receiptAddress);
        }

        uint256 claimAbleAmount = platformFeeMap[_tokenAddress];

        if (claimAbleAmount == 0) {
            revert Errors.AmountIsZero();
        }

        _withdraw(_tokenAddress, _receiptAddress, claimAbleAmount);

        platformFeeMap[_tokenAddress] = 0;
        emit WithdrawPlatformFee(
            _tokenAddress,
            _receiptAddress,
            claimAbleAmount
        );
    }

    /**
     * @notice Update token white list
     * @dev Caller must be manager
     * @param _tokens Token addresses
     * @param _isWhitelisted Is white listed
     */
    function updateTokenWhitelisted(
        address[] calldata _tokens,
        bool _isWhitelisted
    ) external onlyOwner {
        uint256 _tokensLength = _tokens.length;

        for (uint256 i = 0; i < _tokensLength; ) {
            _updateTokenWhitelisted(_tokens[i], _isWhitelisted);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal Function: Update token white list
     * @param _token Token address
     * @param _isWhitelisted Is white listed
     */
    function _updateTokenWhitelisted(
        address _token,
        bool _isWhitelisted
    ) internal {
        tokenWhitelisted[_token] = _isWhitelisted;

        emit UpdateTokenWhitelisted(_token, _isWhitelisted);
    }

    function _withdraw(
        address _tokenAddress,
        address _receiptAddress,
        uint256 _amount
    ) internal {
        address capitalPoolAddr = tadleFactory.relatedContracts(
            RelatedContractLibraries.CAPITAL_POOL
        );

        if (_tokenAddress == wrappedNativeToken) {
            /**
             * @dev token is native token
             * @dev transfer from capital pool to receipt address
             * @dev withdraw native token to token manager contract
             * @dev transfer native token to msg sender
             */
            _transfer(
                wrappedNativeToken,
                capitalPoolAddr,
                address(this),
                _amount,
                capitalPoolAddr
            );

            IWrappedNativeToken(wrappedNativeToken).withdraw(_amount);
            (bool sent, ) = payable(_receiptAddress).call{value: _amount}("");
            if (!sent) {
                revert TransferFailed();
            }
        } else {
            /**
             * @dev token is ERC20 token
             * @dev transfer from capital pool to receipt address
             */

            _transfer(
                _tokenAddress,
                capitalPoolAddr,
                _receiptAddress,
                _amount,
                capitalPoolAddr
            );
        }
    }

    /**
     * @notice Internal Function: Transfer token
     * @dev Transfer ERC20 token
     * @param _token ERC20 token address
     * @param _from From address
     * @param _to To address
     * @param _amount Transfer amount
     */
    function _transfer(
        address _token,
        address _from,
        address _to,
        uint256 _amount,
        address _capitalPoolAddr
    ) internal {
        uint256 fromBalanceBef = IERC20(_token).balanceOf(_from);
        uint256 toBalanceBef = IERC20(_token).balanceOf(_to);

        uint256 _allowance = IERC20(_token).allowance(_from, address(this));
        if (_from == _capitalPoolAddr && _allowance < _amount) {
            ICapitalPool(_capitalPoolAddr).approve(_token, _allowance, _amount);
        }

        _safe_transfer_from(_token, _from, _to, _amount);

        uint256 fromBalanceAft = IERC20(_token).balanceOf(_from);
        uint256 toBalanceAft = IERC20(_token).balanceOf(_to);

        if (fromBalanceAft != fromBalanceBef - _amount) {
            revert TransferFailed();
        }

        if (toBalanceAft != toBalanceBef + _amount) {
            revert TransferFailed();
        }
    }
}
