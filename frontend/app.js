/**
 * KAOKAB5GC Ops Console – Frontend Logic
 * Polls backend API and renders live status
 */

const nfListInfra = document.getElementById("nfList-infra");
const nfListCP = document.getElementById("nfList-cp");
const nfListUP = document.getElementById("nfList-up");
const ranList = document.getElementById("ranList");
const subscriberList = document.getElementById("subscriberList");
const lastUpdate = document.getElementById("lastUpdate");
const applyBtn = document.getElementById("applyConfig");
const actionOutput = document.getElementById("actionOutput");

function badgeClass(state) {
  if (state === "active") return "badge green";
  if (state === "inactive" || state === "failed") return "badge red";
  return "badge gray";
}

function escapeHtml(s) {
  return String(s || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  }[c]));
}

async function fetchStatus() {
  try {
    const res = await fetch("/api/status");
    if (!res.ok) throw new Error("API error");

    const data = await res.json();
    renderStatus(data);
  } catch (e) {
    nfList.innerHTML =
      `<div class="placeholder">Backend not reachable</div>`;
    ranList.innerHTML =
      `<div class="placeholder">No RAN info</div>`;
    subscriberList.innerHTML =
      `<div class="placeholder">No subscriber info</div>`;
  }
}

function renderStatus(data) {
  lastUpdate.textContent = `Last update: ${new Date().toLocaleTimeString()}`;

  /* ---------- Network Functions (Grouped) ---------- */
nfListInfra.innerHTML = "";
nfListCP.innerHTML = "";
nfListUP.innerHTML = "";

// Define service groups (you can tune anytime)
const INFRA = new Set(["mongod"]);
const UP = new Set(["open5gs-upfd"]);

// Everything else goes to Control Plane by default
const nfs = (data.nfs || []).slice();

function addRow(target, nf) {
  const row = document.createElement("div");
  row.className = "row";
  row.innerHTML = `
    <span>${escapeHtml(nf.name)}</span>
    <span class="${badgeClass(nf.active)}">${escapeHtml(nf.active)}</span>
  `;
  target.appendChild(row);
}

if (!nfs.length) {
  nfListCP.innerHTML = `<div class="placeholder">No NFs reported</div>`;
} else {
  nfs.forEach((nf) => {
    if (INFRA.has(nf.name)) return addRow(nfListInfra, nf);
    if (UP.has(nf.name)) return addRow(nfListUP, nf);
    return addRow(nfListCP, nf);
  });
}

 /* ---------- RAN Connections ---------- */
ranList.innerHTML = "";

const gnbs = data.ran?.gnb_ngap_38412 || [];
const enbs = data.ran?.enb_s1ap_36412 || [];

if (!gnbs.length && !enbs.length) {
  ranList.innerHTML =
    `<div class="placeholder">No gNB / eNB connected</div>`;
}

/* gNBs (objects: { ip, last_seen }) */
gnbs.forEach((g) => {
  const row = document.createElement("div");
  row.className = "row";

  const ip = g.ip ?? "unknown";

  row.innerHTML = `
    <span>gNB ${escapeHtml(ip)}</span>
    <span class="badge green">CONNECTED</span>
  `;

  ranList.appendChild(row);
});

/* eNBs (still empty / future) */
enbs.forEach((ip) => {
  const row = document.createElement("div");
  row.className = "row";
  row.innerHTML = `
    <span>eNB ${escapeHtml(ip)}</span>
    <span class="badge green">CONNECTED</span>
  `;
  ranList.appendChild(row);
});

  /* ---------- Subscribers ---------- */
  subscriberList.innerHTML = "";
  const subs = data.subscribers || [];

  if (!subs.length) {
    subscriberList.innerHTML =
      `<div class="placeholder">No subscribers provisioned</div>`;
  }

  subs.forEach((s) => {
    const row = document.createElement("div");
    row.className = "row";
    row.innerHTML = `
      <span>IMSI ${escapeHtml(s.imsi || "")}</span>
      <span class="badge gray">${escapeHtml(s.msisdn || "")}</span>
    `;
    subscriberList.appendChild(row);
  });
}

/* ---------- Actions ---------- */

applyBtn.addEventListener("click", async () => {
  actionOutput.textContent = "Applying configuration...";
  try {
    const res = await fetch("/api/apply", { method: "POST" });
    const data = await res.json();
    actionOutput.textContent =
      data.ok ? data.output || "Done" : JSON.stringify(data, null, 2);
  } catch (e) {
    actionOutput.textContent = `Error: ${e.message}`;
  }
});

/* ---------- Auto refresh ---------- */

fetchStatus();
setInterval(fetchStatus, 2000);
