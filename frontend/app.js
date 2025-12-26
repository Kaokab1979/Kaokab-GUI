/**
 * KAOKAB5GC Ops Console – Frontend Logic
 * Phase-1: JWT authenticated, production-grade, block-separated
 */

/* ======================================================
 * DOM REFERENCES
 * ====================================================== */

const nfListInfra = document.getElementById("nfList-infra");
const nfListCP    = document.getElementById("nfList-cp");
const nfListUP    = document.getElementById("nfList-up");

const ranList        = document.getElementById("ranList");
const subscriberList = document.getElementById("subscriberList");
const lastUpdate     = document.getElementById("lastUpdate");

/* ======================================================
 * UTILITIES
 * ====================================================== */

function esc(s) {
  return String(s || "").replace(/[&<>"']/g, c =>
    ({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[c])
  );
}

function redirectToLogin() {
  localStorage.removeItem("kaokab-token");
  window.location.href = "/login.html";
}

/* ======================================================
 * AUTH FETCH (JWT)
 * ====================================================== */

async function authFetch(url, options = {}) {
  const token = localStorage.getItem("kaokab-token");

  // No token => force login
  if (!token) {
    redirectToLogin();
    return null;
  }

  const res = await fetch(url, {
    ...options,
    headers: {
      ...(options.headers || {}),
      Authorization: "Bearer " + token
    }
  });

  // Token invalid/expired => force login
  if (res.status === 401) {
    redirectToLogin();
    return null;
  }

  return res;
}

/* ======================================================
 * FETCH: SYSTEM STATUS (NFs + RAN)
 * ====================================================== */

async function fetchStatus() {
  try {
    const res = await authFetch("/api/status");
    if (!res) return;

    if (!res.ok) throw new Error("status api failed");
    const data = await res.json();
    renderStatus(data);
  } catch (err) {
    nfListCP.innerHTML =
      `<div class="placeholder">Backend not reachable</div>`;
    ranList.innerHTML =
      `<div class="placeholder">No RAN info</div>`;
  }
}

/* ======================================================
 * FETCH: SUBSCRIBERS
 * ====================================================== */

async function fetchSubscribers() {
  try {
    const res = await authFetch("/api/subscribers");
    if (!res) return;

    if (!res.ok) throw new Error("subscriber api failed");
    const data = await res.json();
    renderSubscribers(data.subscribers || []);
  } catch (err) {
    subscriberList.innerHTML =
      `<div class="placeholder">No subscribers provisioned</div>`;
  }
}

/* ======================================================
 * RENDER: SYSTEM STATUS
 * ====================================================== */

function renderStatus(data) {
  lastUpdate.textContent =
    `Last update: ${new Date().toLocaleTimeString()}`;

  /* ---------- Network Functions ---------- */

  nfListInfra.innerHTML = "";
  nfListCP.innerHTML    = "";
  nfListUP.innerHTML    = "";

  const INFRA = new Set(["mongod"]);
  const UP    = new Set(["open5gs-upfd"]);

  (data.nfs || []).forEach(nf => {
    const row = document.createElement("div");
    row.className = "row";

    const stateClass =
      nf.active === "active" ? "badge green" :
      (nf.active === "inactive" || nf.active === "failed") ? "badge red" :
      "badge gray";

    row.innerHTML = `
      <span>${esc(nf.name)}</span>
      <span class="${stateClass}">${esc(nf.active)}</span>
    `;

    if (INFRA.has(nf.name))      nfListInfra.appendChild(row);
    else if (UP.has(nf.name))    nfListUP.appendChild(row);
    else                         nfListCP.appendChild(row);
  });

  /* ---------- RAN Connections ---------- */

  ranList.innerHTML = "";
  const gnbs = data.ran?.gnb_ngap_38412 || [];
  const enbs = data.ran?.enb_s1ap_36412 || [];

  if (!gnbs.length && !enbs.length) {
    ranList.innerHTML =
      `<div class="placeholder">No gNB / eNB detected</div>`;
    return;
  }

  gnbs.forEach(g => {
    const row = document.createElement("div");
    row.className = "row";
    row.innerHTML = `
      <span>gNB ${esc(g.ip)}</span>
      <span class="badge green">CONNECTED</span>
    `;
    ranList.appendChild(row);
  });

  enbs.forEach(e => {
    const row = document.createElement("div");
    row.className = "row";
    row.innerHTML = `
      <span>eNB ${esc(e.ip || e)}</span>
      <span class="badge green">CONNECTED</span>
    `;
    ranList.appendChild(row);
  });
}

/* ======================================================
 * RENDER: SUBSCRIBERS
 * ====================================================== */

function renderSubscribers(subs) {
  subscriberList.innerHTML = "";

  if (!subs.length) {
    subscriberList.innerHTML =
      `<div class="placeholder">No subscribers provisioned</div>`;
    return;
  }

  subs.forEach(s => {
    const row = document.createElement("div");
    row.className = "row subscriber-row";
    row.innerHTML = `
      <span>IMSI ${esc(s.imsi)}</span>
      <span class="badge gray">${esc(s.status || "Provisioned")}</span>
    `;
    subscriberList.appendChild(row);
  });
}

/* ======================================================
 * INITIAL LOAD + AUTO REFRESH
 * ====================================================== */

fetchStatus();
fetchSubscribers();

setInterval(fetchStatus, 2000);
setInterval(fetchSubscribers, 5000);
