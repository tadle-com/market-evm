# Tadle Protocol

[//]: # 'contest-details-open'

### Prize Pool

-   Total Pool -
-   H/M -
-   Low -
-   Community Judging -

-   Starts:
-   Ends:

-   nSLOC:
-   Complexity Score:

## About the Project

```
Tadle is a cutting-edge pre-market infrastructure designed to unlock illiquid assets in the crypto pre-market.

Our first product, the Points Marketplace, empowers projects to unlock the liquidity and value of projectPoints systems before conducting the Token Generation Event (TGE). By facilitating seamless trading and providing a secure, trustless environment, Tadle ensures that your community can engage with your tokens and projectPoints dynamically and efficiently.

[Documentation](https://tadle.gitbook.io/tadle)
[Website](https://tadle.com)
[Twitter](https://x.com/tadle_com)
[GitHub](https://github.com/tadle-com/market-evm)
```

## Actors

```
Maker
- Create buy offer
- Create sell offer
- Cancel your offer
- Abort your offer

Holding
- Place holding orders
- Relist holdings as new offers

Sell Offer Maker
- Deliver tokens during settlement

General User
- Fetch balances info
- Withdraw funds from your balances

Admin (Trust)
- Create a marketplace
- Take a marketplace offline
- Initialize system parameters, like WETH contract address, referral commission rate, etc.
- Set up collateral token list, like ETH, USDC, LINK, ankrETH, etc.
- Set `TGE` parameters for settlement, like token contract address, TGE time, etc.
- Grant privileges for users’ commission rates
- Pause all the markets

```

[//]: # 'contest-details-close'
[//]: # 'scope-open'

## Scope (contracts)

```js
src
├── core
│   ├── CapitalPool.sol
│   ├── DeliveryPlace.sol
│   ├── PreMarkets.sol
│   ├── SystemConfig.sol
│   └── TokenManager.sol
├── factory
│   ├── ITadleFactory.sol
│   └── TadleFactory.sol
├── interfaces
│   ├── ICapitalPool.sol
│   ├── IDeliveryPlace.sol
│   ├── IPreMarkets.sol
│   ├── ISystemConfig.sol
│   └── ITokenManager.sol
├── libraries
│   ├── MarketplaceLibraries.sol
│   └── OfferLibraries.sol
└── storage
    ├── CapitalPoolStorage.sol
    ├── DeliveryPlaceStorage.sol
    ├── OfferStatus.sol
    ├── PreMarketsStorage.sol
    ├── SystemConfigStorage.sol
    └── TokenManagerStorage.sol
```

## Compatibilities

```
Compatibilities:
  Blockchains:
      - Ethereum/Any EVM
  Tokens:
      - ETH
      - WETH
      - ERC20 (any token that follows the ERC20 standard)
```

[//]: # 'scope-close'
[//]: # 'getting-started-open'

## Setup

Prerequisites:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 --no-commit
```

Build:

```bash
forge build
```

Tests:

```bash
forge test -vvv
```

[//]: # 'getting-started-close'
[//]: # 'known-issues-open'
