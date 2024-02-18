// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

uint256 constant Q128 = 2 ** 128;

/// @dev a * b >= c * d
function mulGte(uint256 a, uint256 b, uint256 c, uint256 d) pure returns (bool) {
    unchecked {
        uint256 r0 = a * b;
        uint256 s0 = c * d;
        uint256 r1;
        uint256 s1;
        assembly {
            let mm
            let n := not(0)

            mm := mulmod(a, b, n)
            r1 := sub(sub(mm, r0), lt(mm, r0))

            mm := mulmod(c, d, n)
            s1 := sub(sub(mm, s0), lt(mm, s0))
        }

        if (r1 > s1) return true;
        if (r1 == s1) return r0 >= s0;
        return false;
    }
}
