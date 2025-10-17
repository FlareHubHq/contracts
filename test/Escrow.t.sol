// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {EscrowRegistry} from "../src/EscrowRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract EscrowTest is Test {
    EscrowRegistry public registry;
    address sponsor = address(0xA11CE);
    address talent = address(0xB0B);

    function setUp() public {
        EscrowRegistry impl = new EscrowRegistry();
        bytes memory initData = abi.encodeWithSelector(EscrowRegistry.initialize.selector, address(0));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        registry = EscrowRegistry(payable(address(proxy)));

        vm.deal(sponsor, 100 ether);
        vm.deal(talent, 1 ether);
    }

    function test_Bounty_CreateFundSetRootClaimAndRefund() public {
        vm.prank(sponsor);
        uint256 id = registry.createBountyEscrow(address(0), 1 ether, 0); // allow immediate clawback

        // fund 1 ether
        vm.prank(sponsor);
        registry.fundBounty{value: 1 ether}(id, 1 ether);

        // single-leaf merkle: leaf = keccak256(abi.encodePacked(offchainHash, claimant, amount)), proof = []
        bytes32 offchain = keccak256("my-offchain-escrow-id");
        bytes32 leaf = keccak256(abi.encodePacked(offchain, talent, uint256(0.5 ether)));

        // set root (owner can set)
        registry.setDistributionRoot(id, leaf, "v1");

        // claim half
        vm.prank(talent);
        registry.claimBounty(id, 0.5 ether, offchain, new bytes32[](0));

        // refund remainder
        vm.prank(sponsor);
        registry.refundRemainder(id);
    }

    function test_Milestone_CreateFundDirectRelease() public {
        vm.prank(sponsor);
        uint256 id = registry.createContractEscrow(address(0), 0, _arr1(1 ether));

        // fund first milestone 1 ether
        vm.prank(sponsor);
        registry.fundMilestone{value: 1 ether}(id, 0, 1 ether);

        // direct release 0.4 ether
        vm.prank(sponsor);
        registry.directRelease(id, 0, talent, 0.4 ether, 1, uint64(block.timestamp + 1 days));
    }

    function _arr1(uint256 a) internal pure returns (uint256[] memory xs) {
        xs = new uint256[](1);
        xs[0] = a;
    }
}
