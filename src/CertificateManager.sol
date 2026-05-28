// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CertificateManager
 * @author Built with concepts from Cyfrin Updraft (Foundry Fundamentals + Full-Stack Web3)
 * @notice A blockchain-based certificate issuance and verification system with IPFS metadata
 * @dev Follows Cyfrin Updraft conventions:
 *      - Custom errors: ContractName__ErrorName
 *      - Variable prefixes: i_ (immutable), s_ (storage)
 *      - CEI pattern (Checks-Effects-Interactions)
 *      - NatSpec on all public/external functions
 *
 * @dev Gas optimisation — only data the contract logic needs is stored on-chain:
 *      recipient, issuer, ipfsHash, issueDate, status.
 *      recipientName and courseName live in the IPFS metadata JSON pointed to by ipfsHash.
 *      certificateId is the mapping key — storing it inside the struct was redundant.
 */
contract CertificateManager {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CertificateManager__NotOwner();
    error CertificateManager__NotAuthorizedIssuer();
    error CertificateManager__CertificateAlreadyExists(bytes32 certificateId);
    error CertificateManager__CertificateNotFound(bytes32 certificateId);
    error CertificateManager__CertificateAlreadyRevoked(bytes32 certificateId);
    error CertificateManager__InvalidRecipient();
    error CertificateManager__EmptyIpfsHash();
    error CertificateManager__IssuerAlreadyAuthorized(address issuer);
    error CertificateManager__IssuerNotAuthorized(address issuer);

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    enum CertificateStatus {
        VALID,
        REVOKED
    }

    /**
     * @dev Optimised struct — only fields the contract logic reads are stored here.
     *      recipientName and courseName are in the IPFS JSON (ipfsHash points there).
     *      certificateId is omitted — it is already the mapping key.
     */
    struct Certificate {
        address recipient;
        address issuer;
        string ipfsHash;
        uint256 issueDate;
        CertificateStatus status;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address private immutable i_owner;
    uint256 private s_certificateCount;
    mapping(bytes32 => Certificate) private s_certificates;
    mapping(address => bool) private s_authorizedIssuers;
    mapping(address => bytes32[]) private s_recipientCertificates;
    bytes32[] private s_allCertificateIds;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CertificateIssued(
        bytes32 indexed certificateId,
        address indexed recipient,
        address indexed issuer,
        string ipfsHash,
        uint256 issueDate
    );

    event CertificateRevoked(
        bytes32 indexed certificateId, address indexed revokedBy, uint256 revokeDate
    );

    event IssuerAuthorized(address indexed issuer, address indexed authorizedBy);
    event IssuerRevoked(address indexed issuer, address indexed revokedBy);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert CertificateManager__NotOwner();
        }
        _;
    }

    modifier onlyAuthorizedIssuer() {
        if (!s_authorizedIssuers[msg.sender] && msg.sender != i_owner) {
            revert CertificateManager__NotAuthorizedIssuer();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        i_owner = msg.sender;
        s_authorizedIssuers[msg.sender] = true;
        emit IssuerAuthorized(msg.sender, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize a new address to issue certificates
    function authorizeIssuer(address _issuer) external onlyOwner {
        if (_issuer == address(0)) {
            revert CertificateManager__InvalidRecipient();
        }
        if (s_authorizedIssuers[_issuer]) {
            revert CertificateManager__IssuerAlreadyAuthorized(_issuer);
        }
        s_authorizedIssuers[_issuer] = true;
        emit IssuerAuthorized(_issuer, msg.sender);
    }

    /// @notice Remove issuer authorization
    function revokeIssuer(address _issuer) external onlyOwner {
        if (!s_authorizedIssuers[_issuer]) {
            revert CertificateManager__IssuerNotAuthorized(_issuer);
        }
        s_authorizedIssuers[_issuer] = false;
        emit IssuerRevoked(_issuer, msg.sender);
    }

    /**
     * @notice Issue a new certificate on-chain with IPFS metadata
     * @dev Follows CEI: Checks first, then Effects, no external Interactions.
     *      recipientName and courseName are stored in the IPFS JSON — not on-chain.
     *      This saves ~50,000–100,000 gas per issuance compared to storing strings on-chain.
     * @param _recipient  Wallet address of the certificate recipient
     * @param _ipfsHash   IPFS CID of the metadata JSON (contains name, course, image, etc.)
     */
    function issueCertificate(
        address _recipient,
        string calldata _ipfsHash
    ) external onlyAuthorizedIssuer returns (bytes32 certificateId) {
        // Checks
        if (_recipient == address(0)) revert CertificateManager__InvalidRecipient();
        if (bytes(_ipfsHash).length == 0) revert CertificateManager__EmptyIpfsHash();

        certificateId = keccak256(
            abi.encodePacked(_recipient, msg.sender, block.timestamp, s_certificateCount)
        );

        if (s_certificates[certificateId].issueDate != 0) {
            revert CertificateManager__CertificateAlreadyExists(certificateId);
        }

        // Effects
        s_certificates[certificateId] = Certificate({
            recipient: _recipient,
            issuer: msg.sender,
            ipfsHash: _ipfsHash,
            issueDate: block.timestamp,
            status: CertificateStatus.VALID
        });

        s_recipientCertificates[_recipient].push(certificateId);
        s_allCertificateIds.push(certificateId);
        s_certificateCount++;

        emit CertificateIssued(
            certificateId, _recipient, msg.sender, _ipfsHash, block.timestamp
        );
    }

    /// @notice Revoke an existing certificate (authorized issuer only)
    function revokeCertificate(bytes32 _certificateId) external onlyAuthorizedIssuer {
        Certificate storage cert = s_certificates[_certificateId];
        if (cert.issueDate == 0) revert CertificateManager__CertificateNotFound(_certificateId);
        if (cert.status == CertificateStatus.REVOKED) {
            revert CertificateManager__CertificateAlreadyRevoked(_certificateId);
        }

        cert.status = CertificateStatus.REVOKED;
        emit CertificateRevoked(_certificateId, msg.sender, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify a certificate — returns on-chain record
    /// @dev recipientName and courseName are in the IPFS JSON at cert.ipfsHash
    function verifyCertificate(bytes32 _certificateId)
        external
        view
        returns (Certificate memory)
    {
        Certificate memory cert = s_certificates[_certificateId];
        if (cert.issueDate == 0) revert CertificateManager__CertificateNotFound(_certificateId);
        return cert;
    }

    /// @notice Returns true if certificate exists and is not revoked
    function isCertificateValid(bytes32 _certificateId) external view returns (bool) {
        Certificate memory cert = s_certificates[_certificateId];
        return (cert.issueDate != 0 && cert.status == CertificateStatus.VALID);
    }

    function getCertificatesByRecipient(address _recipient)
        external
        view
        returns (bytes32[] memory)
    {
        return s_recipientCertificates[_recipient];
    }

    function getAllCertificateIds() external view returns (bytes32[] memory) {
        return s_allCertificateIds;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getCertificateCount() external view returns (uint256) {
        return s_certificateCount;
    }

    function isAuthorizedIssuer(address _issuer) external view returns (bool) {
        return s_authorizedIssuers[_issuer];
    }
}
