// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ILRTA} from "ilrta/src/ILRTA.sol";

abstract contract Position is ILRTA("kyle scott", "kjs") {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    struct ILRTADataID {
        address token0;
        address token1;
        uint256 strike;
    }

    struct ILRTAData {
        uint256 balance;
    }

    struct ILRTATransferDetails {
        bytes32 id;
        uint256 amount;
    }

    struct ILRTAApprovalDetails {
        bool approved;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    mapping(address owner => mapping(bytes32 id => ILRTAData data)) internal _dataOf;

    mapping(address owner => mapping(address spender => ILRTAApprovalDetails approvalDetails)) private _allowanceOf;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function dataOf_XXXXXX(address owner, bytes32 id) external view returns (ILRTAData memory) {
        return _dataOf[owner][id];
    }

    function allowanceOf_XXXXXX(address owner, address spender) external view returns (ILRTAApprovalDetails memory) {
        return _allowanceOf[owner][spender];
    }

    function validateRequest_sUsyFN(
        ILRTATransferDetails calldata signedTransferDetails,
        ILRTATransferDetails calldata requestedTransferDetails
    )
        external
        pure
        returns (bool)
    {
        if (
            requestedTransferDetails.amount > signedTransferDetails.amount
                || requestedTransferDetails.id != signedTransferDetails.id
        ) return false;
        return true;
    }

    function transfer_XXXXXX(address to, ILRTATransferDetails calldata transferDetails) external returns (bool) {
        return _transfer(msg.sender, to, transferDetails);
    }

    function approve_BKoIou(address spender, ILRTAApprovalDetails calldata approvalDetails) external returns (bool) {
        _allowanceOf[msg.sender][spender] = approvalDetails;

        emit Approval(msg.sender, spender, abi.encode(approvalDetails));

        return true;
    }

    function transferFrom_XXXXX(
        address from,
        address to,
        ILRTATransferDetails calldata transferDetails
    )
        external
        returns (bool)
    {
        ILRTAApprovalDetails memory allowed = _allowanceOf[from][msg.sender];

        if (!allowed.approved) revert();

        return _transfer(from, to, transferDetails);
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                             INTERNAL LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function _transfer(address from, address to, ILRTATransferDetails memory transferDetails) private returns (bool) {
        _dataOf[from][transferDetails.id].balance -= transferDetails.amount;
        _dataOf[to][transferDetails.id].balance += transferDetails.amount;

        emit Transfer(from, to, abi.encode(transferDetails));
        return true;
    }

    function _mint(address to, bytes32 id, uint256 amount) internal {
        _dataOf[to][id].balance += amount;

        emit Transfer(address(0), to, abi.encode(ILRTATransferDetails(id, amount)));
    }

    function _burn(address from, bytes32 id, uint256 amount) internal {
        _dataOf[from][id].balance -= amount;

        emit Transfer(from, address(0), abi.encode(ILRTATransferDetails(id, amount)));
    }
}
