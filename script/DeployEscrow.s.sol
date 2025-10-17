// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { EscrowRegistry } from "../src/EscrowRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEscrow is Script {
    function run() external returns (address impl, address proxy) {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address operator = vm.envOr("ESCROW_OPERATOR", address(0));

        vm.startBroadcast(deployer);
        EscrowRegistry implementation = new EscrowRegistry();
        bytes memory initData = abi.encodeWithSelector(EscrowRegistry.initialize.selector, operator);
        ERC1967Proxy p = new ERC1967Proxy(address(implementation), initData);
        vm.stopBroadcast();

        impl = address(implementation);
        proxy = address(p);

        console.log("EscrowRegistry impl:", impl);
        console.log("EscrowRegistry proxy:", proxy);
    }
}
