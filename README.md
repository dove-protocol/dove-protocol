<img align="right" width="150" height="150" top="100" src="./assets/dove-logo.png">

# Dove Protocol • ![solidity](https://img.shields.io/badge/solidity-^0.8.15-lightgrey) ![license](https://img.shields.io/github/license/whitenois3/dove-protocol?label=license)

Unified liquidity, accessible anywhere.

## What is Dove?

Dove is our take on the decentralized AMM, dAMM, idea that was formulated by Brecht Devos and Louis Guthmann. You can find their original post [here](https://ethresear.ch/t/damm-an-l2-powered-amm/10352).

In short ; liquidity stays on L1, trading happens on L2.

Read more [here](https://www.notion.so/0xst/Dove-Protocol-5a174626e63f4c26a30e753fc7460714).

The interface is deployed [here](https://dove.whitenoise.rs/).

## Licensing

The only files subject to the Business Source License 1.1 (`BUSL-1.1`) are [`Dove.sol`](src/L1/Dove.sol) and [`Pair.sol`](src/L2/Pair.sol). See [`LICENSE`](./LICENSE).
All the other files fall under the `AGPL-3.0-only` license.

## Acknowledgements

- [dAMM: An L2-Powered AMM](https://ethresear.ch/t/damm-an-l2-powered-amm/10352)
- [femplate](https://github.com/abigger87/femplate)
- [foundry](https://github.com/foundry-rs/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [solady](https://github.com/Vectorized/solady)
- [forge-std](https://github.com/brockelmore/forge-std)
- [forge-template](https://github.com/foundry-rs/forge-template)
- [foundry-toolchain](https://github.com/foundry-rs/foundry-toolchain)

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
