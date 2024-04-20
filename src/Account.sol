// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

/// @notice
/// @param token
/// @param amount
struct ERC20Data {
    address token;
    uint256 amount;
}

/// @notice
/// @param id
/// @param amount
struct LPData {
    bytes32 id;
    uint256 amount;
}

struct Account {
    ERC20Data[] erc20DataIn;
    ERC20Data[] erc20DataOut;
    LPData[] lpData;
    uint256 lpCount;
}

/// @notice
/// @param length
function createAccount(uint256 length) pure returns (Account memory account) {
    unchecked {
        account.erc20DataIn = new ERC20Data[](length * 2);
        account.erc20DataOut = new ERC20Data[](length * 2);
        account.lpData = new LPData[](length);
    }
}

function updateERC20(Account memory account, address token, uint256 amount, bool positivity) pure {
    unchecked {
        for (uint256 i = 0; i < account.erc20DataIn.length; i++) {
            if (account.erc20DataIn[i].token == token) {
                if (positivity) {
                    account.erc20DataIn[i].amount += amount;
                } else {
                    account.erc20DataIn[i].amount -= amount;
                }
                return;
            } else if (account.erc20DataOut[i].token == token) {
                if (positivity) {
                    account.erc20DataOut[i].amount -= amount;
                } else {
                    account.erc20DataOut[i].amount += amount;
                }
                return;
            } else if (positivity && account.erc20DataIn[i].token == address(0)) {
                account.erc20DataIn[i].token = token;
                account.erc20DataIn[i].amount = amount;
                return;
            } else if (!positivity && account.erc20DataOut[i].token == address(0)) {
                account.erc20DataOut[i].token = token;
                account.erc20DataOut[i].amount = amount;
                return;
            }
        }

        revert();
    }
}

function updateLP(Account memory account, bytes32 id, uint256 amount) pure {
    unchecked {
        uint256 lpCount = account.lpCount;
        account.lpData[lpCount].id = id;
        account.lpData[lpCount].amount = amount;
        account.lpCount = lpCount + 1;
    }
}

function getBalances(Account memory account, address addr) view returns (uint256[] memory) {
    unchecked {
        uint256[] memory balances = new uint256[](account.erc20DataIn.length);

        for (uint256 i = 0; i < account.erc20DataIn.length; i++) {
            if (account.erc20DataIn[i].token == address(0)) break;
            balances[i] = ERC20(account.erc20DataIn[i].token).balanceOf(addr);
        }

        return balances;
    }
}

function transferTokens(Account memory account, address to) {
    unchecked {
        for (uint256 i = 0; i < account.erc20DataOut.length; i++) {
            if (account.erc20DataOut[i].token == address(0)) break;
            SafeTransferLib.safeTransfer(ERC20(account.erc20DataOut[i].token), to, account.erc20DataOut[i].amount);
        }
    }
}
