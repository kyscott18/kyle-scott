// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Handles 512-bit math operations

struct uint512 {
    uint256 msb;
    uint256 lsb;
}

uint256 constant Q128 = 2 ** 128;

/// @notice 512-bit multiplication
function mul(uint256 a, uint256 b) pure returns (uint512 memory) {
    unchecked {
        uint256 msb;
        uint256 lsb;

        assembly {
            lsb := mul(a, b)
            let mm := mulmod(a, b, not(0))
            msb := sub(sub(mm, lsb), lt(mm, lsb))
        }

        return uint512({msb: msb, lsb: lsb});
    }
}

/// @notice 512-bit division
/// @dev Reverts if the quotient is larger than type(uint256).max
function div(uint512 memory a, uint256 b) pure returns (uint256) {}

/// @notice 512-bit division, rounding up
/// @dev Reverts if the quotient is larger than type(uint256).max
function divRoundUp(uint512 memory a, uint256 b) pure returns (uint256) {}
