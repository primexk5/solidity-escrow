// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Escrow.sol";

contract DeployEscrow is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address platform = vm.envAddress("PLATFORM_ADDRESS");
        uint256 platformFee = vm.envUint("PLATFORM_FEE");

        vm.startBroadcast(deployerPrivateKey);

        new Escrow(platform, platformFee);

        vm.stopBroadcast();
    }
}
