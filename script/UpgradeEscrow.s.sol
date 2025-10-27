// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { EscrowRegistry } from "../src/EscrowRegistry.sol";

error InvalidProxyAddress();

contract UpgradeEscrow is Script {
    function run() external returns (address impl, address proxy) {
        uint256 ownerKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        proxy = vm.envAddress("ESCROW_PROXY");
        
        if (proxy == address(0)) revert InvalidProxyAddress();
        address ownerSigner = vm.rememberKey(ownerKey);
        
        vm.startBroadcast(ownerSigner);
        EscrowRegistry implementation = new EscrowRegistry();
        impl = address(implementation);
        
        EscrowRegistry(proxy).upgradeToAndCall{value: 0}(impl, new bytes(0));
        vm.stopBroadcast();
        
        console.log("EscrowRegistry proxy upgraded to implementation:", impl);
        console.log("Proxy address:", proxy);
    }
}

