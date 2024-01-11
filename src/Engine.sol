// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {getPairID, addLiquidity, removeLiquidity, swap, Strike} from "src/Pair.sol";

contract Engine {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    error InvalidStrikeHash();

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    enum Commands {
        Swap,
        WrapWETH,
        UnwrapWETH,
        AddLiquidity,
        RemoveLiquidity
    }

    enum TokenSelector {
        Token0,
        Token1
    }

    struct CommandInput {
        Commands command;
        bytes input;
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        Strike strike;
        uint256 amount;
    }

    struct RemoveLiquidityParams {
        address token0;
        address token1;
        Strike strike;
        uint256 amount;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    address payable immutable weth;

    mapping(bytes32 pairID => mapping(uint256 strike => bytes32)) public strikeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                              CONSTRUCTOR
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    constructor(address payable _weth) {
        weth = _weth;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function execute(CommandInput[] calldata commandInputs) external {
        unchecked {
            for (uint256 i = 0; i < commandInputs.length; i++) {
                if (commandInputs[i].command == Commands.Swap) {
                    //
                } else if (commandInputs[i].command == Commands.WrapWETH) {
                    //
                } else if (commandInputs[i].command == Commands.UnwrapWETH) {
                    //
                } else if (commandInputs[i].command == Commands.AddLiquidity) {
                    AddLiquidityParams memory params = abi.decode(commandInputs[i].input, (AddLiquidityParams));

                    bytes32 strikeHash = keccak256(abi.encode(params.strike));
                    bytes32 pairID = getPairID(params.token0, params.token1);

                    if (strikeHashes[pairID][params.strike.ratio] != strikeHash) revert InvalidStrikeHash();

                    addLiquidity(params.strike, params.amount);

                    strikeHashes[pairID][params.strike.ratio] = keccak256(abi.encode(params.strike));
                } else if (commandInputs[i].command == Commands.RemoveLiquidity) {
                    RemoveLiquidityParams memory params = abi.decode(commandInputs[i].input, (RemoveLiquidityParams));

                    bytes32 strikeHash = keccak256(abi.encode(params.strike));
                    bytes32 pairID = getPairID(params.token0, params.token1);

                    if (strikeHashes[pairID][params.strike.ratio] != strikeHash) revert InvalidStrikeHash();

                    removeLiquidity(params.strike, params.amount);

                    strikeHashes[pairID][params.strike.ratio] = keccak256(abi.encode(params.strike));
                }
            }
        }
    }
}
