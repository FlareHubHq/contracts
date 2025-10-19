// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { EscrowRegistry } from "../src/EscrowRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

    function test_Bounty_CreateFundClaimWithSigAndRefund() public {
        uint256 signerKey = 0xA11CE;
        address signer = vm.addr(signerKey);
        address owner = registry.owner();
        vm.prank(owner);
        registry.setClaimsSigner(signer);
        vm.prank(sponsor);
        uint256 id = registry.createBountyEscrow(address(0), 1 ether, 0); // allow immediate clawback

        // fund 1 ether
        vm.prank(sponsor);
        registry.fundBounty{ value: 1 ether }(id, 1 ether);

        uint256 nonce = 1;
        uint64 expiration = uint64(block.timestamp + 1 days);
        bytes32 digest = registry.getBountyClaimDigest(id, talent, 0.5 ether, nonce, expiration);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(talent);
        registry.claimBounty(id, 0.5 ether, nonce, expiration, sig);

        // refund remainder
        vm.prank(sponsor);
        registry.refundRemainder(id);
    }

    function test_Milestone_CreateFundDirectRelease() public {
        vm.prank(sponsor);
        uint256 id = registry.createContractEscrow(address(0), 0, _arr1(1 ether));

        // fund first milestone 1 ether
        vm.prank(sponsor);
        registry.fundMilestone{ value: 1 ether }(id, 0, 1 ether);

        // direct release 0.4 ether
        vm.prank(sponsor);
        registry.directRelease(id, 0, talent, 0.4 ether, 1, uint64(block.timestamp + 1 days));
    }

    function _arr1(uint256 a) internal pure returns (uint256[] memory xs) {
        xs = new uint256[](1);
        xs[0] = a;
    }
}
