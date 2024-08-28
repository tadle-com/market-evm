// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OfferType} from "../interfaces/IPreMarkets.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title OfferLibraries
 * @dev Library of offer
 * @dev Get deposit amount
 * @dev Get refund amount
 */
library OfferLibraries {
    /**
     * @dev Get deposit collateral amount
     * @dev If create ask offer, return _amount * _collateralRate;
     * @dev If create bid offer, return _amount;
     * @dev If create ask holding, return _amount;
     * @dev If create bid holding, return _amount * _collateralRate;
     * @param _isMaker `_isMaker` is `true` when create offer
     *                    and `_isMaker` is `false` when create holding
     * @param _rounding rounding
     */
    function getDepositCollateralAmount(
        OfferType _offerType,
        uint256 _collateralRate,
        uint256 _amount,
        bool _isMaker,
        Math.Rounding _rounding
    ) internal pure returns (uint256) {
        /// @dev bid offer
        if (_offerType == OfferType.Bid && _isMaker) {
            return _amount;
        }

        /// @dev ask order
        if (_offerType == OfferType.Ask && !_isMaker) {
            return _amount;
        }

        return
            Math.mulDiv(
                _amount,
                _collateralRate,
                Constants.COLLATERAL_RATE_DECIMAL_SCALER,
                _rounding
            );
    }

    /**
     * @dev Get refund amount, offer type
     * @dev If close bid offer, return offer amount - used amount;
     * @dev If close ask offer, return (offer amount - used amount) * collateralRate;
     */
    function getRefundCollateralAmount(
        OfferType _offerType,
        uint256 _quoteTokenAmount,
        uint256 _projectPoints,
        uint256 _usedProjectPoints,
        uint256 _collateralRate
    ) internal pure returns (uint256) {
        uint256 _usedQuoteTokenAmount = Math.mulDiv(
            _quoteTokenAmount,
            _usedProjectPoints,
            _projectPoints,
            Math.Rounding.Up
        );

        if (_offerType == OfferType.Bid) {
            return _quoteTokenAmount - _usedQuoteTokenAmount;
        }

        return
            Math.mulDiv(
                _quoteTokenAmount - _usedQuoteTokenAmount,
                _collateralRate,
                Constants.COLLATERAL_RATE_DECIMAL_SCALER,
                Math.Rounding.Down
            );
    }
}
