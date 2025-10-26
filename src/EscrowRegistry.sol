// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IEscrowRegistry } from "./interfaces/IEscrowRegistry.sol";
import { EscrowStorage } from "./storage/EscrowStorage.sol";
import {
    NotAuthorized,
    TokenNotAllowed,
    InvalidKind,
    ContractPaused,
    InvalidValue,
    NoEthAllowed,
    InsufficientBalance,
    SponsorOnly,
    TimeNotReached,
    InvalidEscrow,
    IndexOutOfBounds,
    Refunded,
    AmountInvalid,
    Expired,
    NonceUsed,
    SponsorMismatch,
    OperatorMismatch,
    TokenMismatch,
    OperatorNotSet,
    InvalidSignature
} from "./errors/EscrowErrors.sol";
contract EscrowRegistry is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    IEscrowRegistry,
    EscrowStorage
{
    using SafeERC20 for IERC20;

    modifier onlyOperatorOrOwner() {
        if (!(msg.sender == operator || msg.sender == owner())) revert NotAuthorized(msg.sender);
        _;
    }

    function _getBounty(uint256 escrowId) internal view returns (BountyEscrow storage e) {
        if (escrowKind[escrowId] != IEscrowRegistry.EscrowKind.Bounty) revert InvalidKind();
        e = bounties[escrowId];
        if (e.sponsor == address(0)) revert InvalidEscrow();
    }

    function _getContract(uint256 escrowId) internal view returns (ContractMeta storage cm) {
        if (escrowKind[escrowId] != IEscrowRegistry.EscrowKind.ContractEscrow) revert InvalidKind();
        cm = contractsMeta[escrowId];
        if (cm.sponsor == address(0)) revert InvalidEscrow();
    }

    function _getMilestone(ContractMeta storage cm, uint256 escrowId, uint256 index)
        internal
        view
        returns (Milestone storage ms)
    {
        if (index >= cm.milestones) revert IndexOutOfBounds();
        ms = milestones[escrowId][index];
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address operator_) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __EIP712_init("FlareHubEscrow", "1");
        operator = operator_;
        _nextEscrowId = 1;
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }

    function setOperator(address newOperator) external onlyOwner {
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function nextEscrowId() external view override returns (uint256) {
        return _nextEscrowId;
    }

    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        tokenAllowed[token] = allowed;
    }

    function createBountyEscrow(address token, uint256 totalAmount, uint64 clawbackAt) external returns (uint256 id) {
        if (token != address(0) && !tokenAllowed[token]) revert TokenNotAllowed(token);
        id = _nextEscrowId++;
        escrowKind[id] = IEscrowRegistry.EscrowKind.Bounty;
        bounties[id] = BountyEscrow({
            sponsor: msg.sender,
            token: token,
            totalAmount: totalAmount,
            balance: 0,
            clawbackAt: clawbackAt,
            paused: false
        });
        emit EscrowCreated(id, IEscrowRegistry.EscrowKind.Bounty, msg.sender, token, totalAmount);
    }

    function fundBounty(uint256 escrowId, uint256 amount) external payable {
        BountyEscrow storage e = _getBounty(escrowId);
        if (e.paused) revert ContractPaused();
        if (e.token == address(0)) {
            if (msg.value != amount || amount == 0) revert InvalidValue(amount, msg.value);
        } else {
            if (msg.value != 0) revert NoEthAllowed();
            if (amount == 0) revert AmountInvalid();
            IERC20(e.token).safeTransferFrom(msg.sender, address(this), amount);
        }
        e.balance += amount;
        emit EscrowFunded(escrowId, msg.sender, amount);
    }

    function claimBounty(
        uint256 escrowId,
        uint256 amount,
        uint256 nonce,
        uint64 expiration,
        bytes calldata signature
    ) external {
        BountyEscrow storage e = _getBounty(escrowId);
        if (e.paused) revert ContractPaused();
        if (block.timestamp > expiration) revert Expired();
        if (amount == 0) revert AmountInvalid();
        if (e.balance < amount) revert InsufficientBalance();
        address signer = operator;
        if (signer == address(0)) revert OperatorNotSet();
        if (msg.sender == address(0)) revert NotAuthorized(address(0));
        bytes32 nonceKey = keccak256(abi.encodePacked(msg.sender, nonce));
        if (bountyClaimUsed[escrowId][nonceKey]) revert NonceUsed();
        bytes32 structHash = keccak256(
            abi.encode(TYPEHASH_BOUNTY_CLAIM, escrowId, msg.sender, amount, nonce, expiration)
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = ECDSA.recover(digest, signature);
        if (recovered != signer) revert InvalidSignature();
        bountyClaimUsed[escrowId][nonceKey] = true;
        e.balance -= amount;
        _payout(e.token, msg.sender, amount);
        emit EscrowClaimed(escrowId, msg.sender, amount);
    }

    function getBountyClaimDigest(
        uint256 escrowId,
        address claimant,
        uint256 amount,
        uint256 nonce,
        uint64 expiration
    ) external view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(TYPEHASH_BOUNTY_CLAIM, escrowId, claimant, amount, nonce, expiration));
        return _hashTypedDataV4(structHash);
    }

    function refundRemainder(uint256 escrowId) external {
        BountyEscrow storage e = _getBounty(escrowId);
        if (msg.sender != e.sponsor) revert SponsorOnly();
        if (block.timestamp < e.clawbackAt) revert TimeNotReached(e.clawbackAt);
        uint256 amt = e.balance;
        e.balance = 0;
        _payout(e.token, e.sponsor, amt);
        emit EscrowRemainderRefunded(escrowId, e.sponsor, amt);
    }

    function pauseEscrow(uint256 escrowId) external onlyOperatorOrOwner {
        if (escrowKind[escrowId] == IEscrowRegistry.EscrowKind.Bounty) {
            BountyEscrow storage e = _getBounty(escrowId);
            e.paused = true;
        } else if (escrowKind[escrowId] == IEscrowRegistry.EscrowKind.ContractEscrow) {
            ContractMeta storage cm = _getContract(escrowId);
            cm.paused = true;
        } else {
            revert InvalidEscrow();
        }
        emit EscrowPaused(escrowId);
    }

    function unpauseEscrow(uint256 escrowId) external onlyOperatorOrOwner {
        if (escrowKind[escrowId] == IEscrowRegistry.EscrowKind.Bounty) {
            BountyEscrow storage e = _getBounty(escrowId);
            e.paused = false;
        } else if (escrowKind[escrowId] == IEscrowRegistry.EscrowKind.ContractEscrow) {
            ContractMeta storage cm = _getContract(escrowId);
            cm.paused = false;
        } else {
            revert InvalidEscrow();
        }
        emit EscrowUnpaused(escrowId);
    }

    function createContractEscrow(address token, uint64 clawbackAt, uint256[] memory amounts)
        external
        returns (uint256 id)
    {
        if (token != address(0) && !tokenAllowed[token]) revert TokenNotAllowed(token);
        id = _nextEscrowId++;
        escrowKind[id] = IEscrowRegistry.EscrowKind.ContractEscrow;
        contractsMeta[id] = ContractMeta({
            sponsor: msg.sender,
            token: token,
            clawbackAt: clawbackAt,
            milestones: amounts.length,
            paused: false
        });
        for (uint256 i = 0; i < amounts.length; i++) {
            milestones[id][i] = Milestone({ amount: amounts[i], funded: 0, claimed: 0, refunded: false });
        }
        uint256 total;
        for (uint256 i2 = 0; i2 < amounts.length; i2++) {
            total += amounts[i2];
        }
        emit EscrowCreated(id, IEscrowRegistry.EscrowKind.ContractEscrow, msg.sender, token, total);
    }

    function fundMilestone(uint256 escrowId, uint256 index, uint256 amount) external payable {
        ContractMeta storage cm = _getContract(escrowId);
        if (msg.sender != cm.sponsor) revert SponsorOnly();
        if (cm.paused) revert ContractPaused();
        Milestone storage ms = _getMilestone(cm, escrowId, index);
        if (ms.refunded) revert Refunded();
        if (cm.token == address(0)) {
            if (msg.value != amount || amount == 0) revert InvalidValue(amount, msg.value);
        } else {
            if (msg.value != 0) revert NoEthAllowed();
            if (amount == 0) revert AmountInvalid();
            IERC20(cm.token).safeTransferFrom(msg.sender, address(this), amount);
        }
        ms.funded += amount;
        emit EscrowMilestoneFunded(escrowId, index, msg.sender, amount);
    }

    function releaseMilestoneWithSig(
        IEscrowRegistry.MilestoneApproval calldata a,
        bytes calldata sigSponsor,
        bytes calldata sigOperator
    ) external {
        ContractMeta storage cm = _getContract(a.escrowId);
        if (cm.paused) revert ContractPaused();
        Milestone storage ms = _getMilestone(cm, a.escrowId, a.milestoneIndex);
        if (a.token != cm.token) revert TokenMismatch();
        if (block.timestamp > a.expiration) revert Expired();
        if (nonceUsed[a.escrowId][a.milestoneIndex][a.nonce]) revert NonceUsed();
        uint256 available = ms.funded - ms.claimed;
        if (!(a.amount <= available && a.amount > 0)) revert AmountInvalid();
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH_MILESTONE_APPROVAL,
                a.escrowId,
                a.milestoneIndex,
                a.talent,
                a.token,
                a.amount,
                a.nonce,
                a.expiration
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address sp = ECDSA.recover(digest, sigSponsor);
        if (sp != cm.sponsor) revert SponsorMismatch();
        if (sigOperator.length > 0 && operator != address(0)) {
            address op = ECDSA.recover(digest, sigOperator);
            if (op != operator) revert OperatorMismatch();
        }
        nonceUsed[a.escrowId][a.milestoneIndex][a.nonce] = true;
        emit EscrowMilestoneApproved(a.escrowId, a.milestoneIndex, msg.sender, structHash);
        ms.claimed += a.amount;
        _payout(cm.token, a.talent, a.amount);
        emit EscrowMilestoneClaimed(a.escrowId, a.milestoneIndex, a.talent, a.amount);
    }

    function directRelease(
        uint256 escrowId,
        uint256 index,
        address talent,
        uint256 amount,
        uint256 nonce,
        uint64 expiration
    ) external {
        ContractMeta storage cm = _getContract(escrowId);
        if (msg.sender != cm.sponsor) revert SponsorOnly();
        if (cm.paused) revert ContractPaused();
        if (block.timestamp > expiration) revert Expired();
        if (nonceUsed[escrowId][index][nonce]) revert NonceUsed();
        Milestone storage ms = _getMilestone(cm, escrowId, index);
        uint256 available = ms.funded - ms.claimed;
        if (!(amount <= available && amount > 0)) revert AmountInvalid();
        bytes32 structHash =
            keccak256(abi.encode(TYPEHASH_DIRECT_RELEASE, escrowId, talent, cm.token, amount, nonce, expiration));
        nonceUsed[escrowId][index][nonce] = true;
        emit EscrowMilestoneApproved(escrowId, index, msg.sender, structHash);
        ms.claimed += amount;
        _payout(cm.token, talent, amount);
        emit EscrowMilestoneClaimed(escrowId, index, talent, amount);
    }

    function refundMilestone(uint256 escrowId, uint256 index) external {
        ContractMeta storage cm = _getContract(escrowId);
        if (msg.sender != cm.sponsor) revert SponsorOnly();
        if (block.timestamp < cm.clawbackAt) revert TimeNotReached(cm.clawbackAt);
        Milestone storage ms = _getMilestone(cm, escrowId, index);
        if (ms.refunded) revert Refunded();
        uint256 refundable = ms.funded - ms.claimed;
        ms.refunded = true;
        if (refundable > 0) {
            _payout(cm.token, cm.sponsor, refundable);
        }
        emit EscrowMilestoneRefunded(escrowId, index, cm.sponsor, refundable);
    }
}
