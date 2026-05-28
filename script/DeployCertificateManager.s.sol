// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {CertificateManager} from "../src/CertificateManager.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployCertificateManager
 * @notice Deployment script — same pattern as DeployFundMe from Cyfrin Updraft
 * @dev Usage:
 *      Anvil:   forge script script/DeployCertificateManager.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 *      Sepolia: forge script script/DeployCertificateManager.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployCertificateManager is Script {
    function run() external returns (CertificateManager, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        uint256 deployerKey = helperConfig.activeNetworkConfig();

        if (deployerKey != 0) {
            vm.startBroadcast(deployerKey);
        } else {
            vm.startBroadcast();
        }
        CertificateManager certificateManager = new CertificateManager();
        vm.stopBroadcast();

        console.log("----------------------------------------------------");
        console.log("CertificateManager deployed at:", address(certificateManager));
        console.log("Owner:", certificateManager.getOwner());
        console.log("----------------------------------------------------");

        return (certificateManager, helperConfig);
    }
}
