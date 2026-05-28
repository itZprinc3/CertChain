// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CertificateManager} from "../../src/CertificateManager.sol";
import {DeployCertificateManager} from "../../script/DeployCertificateManager.s.sol";

/**
 * @title CertificateManagerTest
 * @notice Unit tests — same pattern as FundMeTest.t.sol from Cyfrin Updraft
 * @dev Key patterns used:
 *      - setUp() uses the deploy script (not `new CertificateManager()` directly)
 *      - makeAddr() for creating labeled test addresses
 *      - vm.prank() / vm.startPrank() for impersonation
 *      - vm.expectRevert() with custom error selectors
 *      - Arrange / Act / Assert structure
 *
 * @dev Updated for optimised struct:
 *      issueCertificate now takes (recipient, ipfsHash) only.
 *      recipientName and courseName live in the IPFS JSON.
 */
contract CertificateManagerTest is Test {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    CertificateManager public certificateManager;

    address public OWNER;
    address public ISSUER = makeAddr("issuer");
    address public RECIPIENT = makeAddr("recipient");
    address public RANDOM_USER = makeAddr("randomUser");

    // recipientName and courseName are now in the IPFS JSON — not passed to the contract
    string constant IPFS_HASH = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX";

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Helper modifier — authorize ISSUER before running the test
    modifier issuerAuthorized() {
        vm.prank(OWNER);
        certificateManager.authorizeIssuer(ISSUER);
        _;
    }

    /// @dev Helper modifier — issue a certificate before running the test
    modifier certificateIssued() {
        vm.prank(OWNER);
        certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        DeployCertificateManager deployer = new DeployCertificateManager();
        (certificateManager,) = deployer.run();
        OWNER = certificateManager.getOwner();
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerIsSetCorrectly() public view {
        assertNotEq(OWNER, address(0));
    }

    function test_OwnerIsAuthorizedIssuerByDefault() public view {
        assertTrue(certificateManager.isAuthorizedIssuer(OWNER));
    }

    function test_InitialCertificateCountIsZero() public view {
        assertEq(certificateManager.getCertificateCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                       AUTHORIZE ISSUER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanAuthorizeIssuer() public {
        vm.prank(OWNER);
        certificateManager.authorizeIssuer(ISSUER);
        assertTrue(certificateManager.isAuthorizedIssuer(ISSUER));
    }

    function test_RevertIf_NonOwnerAuthorizesIssuer() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(CertificateManager.CertificateManager__NotOwner.selector);
        certificateManager.authorizeIssuer(ISSUER);
    }

    function test_RevertIf_AuthorizeZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(CertificateManager.CertificateManager__InvalidRecipient.selector);
        certificateManager.authorizeIssuer(address(0));
    }

    function test_RevertIf_AuthorizeSameIssuerTwice() public issuerAuthorized {
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificateManager.CertificateManager__IssuerAlreadyAuthorized.selector, ISSUER
            )
        );
        certificateManager.authorizeIssuer(ISSUER);
    }

    /*//////////////////////////////////////////////////////////////
                        REVOKE ISSUER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanRevokeIssuer() public issuerAuthorized {
        vm.prank(OWNER);
        certificateManager.revokeIssuer(ISSUER);
        assertFalse(certificateManager.isAuthorizedIssuer(ISSUER));
    }

    function test_RevertIf_RevokeUnauthorizedIssuer() public {
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificateManager.CertificateManager__IssuerNotAuthorized.selector, RANDOM_USER
            )
        );
        certificateManager.revokeIssuer(RANDOM_USER);
    }

    /*//////////////////////////////////////////////////////////////
                      ISSUE CERTIFICATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanIssueCertificate() public {
        vm.prank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        assertTrue(certId != bytes32(0));
        assertEq(certificateManager.getCertificateCount(), 1);
    }

    function test_AuthorizedIssuerCanIssueCertificate() public issuerAuthorized {
        vm.prank(ISSUER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        assertTrue(certId != bytes32(0));
    }

    function test_RevertIf_UnauthorizedUserIssuesCertificate() public {
        vm.prank(RANDOM_USER);
        vm.expectRevert(CertificateManager.CertificateManager__NotAuthorizedIssuer.selector);
        certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
    }

    function test_RevertIf_IssueToZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(CertificateManager.CertificateManager__InvalidRecipient.selector);
        certificateManager.issueCertificate(address(0), IPFS_HASH);
    }

    function test_RevertIf_IssueWithEmptyIpfsHash() public {
        vm.prank(OWNER);
        vm.expectRevert(CertificateManager.CertificateManager__EmptyIpfsHash.selector);
        certificateManager.issueCertificate(RECIPIENT, "");
    }

    function test_IssuedCertificateStoresCorrectData() public {
        vm.prank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);

        CertificateManager.Certificate memory cert = certificateManager.verifyCertificate(certId);
        assertEq(cert.recipient, RECIPIENT);
        assertEq(cert.issuer, OWNER);
        assertEq(cert.ipfsHash, IPFS_HASH);
        assertTrue(cert.issueDate > 0);
        assertTrue(cert.status == CertificateManager.CertificateStatus.VALID);
    }

    function test_CertificateAppearsInRecipientList() public certificateIssued {
        bytes32[] memory certs = certificateManager.getCertificatesByRecipient(RECIPIENT);
        assertEq(certs.length, 1);
    }

    function test_CertificateAppearsInAllCertificateIds() public certificateIssued {
        bytes32[] memory allIds = certificateManager.getAllCertificateIds();
        assertEq(allIds.length, 1);
    }

    function test_CanIssueMultipleCertificatesToSameRecipient() public {
        vm.startPrank(OWNER);
        certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        vm.stopPrank();

        bytes32[] memory certs = certificateManager.getCertificatesByRecipient(RECIPIENT);
        assertEq(certs.length, 2);
        assertEq(certificateManager.getCertificateCount(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                     VERIFY CERTIFICATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CanVerifyValidCertificate() public {
        vm.prank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        assertTrue(certificateManager.isCertificateValid(certId));
    }

    function test_RevertIf_VerifyNonExistentCertificate() public {
        bytes32 fakeCertId = keccak256("doesNotExist");
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificateManager.CertificateManager__CertificateNotFound.selector, fakeCertId
            )
        );
        certificateManager.verifyCertificate(fakeCertId);
    }

    function test_IsCertificateValidReturnsFalseForNonExistent() public view {
        bytes32 fakeCertId = keccak256("doesNotExist");
        assertFalse(certificateManager.isCertificateValid(fakeCertId));
    }

    /*//////////////////////////////////////////////////////////////
                     REVOKE CERTIFICATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IssuerCanRevokeCertificate() public {
        vm.startPrank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        certificateManager.revokeCertificate(certId);
        vm.stopPrank();
        assertFalse(certificateManager.isCertificateValid(certId));
    }

    function test_RevokedCertificateShowsRevokedStatus() public {
        vm.startPrank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        certificateManager.revokeCertificate(certId);
        vm.stopPrank();

        CertificateManager.Certificate memory cert = certificateManager.verifyCertificate(certId);
        assertTrue(cert.status == CertificateManager.CertificateStatus.REVOKED);
    }

    function test_RevertIf_RevokeNonExistentCertificate() public {
        bytes32 fakeCertId = keccak256("doesNotExist");
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificateManager.CertificateManager__CertificateNotFound.selector, fakeCertId
            )
        );
        certificateManager.revokeCertificate(fakeCertId);
    }

    function test_RevertIf_RevokeAlreadyRevokedCertificate() public {
        vm.startPrank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);
        certificateManager.revokeCertificate(certId);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificateManager.CertificateManager__CertificateAlreadyRevoked.selector, certId
            )
        );
        certificateManager.revokeCertificate(certId);
        vm.stopPrank();
    }

    function test_RevertIf_UnauthorizedUserRevokesCertificate() public {
        vm.prank(OWNER);
        bytes32 certId = certificateManager.issueCertificate(RECIPIENT, IPFS_HASH);

        vm.prank(RANDOM_USER);
        vm.expectRevert(CertificateManager.CertificateManager__NotAuthorizedIssuer.selector);
        certificateManager.revokeCertificate(certId);
    }
}
