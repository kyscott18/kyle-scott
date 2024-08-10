# Building a Better Decentralized Exchange

I am building a new protocol in response to the deceleration of decentralized exchange technology. No existing protocol is sufficient. In many aspects, I hope this effort will be considered a **return to form**.

The idea is simple: Production-grade exchange infrastructure iteratively simplified and refined. No compromises on neutrality, security, or decentralization will be made. The only motivation is progress.

## Summary

The protocol provides the same basic functionality as almost every other automated market maker: add liquidity, remove liquidity, and swap. Specifically, it is an aggregation of many separate exchanges, each with their own trading invariant. This design is commonly referred to as "concentrated liquidity".

The protocol follows the transaction supply chain to its logical conclusion. Instead of traders sending their trades directly to the protocol, it is assumed that swaps first pass through a specialized trading system, where buyers and sellers are matched, and a common clearing price is found. The aggregate, or leftover, trades are then settled onto decentralized exchanges.

There are a lot of up-front gas savings from this architecture. These can be seen in the benchmarks below. It is less obvious and more profound that this shifts the unit economics and available app experiences.

## Economic Model

Many assumptions are made about the information and motivation of interacting accounts. Some may not be true today, but represent the future direction of the market.

- All swaps are performed by arbitrageurs
- Arbitrageurs have the most accurate price information and exclusively maximize profits
- Arbitrageurs operate in a winner-take-all fashion, therefore one arbitrage event occurs per block

## Technical

_Simplicity is the soul of good engineering._

The main invariant of the protocol is `x + p * y = l`. This invariant is enforced on each trade. "p" represents the exchange rate, in units x per y. An exchange is uniquely identified by a token pair and exchange rate.

A trade on the protocol consists of information identifying which exchange to act on and the resulting state of the exchange after the trade is complete. Every trade is deterministic at transaction generation time. The smart contract allows for efficient execution of a trade. An in-memory account system keeps track of intermediate balance changes, and then settles using a callback at the end of the transaction.

At a higher level, smart contracts are used to validate, resolve, and store data. Much business logic is moved off-chain, where compute is essentially free. Low gas is extremely important, specifically the gas costs of swapping between the tokens in an exchange.

A key optimization is made using a technique called "representment" to minimize storage slot access. Instead of storing the state of each exchange, only the hash of the state of the exchange is stored. With more research, it may be possible to store the entire state of the protocol in one 32 byte hash.

## Benchmarks

|                      | `kyle-scott` | Uniswap v3 |
|----------------------|--------------|------------|
| Add Liquidity (Cold) |       96,731 |    295,220 |
| Add Liquidity (Hot)  |       79,631 |    144,646 |
| Remove Liquidity     |       82,354 |    158,917 |
| Swap                 |       83,133 |    125,117 |
| SLOC                 |          213 |      a lot |

## Security

The protocol is not currently ready for production use. It lacks:

- Multiple implementations
- Fuzz + invariant testing
- Large Lindy Effect measured in days x $

## Roadmap

- [x] Basic
- [x] Fees
- [x] Drift
- [x] Reserved swaps
- [ ] Flatcoin
