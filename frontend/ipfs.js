/* ============================================================
   ipfs.js — Pinata IPFS upload helpers
   Exposed as window.IPFS for use in non-module scripts.
   ============================================================ */

const PINATA_ENDPOINT = "https://api.pinata.cloud/pinning/pinJSONToIPFS";
const PINATA_JWT_KEY  = "pinata_jwt";

window.IPFS = {

  savePinataJwt(jwt) {
    if (!jwt) throw new Error("JWT is empty.");
    localStorage.setItem(PINATA_JWT_KEY, jwt);
  },

  getPinataJwt() {
    return localStorage.getItem(PINATA_JWT_KEY) || "";
  },

  isPinataConfigured() {
    return !!this.getPinataJwt();
  },

  buildCertificateMetadata({ recipientName, recipientAddress, courseName, description, issuerAddress }) {
    return {
      name: "CertChain Certificate — " + courseName,
      description: description || "Blockchain-verified certificate issued via CertChain.",
      recipientName,
      recipientAddress,
      courseName,
      issueDate: new Date().toISOString(),
      issuer: issuerAddress,
      platform: "CertChain"
    };
  },

  async uploadCertificateMetadata(metadata) {
    const jwt = this.getPinataJwt();
    if (!jwt) {
      throw new Error("Pinata JWT not configured. Set it in the Pinata API Key section.");
    }

    const res = await fetch(PINATA_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + jwt
      },
      body: JSON.stringify({
        pinataContent: metadata,
        pinataMetadata: { name: "CertChain-" + (metadata.courseName || "certificate") }
      })
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error("Pinata upload failed: " + (err.error || res.statusText));
    }

    const data = await res.json();
    return data.IpfsHash;
  }

};
