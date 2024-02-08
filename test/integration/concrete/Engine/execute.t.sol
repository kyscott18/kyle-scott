// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {ICallback, Engine, getPairID, StrikeData, TokenSelector} from "src/Engine.sol";
import {Q128} from "src/Math.sol";
import {Position} from "src/Position.sol";

contract ExecuteTest is Test, ICallback {
    Engine private engine;
    MockERC20 private mockERC20_0;
    MockERC20 private mockERC20_1;

    uint256 private amount0;
    uint256 private amount1;

    function setUp() external {
        engine = new Engine();
        mockERC20_0 = new MockERC20("Mock ERC20", "MOCK", 18);
        mockERC20_1 = new MockERC20("Mock ERC20", "MOCK", 18);
    }

    function callback(bytes calldata) external {
        if (amount0 > 0) mockERC20_0.mint(msg.sender, amount0);
        if (amount1 > 0) mockERC20_1.mint(msg.sender, amount1);
    }

    function test_AddLiquidity_Cold() external {
        vm.pauseGasMetering();

        Engine.Params[] memory params = new Engine.Params[](1);
        params[0] = Engine.Params({
            token0: address(mockERC20_0),
            token1: address(mockERC20_1),
            ratio: Q128,
            spread: 0,
            strikeBefore: StrikeData({token: TokenSelector.Token0, amount: 0, liquidity: 0, volume: 0}),
            strikeAfter: StrikeData({token: TokenSelector.Token0, amount: 1e18, liquidity: 1e18, volume: 0})
        });

        amount0 = 1e18;

        vm.resumeGasMetering();

        engine.execute(params, address(this), bytes(""));

        vm.pauseGasMetering();

        bytes32 positionID = keccak256(
            abi.encode(
                Position.ILRTADataID({pairID: getPairID(address(mockERC20_0), address(mockERC20_1)), strike: Q128})
            )
        );

        assertEq(engine.dataOf_XXXXXX(address(this), positionID).balance, 1e18);

        vm.resumeGasMetering();
    }

    function test_AddLiquidity_Hot() external {
        vm.pauseGasMetering();

        Engine.Params[] memory params = new Engine.Params[](1);
        params[0] = Engine.Params({
            token0: address(mockERC20_0),
            token1: address(mockERC20_1),
            ratio: Q128,
            spread: 0,
            strikeBefore: StrikeData({token: TokenSelector.Token0, amount: 0, liquidity: 0, volume: 0}),
            strikeAfter: StrikeData({token: TokenSelector.Token0, amount: 1e18, liquidity: 1e18, volume: 0})
        });

        amount0 = 1e18;

        engine.execute(params, address(this), bytes(""));

        params[0] = Engine.Params({
            token0: address(mockERC20_0),
            token1: address(mockERC20_1),
            ratio: Q128,
            spread: 0,
            strikeBefore: StrikeData({token: TokenSelector.Token0, amount: 1e18, liquidity: 1e18, volume: 0}),
            strikeAfter: StrikeData({token: TokenSelector.Token0, amount: 2e18, liquidity: 2e18, volume: 0})
        });

        vm.resumeGasMetering();

        engine.execute(params, address(this), bytes(""));

        vm.pauseGasMetering();

        bytes32 positionID = keccak256(
            abi.encode(
                Position.ILRTADataID({pairID: getPairID(address(mockERC20_0), address(mockERC20_1)), strike: Q128})
            )
        );

        assertEq(engine.dataOf_XXXXXX(address(this), positionID).balance, 2e18);

        vm.resumeGasMetering();
    }
}
