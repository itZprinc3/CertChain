// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

/**
 * @title HelperConfig
 * @notice Manage network-specific configuration for deployments
 * @dev Same pattern as Cyfrin Updraft foundry-fund-me-f23:
 *      1. Deploy to a local Anvil chain → use Anvil default key
 *      2. Deploy to Sepolia → use real key from .env
 *
 *      If we are on Anvil, we use the default key.
 *      If we are on Sepolia, we pull from environment.
 */
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        uint256 deployerKey;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    NetworkConfig public activeNetworkConfig;

    // Anvil default account #0 private key (public, pre-funded with 10000 ETH)
    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    /*//////////////////////////////////////////////////////////////
                           CONFIG FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Config for Sepolia testnet
     * @dev Uses 0 so vm.startBroadcast() falls back to --account / --sender from CLI.
     */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({deployerKey: 0});
    }

    /**
     * @notice Config for local Anvil chain
     * @dev Uses the well-known Anvil default key — no .env needed
     */
    function getOrCreateAnvilEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({deployerKey: DEFAULT_ANVIL_KEY});
    }
}
