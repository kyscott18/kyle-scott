// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {ICallback, Engine, Exchange, ExchangeState} from "src/Engine.sol";
import {Q128} from "src/Math.sol";
import {Position} from "src/Position.sol";

contract ExecuteTest is Test, ICallback {
    Engine private engine;
    MockERC20 private mockERC20_0;
    MockERC20 private mockERC20_1;
    bytes32 private exchangeID;

    uint256 private amount0;
    uint256 private amount1;
    uint256 private liquidity;

    function setUp() external {
        engine = new Engine();
        mockERC20_0 = new MockERC20("Mock ERC20", "MOCK", 18);
        mockERC20_1 = new MockERC20("Mock ERC20", "MOCK", 18);

        mockERC20_0.mint(address(this), 1);
        mockERC20_1.mint(address(this), 1);
        mockERC20_0.mint(address(engine), 1);
        mockERC20_1.mint(address(engine), 1);
    }

    function callback(bytes calldata) external {
        if (amount0 > 0) mockERC20_0.mint(msg.sender, amount0);
        if (amount1 > 0) mockERC20_1.mint(msg.sender, amount1);
        if (liquidity > 0) {
            engine.transfer_XXXXXX(msg.sender, Position.ILRTATransferDetails(exchangeID, liquidity));
        }
    }

    function test_AddLiquidity_Cold() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: 0,
                    drift: 0
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount0 = 1e18;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        amount0 = 0;

        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 1e18);

        exchangeID = bytes32(0);

        vm.resumeGasMetering();
    }

    function test_AddLiquidity_Hot() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: 0,
                    drift: 0
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount0 = 1e18;

        engine.execute(trades, address(this), bytes(""));

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 2e18, liquidity: 2e18, volume: 0, fee: 0})
        });
        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        amount0 = 0;

        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 2e18);

        exchangeID = bytes32(0);

        vm.resumeGasMetering();
    }

    function test_AddLiquidity_Drift() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: 0,
                    drift: int256(Q128 / 100)
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: int256(Q128 / 100)
            }),
            stateBefore: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: uint256(1e18 * 100) / 101 + 1, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount1 = uint256(1e18 * 100) / 101 + 1;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        amount1 = 0;

        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 1e18);

        exchangeID = bytes32(0);

        vm.resumeGasMetering();
    }

    function test_AddLiquidity_Spread() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: Q128 / 100,
                    drift: 0
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: 1e18 + 2e16, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount1 = 1e18 + 2e16;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        amount1 = 0;

        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 1e18);

        exchangeID = bytes32(0);

        vm.resumeGasMetering();
    }

    function test_RemoveLiquidity() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: 0,
                    drift: 0
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount0 = 1e18;

        engine.execute(trades, address(this), bytes(""));

        amount0 = 0;

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0})
        });

        liquidity = 1e18;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        liquidity = 0;

        assertEq(mockERC20_0.balanceOf(address(this)), 1e18 + 1);
        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 0);

        exchangeID = bytes32(0);

        vm.resumeGasMetering();
    }

    function test_RemoveLiquidity_Drift() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: 0,
                    drift: int256(Q128 / 100)
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: int256(Q128 / 100)
            }),
            stateBefore: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: uint256(1e18 * 100) / 101 + 1, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount1 = uint256(1e18 * 100) / 101 + 1;

        vm.roll(2);

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        amount1 = 0;

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: int256(Q128 / 100)
            }),
            stateBefore: ExchangeState({token: 1, amount: uint256(1e18 * 100) / 101 + 1, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0})
        });

        liquidity = 1e18;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        liquidity = 0;

        exchangeID = bytes32(0);

        assertEq(mockERC20_1.balanceOf(address(this)), uint256(1e18 * 100) / 101 + 2);
        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 0);

        vm.resumeGasMetering();
    }

    function test_RemoveLiquidity_Spread() external {
        vm.pauseGasMetering();

        exchangeID = keccak256(
            abi.encode(
                Position.ILRTADataID({
                    token0: address(mockERC20_0),
                    token1: address(mockERC20_1),
                    ratio: Q128,
                    spread: Q128 / 100,
                    drift: 0
                })
            )
        );

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: 1e18 + 2e16, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount1 = 1e18 + 2e16;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        amount1 = 0;

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 1, amount: 1e18 + 2e16, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0})
        });

        liquidity = 1e18;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        vm.pauseGasMetering();

        liquidity = 0;

        exchangeID = bytes32(0);

        assertEq(mockERC20_1.balanceOf(address(this)), 1e18 + 2e16 + 1);
        assertEq(engine.dataOf_XXXXXX(address(this), exchangeID).balance, 0);

        vm.resumeGasMetering();
    }

    function test_Swap() external {
        vm.pauseGasMetering();

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount0 = 1e18;

        engine.execute(trades, address(this), bytes(""));

        amount0 = 0;

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: 0,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, volume: 1e18, fee: 0})
        });

        amount1 = 1e18;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        amount1 = 0;

        vm.pauseGasMetering();

        assertEq(mockERC20_0.balanceOf(address(this)), 1e18 + 1);

        vm.resumeGasMetering();
    }

    function test_Swap_FeeZeroToOne() external {
        vm.pauseGasMetering();

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount0 = 1e18;

        engine.execute(trades, address(this), bytes(""));

        amount0 = 0;

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({
                token: 1,
                amount: uint256(101e16 * 100) / 99 + 1,
                liquidity: 1e18,
                volume: 1e18,
                fee: 1e16
            })
        });

        amount1 = uint256(101e16 * 100) / 99 + 1;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        amount1 = 0;

        vm.pauseGasMetering();

        assertEq(mockERC20_0.balanceOf(address(this)), 1e18 + 1);

        vm.resumeGasMetering();
    }

    function test_Swap_FeeOneToZero() external {
        vm.pauseGasMetering();

        Engine.Trade[] memory trades = new Engine.Trade[](1);
        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 1, amount: 1e18 + 2e16, liquidity: 1e18, volume: 0, fee: 0})
        });

        amount1 = 1e18 + 2e16;

        engine.execute(trades, address(this), bytes(""));

        amount1 = 0;

        trades[0] = Engine.Trade({
            exchange: Exchange({
                token0: address(mockERC20_0),
                token1: address(mockERC20_1),
                ratio: Q128,
                spread: Q128 / 100,
                drift: 0
            }),
            stateBefore: ExchangeState({token: 1, amount: 1e18 + 2e16, liquidity: 1e18, volume: 0, fee: 0}),
            stateAfter: ExchangeState({token: 0, amount: 101e16, liquidity: 1e18, volume: 1e18, fee: 1e16})
        });

        amount0 = 101e16;

        vm.resumeGasMetering();

        engine.execute(trades, address(this), bytes(""));

        amount0 = 0;

        vm.pauseGasMetering();

        assertEq(mockERC20_1.balanceOf(address(this)), 1e18 + 2e16 + 1);

        vm.resumeGasMetering();
    }
}
