/**
 * KAOKAB5GC Ops Console – Backend API
 * Phase 1: JWT Authentication + MongoDB + Ops APIs
 */

const express = require("express");
const { execFile } = require("child_process");
const { MongoClient } = require("mongodb");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");

const app = express();
const PORT = 3000;

/* ======================================================
 * CONFIG
 * ====================================================== */

const MONGO_URL = "mongodb://127.0.0.1:27017";
const DB_NAME = "open5gs";
const JWT_SECRET =
  process.env.KAOKAB_JWT_SECRET || "CHANGE_ME_NOW_KAOKAB_SECRET";

/* ======================================================
 * MONGODB
 * ====================================================== */

let db = null;

async function connectMongo() {
  if (db) return db;

  const client = new MongoClient(MONGO_URL);
  await client.connect();
  db = client.db(DB_NAME);

  console.log("✅ MongoDB connected (open5gs)");
  return db;
}

/* ======================================================
 * MIDDLEWARE
 * ====================================================== */

app.use(express.json());
app.use("/", express.static("/opt/kaokab/frontend"));

/* ======================================================
 * HELPERS
 * ====================================================== */

function run(cmd, args = []) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { timeout: 15000 }, (err, stdout, stderr) => {
      if (err) {
        return reject(stderr?.toString() || err.message);
      }
      resolve(stdout.toString());
    });
  });
}

/* ======================================================
 * AUTH (JWT)
 * ====================================================== */

function authRequired(req, res, next) {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;

  if (!token) {
    return res.status(401).json({ ok: false, error: "Missing token" });
  }

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ ok: false, error: "Invalid token" });
  }
}

/* ======================================================
 * ROUTES
 * ====================================================== */

/* ---------- Health (no auth) ---------- */

app.get("/api/health", (req, res) => {
  res.json({
    ok: true,
    service: "kaokab-api",
    ts: new Date().toISOString()
  });
});

/* ---------- Login (no auth) ---------- */

app.post("/api/auth/login", async (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res
        .status(400)
        .json({ ok: false, error: "Missing username/password" });
    }

    const db = await connectMongo();
    const user = await db.collection("users").findOne({ username });

    if (!user) {
      return res.status(401).json({ ok: false, error: "Invalid credentials" });
    }

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
      return res.status(401).json({ ok: false, error: "Invalid credentials" });
    }

    const token = jwt.sign(
      {
        sub: String(user._id),
        username: user.username,
        role: user.role || "operator"
      },
      JWT_SECRET,
      { expiresIn: "8h" }
    );

    res.json({
      ok: true,
      token,
      user: { username: user.username, role: user.role }
    });
  } catch (e) {
    console.error("Login error:", e);
    res.status(500).json({ ok: false, error: "Login failed" });
  }
});

/* ---------- Profile ---------- */

app.get("/api/auth/me", authRequired, (req, res) => {
  res.json({
    ok: true,
    user: {
      username: req.user.username,
      role: req.user.role
    }
  });
});

/* ---------- Change password ---------- */

app.post("/api/auth/change-password", authRequired, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body || {};
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ ok: false, error: "Missing fields" });
    }

    const db = await connectMongo();
    const user = await db
      .collection("users")
      .findOne({ username: req.user.username });

    if (!user) {
      return res.status(404).json({ ok: false, error: "User not found" });
    }

    const valid = await bcrypt.compare(currentPassword, user.password);
    if (!valid) {
      return res.status(401).json({ ok: false, error: "Wrong password" });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await db
      .collection("users")
      .updateOne({ _id: user._id }, { $set: { password: hash } });

    res.json({ ok: true, message: "Password updated" });
  } catch (e) {
    console.error("Change password error:", e);
    res.status(500).json({ ok: false, error: "Password update failed" });
  }
});

/* ---------- Status (protected) ---------- */

app.get("/api/status", authRequired, async (req, res) => {
  try {
    const out = await run("/usr/local/sbin/kaokabctl", ["status"]);
    res.type("json").send(out);
  } catch {
    res.status(500).json({ ok: false, error: "Status failed" });
  }
});

/* ---------- Subscribers ---------- */

app.get("/api/subscribers", authRequired, async (req, res) => {
  try {
    const db = await connectMongo();
    const subs = await db.collection("subscribers").find({}).toArray();

    res.json({
      ok: true,
      subscribers: subs.map((s) => ({
        imsi: s.imsi,
        dnn: s.dnn?.[0] || "",
        snssai: s.slice?.[0] || {},
        status: "Provisioned"
      }))
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, subscribers: [] });
  }
});

app.post("/api/subscribers/add", authRequired, async (req, res) => {
  try {
    const sub = req.body || {};
    if (
      !sub.imsi ||
      !sub.ki ||
      !sub.opc ||
      !sub.dnn ||
      !sub.snssai?.sst ||
      !sub.snssai?.sd
    ) {
      return res
        .status(400)
        .json({ ok: false, error: "Missing subscriber fields" });
    }

    const db = await connectMongo();
    await db.collection("subscribers").insertOne({
      imsi: sub.imsi,
      key: sub.ki,
      opc: sub.opc,
      amf: "8000",
      slice: [{ sst: sub.snssai.sst, sd: sub.snssai.sd }],
      dnn: [sub.dnn]
    });

    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: "Provisioning failed" });
  }
});

/* ---------- Ops ---------- */

app.post("/api/apply", authRequired, async (req, res) => {
  try {
    const output = await run("/usr/local/sbin/kaokabctl", ["apply"]);
    res.json({ ok: true, output });
  } catch {
    res.status(500).json({ ok: false, error: "Apply failed" });
  }
});

app.post("/api/restart/:service", authRequired, async (req, res) => {
  try {
    const output = await run("/usr/local/sbin/kaokabctl", [
      "restart",
      req.params.service
    ]);
    res.json({ ok: true, output });
  } catch {
    res
      .status(500)
      .json({ ok: false, error: "Service restart failed" });
  }
});

/* ======================================================
 * START
 * ====================================================== */

app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 KAOKAB API listening on ${PORT}`);
});
