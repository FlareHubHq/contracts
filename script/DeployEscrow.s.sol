// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EscrowRegistryUpgradeable} from "../src/EscrowRegistryUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEscrow is Script {
    function run() external returns (address impl, address proxy) {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address operator = vm.envOr("ESCROW_OPERATOR", address(0));

        vm.startBroadcast(deployer);
        EscrowRegistryUpgradeable implementation = new EscrowRegistryUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EscrowRegistryUpgradeable.initialize.selector, operator);
        ERC1967Proxy p = new ERC1967Proxy(address(implementation), initData);
        vm.stopBroadcast();

        impl = address(implementation);
        proxy = address(p);

        console.log("EscrowRegistryUpgradeable impl:", impl);
        console.log("EscrowRegistry proxy:", proxy);
    }
}
