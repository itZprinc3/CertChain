// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CertificateManager} from "../../src/CertificateManager.sol";
import {DeployCertificateManager} from "../../script/DeployCertificateManager.s.sol";
import {IssueCertificate, AuthorizeIssuer} from "../../script/Interactions.s.sol";

/**
 * @title InteractionsTest
 * @notice Integration tests — same pattern as InteractionsTest.t.sol from Cyfrin Updraft
 * @dev These tests use the SCRIPTS (not direct contract calls) to test
 *      the full deployment → interaction flow end-to-end.
 *
 * @dev Updated for optimised struct:
 *      issueCertificate now takes (recipient, ipfsHash) only.
 *      recipientName and courseName live in the IPFS JSON — not on-chain.
 */
contract InteractionsTest is Test {
    CertificateManager public certificateManager;
    address public OWNER;

    function setUp() external {
        DeployCertificateManager deployer = new DeployCertificateManager();
        (certificateManager,) = deployer.run();
        OWNER = certificateManager.getOwner();
    }

    /**
     * @notice Test the full flow: deploy → issue via script → verify
     * @dev This mirrors how InteractionsTest works in foundry-fund-me-f23:
     *      deploy the contract, then call the interaction script against it
     */
    function test_UserCanIssueCertificateViaScript() public {
        IssueCertificate issueScript = new IssueCertificate();
        issueScript.issueCertificateUsingConfig(address(certificateManager));

        assertEq(certificateManager.getCertificateCount(), 1);

        bytes32[] memory allIds = certificateManager.getAllCertificateIds();
        assertEq(allIds.length, 1);

        CertificateManager.Certificate memory cert =
            certificateManager.verifyCertificate(allIds[0]);

        // courseName and recipientName are now in IPFS — verify the on-chain fields instead
        assertEq(cert.ipfsHash, "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX");
        assertTrue(cert.status == CertificateManager.CertificateStatus.VALID);
    }

    function test_FullFlowIssueAndRevoke() public {
        // Issue — only recipient and ipfsHash now
        vm.prank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(
            makeAddr("bob"),
            "QmExampleHash123"
        );

        // Verify it's valid
        assertTrue(certificateManager.isCertificateValid(certId));

        // Revoke
        vm.prank(OWNER);
        certificateManager.revokeCertificate(certId);

        // Verify it's revoked
        assertFalse(certificateManager.isCertificateValid(certId));
        CertificateManager.Certificate memory cert = certificateManager.verifyCertificate(certId);
        assertTrue(cert.status == CertificateManager.CertificateStatus.REVOKED);
    }

    function test_FullFlowMultipleIssuersMultipleCerts() public {
        address issuer2    = makeAddr("issuer2");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");

        // Owner authorizes a second issuer
        vm.prank(OWNER);
        certificateManager.authorizeIssuer(issuer2);

        // Owner issues a cert
        vm.prank(OWNER);
        certificateManager.issueCertificate(recipient1, "QmHashA");

        // Second issuer issues a cert
        vm.prank(issuer2);
        certificateManager.issueCertificate(recipient2, "QmHashB");

        // Both should exist
        assertEq(certificateManager.getCertificateCount(), 2);

        bytes32[] memory aliceCerts = certificateManager.getCertificatesByRecipient(recipient1);
        bytes32[] memory bobCerts   = certificateManager.getCertificatesByRecipient(recipient2);
        assertEq(aliceCerts.length, 1);
        assertEq(bobCerts.length, 1);
    }
}
