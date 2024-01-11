// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

function mul(uint256 a, uint256 b) pure returns (uint256 prod1, uint256 prod0) {
    unchecked {
        assembly {
            prod0 := mul(a, b)
            let mm := mulmod(a, b, not(0))
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
    }
}
