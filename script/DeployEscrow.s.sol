// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { EscrowRegistry } from "../src/EscrowRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEscrow is Script {
    struct DeploymentInfo {
        uint256 chainId;
        address implementation;
        address proxy;
    }

    function run() external returns (address impl, address proxy) {
        address deployer = vm.rememberKey(uint256(vm.envBytes32("PRIVATE_KEY")));
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

        _persistDeployment(block.chainid, impl, proxy);
    }

    function _persistDeployment(uint256 chainId, address implementation, address proxy) internal {
        string memory path = string.concat(vm.projectRoot(), "/deployments/contracts.json");
        DeploymentInfo[] memory entries = _loadDeployments(path);
        bool updated;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].chainId == chainId) {
                entries[i] = DeploymentInfo({ chainId: chainId, implementation: implementation, proxy: proxy });
                updated = true;
                break;
            }
        }
        if (!updated) {
            DeploymentInfo[] memory extended = new DeploymentInfo[](entries.length + 1);
            for (uint256 j = 0; j < entries.length; j++) {
                extended[j] = entries[j];
            }
            extended[entries.length] = DeploymentInfo({ chainId: chainId, implementation: implementation, proxy: proxy });
            entries = extended;
        }
        string memory json = _encodeEntries(entries);
        vm.writeJson(json, path);
    }

    function _loadDeployments(string memory path) internal view returns (DeploymentInfo[] memory entries) {
        string memory raw;
        try vm.readFile(path) returns (string memory contents) {
            raw = contents;
        } catch {
            return new DeploymentInfo[](0);
        }
        if (bytes(raw).length == 0) {
            return new DeploymentInfo[](0);
        }
        bytes memory parsed;
        try vm.parseJson(raw) returns (bytes memory data) {
            parsed = data;
        } catch {
            return new DeploymentInfo[](0);
        }
        if (parsed.length == 0) {
            return new DeploymentInfo[](0);
        }
        entries = abi.decode(parsed, (DeploymentInfo[]));
    }

    function _encodeEntries(DeploymentInfo[] memory entries) internal view returns (string memory json) {
        json = "[";
        for (uint256 i = 0; i < entries.length; i++) {
            DeploymentInfo memory d = entries[i];
            json = string.concat(
                json,
                i == 0 ? "" : ",",
                "{\"chainId\": ",
                vm.toString(d.chainId),
                ", \"implementation\": \"",
                vm.toString(d.implementation),
                "\", \"proxy\": \"",
                vm.toString(d.proxy),
                "\"}"
            );
        }
        json = string.concat(json, "]");
    }
}
