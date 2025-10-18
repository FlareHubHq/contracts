// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { EscrowRegistry } from "../src/EscrowRegistry.sol";

contract UpgradeEscrow is Script {
    function run() external returns (address impl, address proxy) {
        uint256 ownerKey = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        proxy = vm.envAddress("ESCROW_PROXY");
        address providedImpl = vm.envOr("ESCROW_IMPLEMENTATION", address(0));
        address owner = vm.rememberKey(ownerKey);
        vm.startBroadcast(owner);
        if (providedImpl == address(0)) {
            EscrowRegistry implementation = new EscrowRegistry();
            impl = address(implementation);
        } else {
            impl = providedImpl;
        }
        EscrowRegistry(proxy).upgradeToAndCall{value: 0}(impl, new bytes(0));
        vm.stopBroadcast();
        console.log("EscrowRegistry proxy upgraded to implementation:", impl);
        console.log("Proxy address:", proxy);
    }
}
