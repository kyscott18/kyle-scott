// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {mulGte, Q128} from "src/Math.sol";

contract MulGteTest is Test {
    function test_mulGte_true() external {
        assertEq(mulGte(0, 0, 0, 0), true);
        assertEq(mulGte(1, 0, 0, 0), true);
        assertEq(mulGte(1, 0, 1, 0), true);
        assertEq(mulGte(Q128, Q128, Q128, Q128), true);
    }

    function test_mulGte_false() external {
        assertEq(mulGte(0, 0, 1, 1), false);
        assertEq(mulGte(1, 0, 1, 1), false);
        assertEq(mulGte(Q128, Q128 - 1, Q128, Q128), false);
    }
}
