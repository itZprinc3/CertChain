// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {CertificateManager} from "../src/CertificateManager.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @title Interactions
 * @notice Scripts to interact with a deployed CertificateManager
 * @dev Same pattern as Interactions.s.sol (FundFundMe / WithdrawFundMe) from Cyfrin Updraft
 *      Uses foundry-devops to automatically find the most recently deployed contract address
 *
 *      Usage:
 *        forge script script/Interactions.s.sol:IssueCertificate --rpc-url $RPC_URL --broadcast
 *        forge script script/Interactions.s.sol:VerifyCertificate --rpc-url $RPC_URL
 *        forge script script/Interactions.s.sol:RevokeCertificate --rpc-url $RPC_URL --broadcast
 *        forge script script/Interactions.s.sol:AuthorizeIssuer --rpc-url $RPC_URL --broadcast
 */

// ============================================================
// IssueCertificate — like FundFundMe
// ============================================================
contract IssueCertificate is Script {
    // recipientName and courseName now live in the IPFS JSON — not passed to the contract
    address constant RECIPIENT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account #1
    string constant IPFS_HASH = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX";

    function issueCertificateUsingConfig(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        bytes32 certId = CertificateManager(mostRecentlyDeployed).issueCertificate(
            RECIPIENT, IPFS_HASH
        );
        vm.stopBroadcast();

        console.log("Certificate issued!");
        console.log("Certificate ID:");
        console.logBytes32(certId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CertificateManager", block.chainid
        );
        issueCertificateUsingConfig(mostRecentlyDeployed);
    }
}

// ============================================================
// VerifyCertificate — read-only, like a view call
// ============================================================
contract VerifyCertificate is Script {
    // Paste a certificate ID here to verify it
    bytes32 constant CERT_ID_TO_VERIFY = bytes32(0);

    function verifyCertificateUsingConfig(address mostRecentlyDeployed) public view {
        CertificateManager cm = CertificateManager(mostRecentlyDeployed);
        CertificateManager.Certificate memory cert = cm.verifyCertificate(CERT_ID_TO_VERIFY);

        console.log("-------- Certificate Verified --------");
        console.log("Recipient:", cert.recipient);
        console.log("Issuer:", cert.issuer);
        console.log("IPFS Hash:", cert.ipfsHash);
        console.log("Issue Date:", cert.issueDate);
        console.log("Status (0=VALID, 1=REVOKED):", uint256(cert.status));
        console.log("(Name and course are in the IPFS metadata JSON)");
        console.log("--------------------------------------");
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CertificateManager", block.chainid
        );
        verifyCertificateUsingConfig(mostRecentlyDeployed);
    }
}

// ============================================================
// RevokeCertificate — like WithdrawFundMe
// ============================================================
contract RevokeCertificate is Script {
    // Paste the certificate ID to revoke here
    bytes32 constant CERT_ID_TO_REVOKE = bytes32(0);

    function revokeCertificateUsingConfig(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CertificateManager(mostRecentlyDeployed).revokeCertificate(CERT_ID_TO_REVOKE);
        vm.stopBroadcast();

        console.log("Certificate revoked!");
        console.logBytes32(CERT_ID_TO_REVOKE);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CertificateManager", block.chainid
        );
        revokeCertificateUsingConfig(mostRecentlyDeployed);
    }
}

// ============================================================
// AuthorizeIssuer — owner-only interaction
// ============================================================
contract AuthorizeIssuer is Script {
    // Address to authorize as an issuer
    address constant NEW_ISSUER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account #1

    function authorizeIssuerUsingConfig(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CertificateManager(mostRecentlyDeployed).authorizeIssuer(NEW_ISSUER);
        vm.stopBroadcast();

        console.log("Issuer authorized:", NEW_ISSUER);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CertificateManager", block.chainid
        );
        authorizeIssuerUsingConfig(mostRecentlyDeployed);
    }
}
