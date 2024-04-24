// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

uint256 constant Q128 = 2 ** 128;

/// @notice Returns true if a * b >= c * d
/// @dev Prevents against intermediate values overflowing 256 bits
/// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
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

        return (r1 == s1 && r0 >= s0);
    }
}
