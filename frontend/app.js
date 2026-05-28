/* ============================================================
   app.js — CertChain Frontend Logic
   Wallet connection, contract interaction, UI management
   ============================================================ */


// ---- Contract ABI ----
const CONTRACT_ABI = [
  {"type":"constructor","inputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"authorizeIssuer","inputs":[{"name":"_issuer","type":"address"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"revokeIssuer","inputs":[{"name":"_issuer","type":"address"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"issueCertificate","inputs":[{"name":"_recipient","type":"address"},{"name":"_ipfsHash","type":"string"}],"outputs":[{"name":"certificateId","type":"bytes32"}],"stateMutability":"nonpayable"},
  {"type":"function","name":"revokeCertificate","inputs":[{"name":"_certificateId","type":"bytes32"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"verifyCertificate","inputs":[{"name":"_certificateId","type":"bytes32"}],"outputs":[{"name":"certificate","type":"tuple","components":[{"name":"recipient","type":"address"},{"name":"issuer","type":"address"},{"name":"ipfsHash","type":"string"},{"name":"issueDate","type":"uint256"},{"name":"status","type":"uint8"}]}],"stateMutability":"view"},
  {"type":"function","name":"isCertificateValid","inputs":[{"name":"_certificateId","type":"bytes32"}],"outputs":[{"name":"isValid","type":"bool"}],"stateMutability":"view"},
  {"type":"function","name":"getCertificatesByRecipient","inputs":[{"name":"_recipient","type":"address"}],"outputs":[{"name":"certificateIds","type":"bytes32[]"}],"stateMutability":"view"},
  {"type":"function","name":"getAllCertificateIds","inputs":[],"outputs":[{"name":"","type":"bytes32[]"}],"stateMutability":"view"},
  {"type":"function","name":"getOwner","inputs":[],"outputs":[{"name":"","type":"address"}],"stateMutability":"view"},
  {"type":"function","name":"getCertificateCount","inputs":[],"outputs":[{"name":"","type":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"isAuthorizedIssuer","inputs":[{"name":"_issuer","type":"address"}],"outputs":[{"name":"","type":"bool"}],"stateMutability":"view"},
  {"type":"event","name":"CertificateIssued","inputs":[{"name":"certificateId","type":"bytes32","indexed":true},{"name":"recipient","type":"address","indexed":true},{"name":"issuer","type":"address","indexed":true},{"name":"ipfsHash","type":"string","indexed":false},{"name":"issueDate","type":"uint256","indexed":false}]},
  {"type":"event","name":"CertificateRevoked","inputs":[{"name":"certificateId","type":"bytes32","indexed":true},{"name":"revokedBy","type":"address","indexed":true},{"name":"revokeDate","type":"uint256","indexed":false}]},
  {"type":"event","name":"IssuerAuthorized","inputs":[{"name":"issuer","type":"address","indexed":true},{"name":"authorizedBy","type":"address","indexed":true}]},
  {"type":"event","name":"IssuerRevoked","inputs":[{"name":"issuer","type":"address","indexed":true},{"name":"revokedBy","type":"address","indexed":true}]}
];

// ---- Network Config ----
const NETWORK_CONFIG = {
  31337:    { name: "Anvil (Local)", contractAddress: "", blockExplorer: "" },
  11155111: { name: "Sepolia",      contractAddress: "", blockExplorer: "https://sepolia.etherscan.io" }
};

// ---- App State ----
let provider = null;
let signer = null;
let contract = null;
let contractAddress = null;
let currentAccount = null;
let blockExplorerUrl = "";
let currentNetworkName = "";


/* ============================================================
   INITIALIZATION
   ============================================================ */
window.addEventListener("DOMContentLoaded", async () => {
  if (!window.ethereum) {
    showToast("MetaMask not detected. Serve this page via http://localhost (run: make serve)", "error");
    return;
  }

  // Detect chain using ethers.js BrowserProvider — more reliable than raw eth_chainId
  const _tempProvider = new ethers.BrowserProvider(window.ethereum);
  const _network = await _tempProvider.getNetwork();
  const chainId = Number(_network.chainId);
  console.log("[CertChain] Detected chainId:", chainId, "| Expected Sepolia=11155111, Anvil=31337");
  const netConfig = NETWORK_CONFIG[chainId];

  if (!netConfig) {
    showToast("Unsupported network (chainId " + chainId + "). Switch to Anvil (31337) or Sepolia (11155111).", "error");
    return;
  }

  if (!netConfig.contractAddress) {
    const addr = prompt(
      "Connected to " + netConfig.name + ".\n\n" +
      "Deploy first:\n  make deploy          (Anvil)\n  make deploy-sepolia  (Sepolia)\n\n" +
      "Paste the deployed contract address:"
    );
    if (addr && addr.startsWith("0x")) {
      netConfig.contractAddress = addr;
    } else {
      showToast("No contract address provided.", "error");
      return;
    }
  }

  // Validate that a real contract exists at this address on this network.
  // If logs are empty after a transaction, this is always the cause.
  try {
    const tempProvider = new ethers.BrowserProvider(window.ethereum);
    const code = await tempProvider.getCode(netConfig.contractAddress);
    if (code === "0x") {
      showToast(
        "No contract found at that address on " + netConfig.name +
        ". Redeploy and refresh the page.",
        "error"
      );
      netConfig.contractAddress = "";   // reset so prompt shows again on next load
      return;
    }
  } catch (e) {
    console.warn("[CertChain] Could not verify contract code:", e.message);
  }

  contractAddress = netConfig.contractAddress;
  currentNetworkName = netConfig.name;
  blockExplorerUrl = netConfig.blockExplorer || "";

  // Show network badge
  const badge = document.getElementById("networkBadge");
  badge.textContent = currentNetworkName;
  badge.classList.add("visible");

  // Pinata config UI init
  updatePinataStatus();
  document.getElementById("pinataConfigBody").style.display = "none";
  const savedJwt = IPFS.getPinataJwt();
  if (savedJwt) document.getElementById("pinataJwt").value = savedJwt;

  // Refresh stats
  refreshStats();

  // Auto-connect if already connected
  const accounts = await window.ethereum.request({ method: "eth_accounts" });
  if (accounts.length > 0) {
    await connectWallet();
  }
});


/* ============================================================
   WALLET CONNECTION
   ============================================================ */
async function connectWallet() {
  if (!window.ethereum) return showToast("Install MetaMask!", "error");

  try {
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    currentAccount = accounts[0];

    provider = new ethers.BrowserProvider(window.ethereum);
    signer = await provider.getSigner();
    contract = new ethers.Contract(contractAddress, CONTRACT_ABI, signer);

    // Re-detect network and update badge (fixes wrong name on Sepolia)
    const network = await provider.getNetwork();
    const detectedChainId = Number(network.chainId);
    const detectedNetConfig = NETWORK_CONFIG[detectedChainId];
    if (detectedNetConfig) {
      currentNetworkName = detectedNetConfig.name;
      blockExplorerUrl = detectedNetConfig.blockExplorer || "";
      const netBadge = document.getElementById("networkBadge");
      netBadge.textContent = currentNetworkName;
      netBadge.classList.add("visible");
    }

    // Update UI
    document.getElementById("walletDot").classList.add("active");
    document.getElementById("walletLabel").textContent =
      currentAccount.slice(0, 6) + "..." + currentAccount.slice(-4);

    const btn = document.getElementById("connectBtn");
    btn.classList.add("connected");

    await updateRole();
    showToast("Wallet connected!", "success");

    // Listeners
    window.ethereum.on("accountsChanged", async (accs) => {
      if (accs.length === 0) { location.reload(); return; }
      currentAccount = accs[0];
      signer = await provider.getSigner();
      contract = new ethers.Contract(contractAddress, CONTRACT_ABI, signer);
      document.getElementById("walletLabel").textContent =
        currentAccount.slice(0, 6) + "..." + currentAccount.slice(-4);
      await updateRole();
    });

    window.ethereum.on("chainChanged", () => location.reload());
  } catch (err) {
    showToast("Connection failed: " + err.message, "error");
  }
}

async function updateRole() {
  const badge = document.getElementById("roleBadge");
  try {
    const owner = await contract.getOwner();
    if (currentAccount.toLowerCase() === owner.toLowerCase()) {
      badge.textContent = "Owner";
      badge.className = "role-badge role-owner visible";
      return;
    }
    const isIssuer = await contract.isAuthorizedIssuer(currentAccount);
    if (isIssuer) {
      badge.textContent = "Issuer";
      badge.className = "role-badge role-issuer visible";
      return;
    }
    badge.textContent = "Viewer";
    badge.className = "role-badge role-viewer visible";
  } catch {
    badge.className = "role-badge";
  }
}


/* ============================================================
   TAB / NAVIGATION
   ============================================================ */
function switchTab(name) {
  // Update nav links
  document.querySelectorAll(".nav-link").forEach(l => l.classList.remove("active"));
  event.target.classList.add("active");

  // Show/hide hero (only on verify tab)
  const hero = document.getElementById("heroSection");
  const statsBar = document.querySelector(".stats-bar");
  if (name === "verify") {
    hero.style.display = "block";
    statsBar.style.display = "block";
  } else {
    hero.style.display = "none";
    statsBar.style.display = "none";
  }

  // Show/hide panels
  document.querySelectorAll(".panel").forEach(p => p.classList.remove("active"));
  const panel = document.getElementById("panel-" + name);
  if (panel) panel.classList.add("active");

  // Refresh stats on dashboard
  if (name === "dashboard") refreshStats();
}


/* ============================================================
   VERIFY CERTIFICATE
   ============================================================ */
async function verifyCertificate() {
  const certId = document.getElementById("verifyId").value.trim();
  if (!certId) return showToast("Enter a certificate ID.", "error");

  const resultDiv = document.getElementById("verifyResult");
  resultDiv.innerHTML = '<p class="loading-text"><span class="spinner"></span> Searching the blockchain...</p>';

  try {
    const rp = provider || new ethers.BrowserProvider(window.ethereum);
    const rc = new ethers.Contract(contractAddress, CONTRACT_ABI, rp);
    const cert = await rc.verifyCertificate(certId);

    const isValid = Number(cert.status) === 0;
    const issueDate = new Date(Number(cert.issueDate) * 1000).toLocaleDateString("en-US", {
      year: "numeric", month: "long", day: "numeric"
    });
    const ipfsLink = "https://ipfs.io/ipfs/" + cert.ipfsHash;

    // Fetch human-readable fields (name, course) from IPFS metadata
    let recipientName = "—";
    let courseName = "Certificate";
    try {
      const meta = await fetch("https://ipfs.io/ipfs/" + cert.ipfsHash).then(r => r.json());
      if (meta.recipientName) recipientName = meta.recipientName;
      if (meta.courseName)    courseName    = meta.courseName;
    } catch (e) { /* IPFS unavailable — show addresses only */ }

    resultDiv.innerHTML =
      '<div class="cert-card">' +
        '<div class="cert-header">' +
          '<h3>' + esc(courseName) + '</h3>' +
          '<span class="' + (isValid ? 'status-valid' : 'status-revoked') + '">' +
            (isValid ? 'Valid' : 'Revoked') +
          '</span>' +
        '</div>' +
        '<div class="cert-row"><span class="label">Certificate ID</span><span class="value" style="font-size:12px">' + esc(certId) + '</span></div>' +
        '<div class="cert-row"><span class="label">Recipient</span><span class="value">' + esc(recipientName) + '</span></div>' +
        '<div class="cert-row"><span class="label">Recipient Address</span><span class="value" style="font-size:12px">' + cert.recipient + '</span></div>' +
        '<div class="cert-row"><span class="label">Issuer</span><span class="value" style="font-size:12px">' + cert.issuer + '</span></div>' +
        '<div class="cert-row"><span class="label">IPFS Metadata</span><span class="value"><a href="' + ipfsLink + '" target="_blank">' + esc(cert.ipfsHash.slice(0, 24)) + '...</a></span></div>' +
        '<div class="cert-row"><span class="label">Issue Date</span><span class="value">' + issueDate + '</span></div>' +
      '</div>';
  } catch (err) {
    resultDiv.innerHTML = '<div class="cert-card"><p style="color:var(--red);font-weight:600;">Certificate not found. Please check the ID and try again.</p></div>';
  }
}


/* ============================================================
   PINATA UI HANDLERS
   ============================================================ */
function updatePinataStatus() {
  const status = document.getElementById("pinataStatus");
  if (!status) return;
  if (IPFS.isPinataConfigured()) {
    status.textContent = "Configured";
    status.className = "pinata-status pinata-ok";
  } else {
    status.textContent = "Not set";
    status.className = "pinata-status pinata-missing";
  }
}

function togglePinataConfig() {
  const body = document.getElementById("pinataConfigBody");
  const chevron = document.getElementById("pinataChevron");
  const open = body.style.display !== "none";
  body.style.display = open ? "none" : "block";
  chevron.style.transform = open ? "" : "rotate(180deg)";
}

function savePinataJwtFromUI() {
  const jwt = document.getElementById("pinataJwt").value.trim();
  try {
    IPFS.savePinataJwt(jwt);
    updatePinataStatus();
    document.getElementById("pinataConfigBody").style.display = "none";
    showToast("Pinata key saved.", "success");
  } catch (err) {
    showToast(err.message, "error");
  }
}


/* ============================================================
   ISSUE CERTIFICATE
   ============================================================ */
async function issueCertificate() {
  if (!signer) return showToast("Connect your wallet first.", "error");

  const recipient = document.getElementById("issueRecipient").value.trim();
  const name = document.getElementById("issueRecipientName").value.trim();
  const course = document.getElementById("issueCourseName").value.trim();
  const description = document.getElementById("issueDescription").value.trim();

  if (!recipient || !name || !course) {
    return showToast("Please fill in all required fields.", "error");
  }
  if (!ethers.isAddress(recipient)) {
    return showToast("Invalid recipient address. Must be a valid 0x... Ethereum address (42 chars).", "error");
  }

  const btn = document.getElementById("issueBtn");
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner"></span> Uploading to IPFS...';

  let ipfs;
  try {
    const metadata = IPFS.buildCertificateMetadata({
      recipientName: name,
      recipientAddress: recipient,
      courseName: course,
      description,
      issuerAddress: currentAccount
    });
    ipfs = await IPFS.uploadCertificateMetadata(metadata);
    document.getElementById("issueIpfsHash").value = ipfs;
    showToast("Uploaded to IPFS: " + ipfs.slice(0, 16) + "...", "success");
  } catch (err) {
    showToast(err.message, "error");
    btn.disabled = false;
    btn.innerHTML = "Issue Certificate";
    return;
  }

  btn.innerHTML = '<span class="spinner"></span> Issuing on-chain...';

  try {
    const tx = await contract.issueCertificate(ethers.getAddress(recipient), ipfs);
    showToast("Transaction sent. Waiting for confirmation...", "info");
    const receipt = await tx.wait();

    // --- Extract Certificate ID from receipt ---
    // Debug: log receipt so we can inspect if something goes wrong
    console.log("[CertChain] receipt.logs:", receipt.logs);

    let certIdStr = "";

    // Approach 1: ethers.js v6 EventLog — parsed logs have .fragment.name and .args
    for (const log of receipt.logs) {
      if (log.fragment && log.fragment.name === "CertificateIssued") {
        certIdStr = log.args[0];               // args[0] = certificateId (first param)
        console.log("[CertChain] Found via EventLog.args:", certIdStr);
        break;
      }
    }

    // Approach 2: Manual topic hash match — topics[0] = event sig, topics[1] = certificateId
    if (!certIdStr) {
      const certIssuedSig = ethers.id("CertificateIssued(bytes32,address,address,string,uint256)");
      for (const log of receipt.logs) {
        if (log.topics && log.topics.length >= 2 &&
            log.topics[0].toLowerCase() === certIssuedSig.toLowerCase()) {
          certIdStr = log.topics[1];
          console.log("[CertChain] Found via topics[1]:", certIdStr);
          break;
        }
      }
    }

    // Approach 3: ethers Interface.parseLog() fallback
    if (!certIdStr) {
      const iface = new ethers.Interface(CONTRACT_ABI);
      for (const log of receipt.logs) {
        try {
          const decoded = iface.parseLog({ topics: Array.from(log.topics), data: log.data });
          if (decoded && decoded.name === "CertificateIssued") {
            certIdStr = decoded.args[0];
            console.log("[CertChain] Found via Interface.parseLog:", certIdStr);
            break;
          }
        } catch (e) { /* not this event, skip */ }
      }
    }

    if (!certIdStr) {
      console.warn("[CertChain] Could not extract cert ID. Full logs:", JSON.stringify(receipt.logs, null, 2));
      certIdStr = "Not found — check the Dashboard tab";
    }

    const txLink = blockExplorerUrl
      ? '<a href="' + blockExplorerUrl + '/tx/' + receipt.hash + '" target="_blank">' + receipt.hash.slice(0, 20) + '...</a>'
      : receipt.hash.slice(0, 24) + '...';

    document.getElementById("issueResult").innerHTML =
      '<div class="cert-card">' +
        '<p class="cert-success">Certificate Issued Successfully</p>' +
        '<div class="cert-row"><span class="label">Certificate ID</span><span class="value" style="font-size:12px">' + esc(certIdStr.toString()) + '</span></div>' +
        '<div style="padding:4px 0 12px"><button class="btn-copy" onclick="copyToClipboard(\'' + certIdStr + '\')">Copy ID</button></div>' +
        '<div class="cert-row"><span class="label">Transaction</span><span class="value" style="font-size:12px">' + txLink + '</span></div>' +
      '</div>';

    showToast("Certificate issued on-chain!", "success");
    refreshStats();

    // Clear form
    ["issueRecipient", "issueRecipientName", "issueCourseName", "issueDescription", "issueIpfsHash"]
      .forEach(id => document.getElementById(id).value = "");
  } catch (err) {
    showToast("Failed: " + (err.reason || err.message), "error");
  } finally {
    btn.disabled = false;
    btn.innerHTML = "Issue Certificate";
  }
}


/* ============================================================
   REVOKE CERTIFICATE
   ============================================================ */
async function revokeCertificate() {
  if (!signer) return showToast("Connect your wallet first.", "error");
  const id = document.getElementById("revokeId").value.trim();
  if (!id) return showToast("Enter a certificate ID.", "error");

  try {
    const tx = await contract.revokeCertificate(id);
    showToast("Revoking...", "info");
    await tx.wait();
    document.getElementById("revokeResult").innerHTML =
      '<div class="cert-card"><p style="color:var(--green);font-weight:600;">Certificate has been revoked successfully.</p></div>';
    showToast("Certificate revoked.", "success");
  } catch (err) {
    showToast("Failed: " + (err.reason || err.message), "error");
  }
}


/* ============================================================
   MANAGE ISSUERS
   ============================================================ */
async function authorizeIssuer() {
  if (!signer) return showToast("Connect your wallet first.", "error");
  const addr = document.getElementById("issuerAddress").value.trim();
  if (!addr) return showToast("Enter an address.", "error");
  if (!ethers.isAddress(addr)) return showToast("Invalid address. Must be 0x... (42 chars).", "error");

  try {
    const tx = await contract.authorizeIssuer(ethers.getAddress(addr));
    showToast("Authorizing...", "info");
    await tx.wait();
    showToast("Issuer authorized!", "success");
  } catch (err) {
    showToast("Failed: " + (err.reason || err.message), "error");
  }
}

async function revokeIssuerAccess() {
  if (!signer) return showToast("Connect your wallet first.", "error");
  const addr = document.getElementById("issuerAddress").value.trim();
  if (!addr) return showToast("Enter an address.", "error");
  if (!ethers.isAddress(addr)) return showToast("Invalid address. Must be 0x... (42 chars).", "error");

  try {
    const tx = await contract.revokeIssuer(ethers.getAddress(addr));
    showToast("Revoking issuer...", "info");
    await tx.wait();
    showToast("Issuer access revoked.", "success");
  } catch (err) {
    showToast("Failed: " + (err.reason || err.message), "error");
  }
}

async function checkIssuer() {
  const addr = document.getElementById("checkIssuerAddress").value.trim();
  if (!addr) return showToast("Enter an address to check.", "error");
  if (!ethers.isAddress(addr)) return showToast("Invalid address. Must be 0x... (42 chars).", "error");

  try {
    const rp = provider || new ethers.BrowserProvider(window.ethereum);
    const rc = new ethers.Contract(contractAddress, CONTRACT_ABI, rp);
    const isAuth = await rc.isAuthorizedIssuer(addr);

    document.getElementById("checkIssuerResult").innerHTML = isAuth
      ? '<div class="auth-result auth-yes">Authorized Issuer</div>'
      : '<div class="auth-result auth-no">Not Authorized</div>';
  } catch (err) {
    showToast("Check failed: " + err.message, "error");
  }
}


/* ============================================================
   DASHBOARD / LOOKUP
   ============================================================ */
async function refreshStats() {
  try {
    const rp = provider || new ethers.BrowserProvider(window.ethereum);
    const rc = new ethers.Contract(contractAddress, CONTRACT_ABI, rp);

    const count = await rc.getCertificateCount();
    document.getElementById("statTotalCerts").textContent = count.toString();

    const owner = await rc.getOwner();
    document.getElementById("statIssuers").textContent =
      owner.slice(0, 6) + "..." + owner.slice(-4);
  } catch { /* contract might not be connected yet */ }
}

async function lookupRecipient() {
  const addr = document.getElementById("dashRecipient").value.trim();
  if (!addr) return showToast("Enter a recipient address.", "error");
  if (!ethers.isAddress(addr)) return showToast("Invalid address. Must be 0x... (42 chars).", "error");

  // Must have wallet connected — reuse the verified contract instance
  if (!contract) return showToast("Connect your wallet first to use the Dashboard.", "error");

  const resultDiv = document.getElementById("dashResult");
  resultDiv.innerHTML = '<p class="loading-text"><span class="spinner"></span> Looking up certificates...</p>';

  try {
    const ids = await contract.getCertificatesByRecipient(ethers.getAddress(addr));

    if (ids.length === 0) {
      resultDiv.innerHTML = '<div class="cert-card"><p style="color:var(--gray-500)">No certificates found for this address.</p></div>';
      return;
    }

    let html = "";
    for (const id of ids) {
      const cert = await contract.verifyCertificate(id);
      const isValid = Number(cert.status) === 0;
      const date = new Date(Number(cert.issueDate) * 1000).toLocaleDateString("en-US", {
        year: "numeric", month: "short", day: "numeric"
      });

      // Fetch name and course from IPFS metadata
      let recipientName = "—";
      let courseName = "Certificate";
      try {
        const meta = await fetch("https://ipfs.io/ipfs/" + cert.ipfsHash).then(r => r.json());
        if (meta.recipientName) recipientName = meta.recipientName;
        if (meta.courseName)    courseName    = meta.courseName;
      } catch (e) { /* IPFS unavailable — show fallback */ }

      html +=
        '<div class="cert-card" style="margin-top:12px">' +
          '<div class="cert-header">' +
            '<h3>' + esc(courseName) + '</h3>' +
            '<span class="' + (isValid ? 'status-valid' : 'status-revoked') + '">' +
              (isValid ? 'Valid' : 'Revoked') +
            '</span>' +
          '</div>' +
          '<div class="cert-row"><span class="label">Certificate ID</span><span class="value" style="font-size:12px">' + id + '</span></div>' +
          '<div class="cert-row"><span class="label">Recipient</span><span class="value">' + esc(recipientName) + '</span></div>' +
          '<div class="cert-row"><span class="label">Issued</span><span class="value">' + date + '</span></div>' +
        '</div>';
    }
    resultDiv.innerHTML = html;
  } catch (err) {
    resultDiv.innerHTML = '<div class="cert-card"><p style="color:var(--red)">Lookup failed: ' + err.message + '</p></div>';
  }
}


/* ============================================================
   UTILITIES
   ============================================================ */
function esc(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

function showToast(message, type) {
  type = type || "info";
  const container = document.getElementById("toastContainer");
  const toast = document.createElement("div");
  toast.className = "toast toast-" + type;
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(function() { toast.remove(); }, 4500);
}

function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(function() {
    showToast("Certificate ID copied!", "success");
  });
}
