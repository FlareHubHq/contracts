// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEscrowRegistry} from "../interfaces/IEscrowRegistry.sol";
import {TransferFailed} from "../errors/EscrowErrors.sol";

abstract contract EscrowStorage {
    using SafeERC20 for IERC20;

    struct BountyEscrow {
        address sponsor;
        address token;
        uint256 totalAmount;
        uint256 balance;
        bytes32 root;
        uint64 clawbackAt;
        bool paused;
    }

    struct Milestone { uint256 amount; uint256 funded; uint256 claimed; bool refunded; }

    struct ContractMeta {
        address sponsor;
        address token;
        uint64 clawbackAt;
        uint256 milestones;
        bool paused;
    }

    // EIP-712 Typehashes
    bytes32 internal constant TYPEHASH_MILESTONE_APPROVAL = keccak256("MilestoneApproval(uint256 escrowId,uint256 milestoneIndex,address talent,address token,uint256 amount,uint256 nonce,uint64 expiration)");
    bytes32 internal constant TYPEHASH_MILESTONE_CANCELLATION = keccak256("MilestoneCancellation(uint256 escrowId,uint256 milestoneIndex,uint256 nonce,uint64 expiration)");
    bytes32 internal constant TYPEHASH_DIRECT_RELEASE = keccak256("DirectReleaseAuthorization(uint256 escrowId,address talent,address token,uint256 amount,uint256 nonce,uint64 expiration)");

    // State
    uint256 internal _nextEscrowId;
    mapping(uint256 => IEscrowRegistry.EscrowKind) public escrowKind;

    mapping(uint256 => BountyEscrow) public bounties;
    mapping(uint256 => mapping(bytes32 => bool)) public bountyLeafClaimed;

    mapping(uint256 => ContractMeta) public contractsMeta;
    mapping(uint256 => mapping(uint256 => Milestone)) public milestones; // escrowId => index => Milestone
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) public nonceUsed; // escrowId => index => nonce => used

    mapping(address => bool) public tokenAllowed;

    address public operator;

    function _payout(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool ok, ) = to.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
