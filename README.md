# Tadle Protocol

[//]: # 'contest-details-open'

### Prize Pool TO BE FILLED OUT BY CYFRIN

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

Our first product, the Points Marketplace, empowers projects to unlock the liquidity and value of points systems before conducting the Token Generation Event (TGE). By facilitating seamless trading and providing a secure, trustless environment, Tadle ensures that your community can engage with your tokens and points dynamically and efficiently.

[Documentation](https://tadle.gitbook.io/tadle)
[Website](https://tadle.com)
[Twitter](https://x.com/tadle_com)
[GitHub](https://github.com/tadle-com/market-evm)
```

## Actors

```
- Create Buy Offer
- Create Sell Offer
- Place Taker Orders
- Know Your Numbers on Dashboard
- Relist Stocks as New Offers
- Cancel Your Offer
- Abort Your Offer
- Deliver Tokens During Settlement
- Fetch Balances Info 
- Withdraw Fund from Your Balances
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
│   ├── IPerMarkets.sol
│   ├── ISystemConfig.sol
│   └── ITokenManager.sol
├── libraries
│   ├── MarketPlaceLibraries.sol
│   └── OfferLibraries.sol
└── storage
    ├── CapitalPoolStorage.sol
    ├── DeliveryPlaceStorage.sol
    ├── OfferStatus.sol
    ├── PerMarketsStorage.sol
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
      - ERC20
```

[//]: # 'scope-close'
[//]: # 'getting-started-open'

## Setup

Example:

Build:

```bash
forge init

forge install OpenZeppelin/openzeppelin-contracts

forge build
```

Tests:

```bash
Forge test
```

[//]: # 'getting-started-close'
[//]: # 'known-issues-open'
