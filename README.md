<img align="right" width="150" height="150" top="100" src="./assets/dove.png">

# Dove Protocol • ![solidity](https://img.shields.io/badge/solidity-^0.8.15-lightgrey)

Provide liquidity on L1, trade on L2.

Minimized risks, maximized security.

## What is Dove?

Dove is our take on the decentralized AMM dAMM idea that was formulated by Brecht Devos and Louis Guthmann. You can find their original post [here](https://ethresear.ch/t/damm-an-l2-powered-amm/10352).

The liquidity and pricing logics are separated. Liquidity is on L1, trading happens on L2s.

It also means that for any given pair, multiple AMMs on different layers will share the same liquidity, it’s **amplified**. It exposes the LPs to potentially much more trades, thus more fees. It’s a more efficient use of liquidity and helps to solve the liquidity fragmentation problem.

Read more [here](https://www.notion.so/0xst/Dove-Protocol-5a174626e63f4c26a30e753fc7460714).

## Deployments

|      | Goerli                                             | Arbitrum Goerli                                    | Mumbai                                             |
| ---- | -------------------------------------------------- | -------------------------------------------------- | -------------------------------------------------- |
| dAMM | [0x18e02D08CCEb8509730949954e904534768f1536][key1] |                                                    |                                                    |
| AMM  |                                                    | [0xE7b3CcEb43b247664784836572af31dac522E148][key2] | [0xC51eFC8C3E3b8708c6f496FDa57ac33931CDB0c8][key3] |

[key1]: https://goerli.etherscan.io/address/0x18e02D08CCEb8509730949954e904534768f1536
[key2]: https://goerli.arbiscan.io/address/0xe7b3cceb43b247664784836572af31dac522e148
[key3]: https://mumbai.polygonscan.com/address/0xC51eFC8C3E3b8708c6f496FDa57ac33931CDB0c8

## Warning

This is a very very rough MVP. It is **not** gas-optimized, it is **not** 100% safe, it is **incomplete**.

The tests are **incomplete**.

For the moment, consider this protocol as purely for experimental and pedagogical goals.

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
