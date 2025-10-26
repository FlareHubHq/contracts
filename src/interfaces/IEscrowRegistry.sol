// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrowRegistry {
    enum EscrowKind {
        Bounty,
        ContractEscrow
    }

    struct MilestoneApproval {
        uint256 escrowId;
        uint256 milestoneIndex;
        address talent;
        address token;
        uint256 amount;
        uint256 nonce;
        uint64 expiration;
    }

    event EscrowCreated(
        uint256 indexed escrowId, EscrowKind kind, address indexed sponsor, address token, uint256 totalAmount
    );
    event EscrowFunded(uint256 indexed escrowId, address indexed funder, uint256 amount);
    event EscrowClaimed(uint256 indexed escrowId, address indexed claimant, uint256 amount);
    event EscrowRemainderRefunded(uint256 indexed escrowId, address indexed sponsor, uint256 amount);

    event EscrowMilestoneFunded(
        uint256 indexed escrowId, uint256 indexed milestoneIndex, address indexed funder, uint256 amount
    );
    event EscrowMilestoneApproved(
        uint256 indexed escrowId, uint256 indexed milestoneIndex, address approver, bytes32 approvalHash
    );
    event EscrowMilestoneClaimed(
        uint256 indexed escrowId, uint256 indexed milestoneIndex, address indexed claimant, uint256 amount
    );
    event EscrowMilestoneRefunded(
        uint256 indexed escrowId, uint256 indexed milestoneIndex, address indexed sponsor, uint256 amount
    );

    event EscrowPaused(uint256 indexed escrowId);
    event EscrowUnpaused(uint256 indexed escrowId);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);

    function nextEscrowId() external view returns (uint256);

    function setOperator(address newOperator) external;
    function setTokenAllowed(address token, bool allowed) external;

    function createBountyEscrow(address token, uint256 totalAmount, uint64 clawbackAt) external returns (uint256 id);
    function fundBounty(uint256 escrowId, uint256 amount) external payable;
    function claimBounty(
        uint256 escrowId,
        uint256 amount,
        uint256 nonce,
        uint64 expiration,
        bytes calldata signature
    ) external;
    function refundRemainder(uint256 escrowId) external;

    function createContractEscrow(address token, uint64 clawbackAt, uint256[] memory amounts)
        external
        returns (uint256 id);
    function fundMilestone(uint256 escrowId, uint256 index, uint256 amount) external payable;
    function releaseMilestoneWithSig(
        MilestoneApproval calldata a,
        bytes calldata sigSponsor,
        bytes calldata sigOperator
    ) external;
    function directRelease(
        uint256 escrowId,
        uint256 index,
        address talent,
        uint256 amount,
        uint256 nonce,
        uint64 expiration
    ) external;
    function refundMilestone(uint256 escrowId, uint256 index) external;
}
