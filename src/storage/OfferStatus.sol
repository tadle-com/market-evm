// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @dev Offer status
 * @notice Unknown, Virgin, Ongoing, Canceled, Filled, Settling, Settled
 * @param Unknown The offer does not exist.
 * @param Virgin The offer already listed, but no one's buying it.
 * @param Ongoing The offer already listed, and at least one person is buying it.
 * @param Canceled The offer has been canceled.
 * @param Filled The offer has been filled.
 * @param Settling The offer is being settled.
 * @param Settled The offer has been settled.
 */
enum OfferStatus {
    Unknown,
    Virgin,
    Ongoing,
    Canceled,
    Filled,
    Settling,
    Settled
}

/**
 * @dev Offer type
 * @param Ask Create offer to sell projectPoints
 * @param Bid Create offer to buy projectPoints
 */
enum OfferType {
    Ask,
    Bid
}

/**
 * @dev Holding type
 * @notice Ask, Bid
 * @param Ask Create holding to sell projectPoints
 * @param Bid Create holding to buy projectPoints
 */
enum HoldingType {
    Ask,
    Bid
}

/**
 * @dev Holding status
 * @param Unknown The holding does not exist.
 * @param Initialized The holding already exist.
 * @param Finished The holding already settled.
 */
enum HoldingStatus {
    Unknown,
    Initialized,
    Finished
}

/**
 * @dev Offer settle type
 * @param Protected The offer type is protected. the holding taked by this offer need collateral to list.
 * @param Turbo The offer type is turbo
 */
enum OfferSettleType {
    Protected,
    Turbo
}

/**
 * @dev Abort offer status
 * @param Initialized The offer not exist.
 * @param AllocationPropagated Some one take the offer, and relist the holding.
 * @param Aborted The offer has been aborted
 */
enum AbortOfferStatus {
    Initialized,
    AllocationPropagated,
    Aborted
}
