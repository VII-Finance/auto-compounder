# AutoCompounder

A permissionless, immutable auto-compounder for Uniswap v4 LP positions.

- **Permissionless:** anyone can call `compound`. No keeper, no allowlist.
- **Immutable:** no owner, no admin, no upgrades. `POSITION_MANAGER` and `PERCENTAGE` are fixed at deployment.

Unclaimed fees sit in a position. Anyone may collect them, but only in the same transaction that increases that
position's liquidity by a fixed percentage (e.g. 0.2%). Once fees exceed the cost of that increase plus gas,
compounding is profitable, and searchers compete to do it. The LP gets a growing position without paying gas or
running a keeper. Same pattern as Uniswap's Token Jar or liquidations: a growing on-chain prize, claimable only by
doing something good for the protocol.

Inspired by [this tweet from Hayden Adams](https://x.com/haydenzadams/status/2085485550707052933).

## For LPs

To get started, collect any fees already accrued and approve `AutoCompounder` for your position on the v4 `PositionManager`.

From then on, searchers grow your position by `PERCENTAGE` each time they claim its fees. `PERCENTAGE` is in millionths (2_000 = 0.2%). They can't withdraw
principal or change the range. Revoke the approval to opt out.

## For searchers

In one transaction, send the tokens needed to PositionManager (or ETH as `msg.value`) and call
`compound(tokenIds, currencies, recipient, deadline)`. The contract adds `PERCENTAGE` liquidity to each position.
Accrued fees pay for it, and the surplus goes to `recipient`. If fees don't cover the increase, your tokens make up
the difference. `currencies` must list every currency the positions use.


## Usage

```shell
forge build
forge test
forge coverage
```
