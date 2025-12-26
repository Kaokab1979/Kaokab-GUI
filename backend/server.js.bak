/**
 * KAOKAB5GC Ops Console – Backend API
 * Production-safe foundation with MongoDB integration
 */

const express = require("express");
const { execFile } = require("child_process");
const { MongoClient } = require("mongodb");

const app = express();
const PORT = process.env.PORT || 3000;

// --------------------------------------------------
// MongoDB (Open5GS)
// --------------------------------------------------

const MONGO_URL = "mongodb://127.0.0.1:27017";
const DB_NAME = "open5gs";

let mongoClient;
let db;

// --------------------------------------------------
// Middleware
// --------------------------------------------------

app.use(express.json());
app.use("/", express.static("/opt/kaokab/frontend"));

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function run(cmd, args = []) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { timeout: 15000 }, (err, stdout, stderr) => {
      if (err) {
        return reject({
          error: err.message,
          stderr: stderr?.toString() || ""
        });
      }
      resolve(stdout.toString());
    });
  });
}

// --------------------------------------------------
// MongoDB connection (once)
// --------------------------------------------------

(async () => {
  try {
    mongoClient = new MongoClient(MONGO_URL);
    await mongoClient.connect();
    db = mongoClient.db(DB_NAME);
    console.log("✅ Connected to MongoDB (open5gs)");
  } catch (err) {
    console.error("❌ MongoDB connection failed:", err);
    process.exit(1);
  }
})();

// --------------------------------------------------
// Routes
// --------------------------------------------------

// Health check
app.get("/api/health", (req, res) => {
  res.json({
    ok: true,
    service: "kaokab-api",
    ts: new Date().toISOString()
  });
});

// NF + system status (calls kaokabctl)
app.get("/api/status", async (req, res) => {
  try {
    const output = await run("/usr/local/sbin/kaokabctl", ["status"]);
    res.type("json").send(output);
  } catch (e) {
    res.status(500).json({
      ok: false,
      error: "Failed to get status",
      detail: e
    });
  }
});

// --------------------------------------------------
// Subscribers (Provisioning – MongoDB / Open5GS)
// --------------------------------------------------

app.post("/api/subscribers/add", async (req, res) => {
  try {
    const sub = req.body;

    console.log("📡 New subscriber received from GUI:");
    console.log(JSON.stringify(sub, null, 2));

    const doc = {
      imsi: sub.imsi,
      key: sub.ki,
      opc: sub.opc,
      amf: "8000",
      slice: [
        {
          sst: sub.snssai.sst,
          sd: sub.snssai.sd
        }
      ],
      dnn: [sub.dnn]
    };

    await db.collection("subscribers").insertOne(doc);

    console.log(`✅ Subscriber inserted into MongoDB: ${sub.imsi}`);

    res.json({
      ok: true,
      message: "Subscriber provisioned",
      subscriber: {
        name: sub.name,
        imsi: sub.imsi,
        dnn: sub.dnn,
        snssai: sub.snssai,
        status: "Provisioned"
      }
    });
  } catch (err) {
    console.error("❌ Subscriber insert failed:", err);
    res.status(500).json({
      ok: false,
      error: "Failed to provision subscriber"
    });
  }
});

// --------------------------------------------------
// Apply configuration (future)
// --------------------------------------------------

app.post("/api/apply", async (req, res) => {
  try {
    const output = await run("/usr/local/sbin/kaokabctl", ["apply"]);
    res.json({ ok: true, output });
  } catch (e) {
    res.status(500).json({
      ok: false,
      error: "Apply failed",
      detail: e
    });
  }
});

// Restart a service
app.post("/api/restart/:service", async (req, res) => {
  const service = req.params.service;
  try {
    const output = await run("/usr/local/sbin/kaokabctl", ["restart", service]);
    res.json({ ok: true, output });
  } catch (e) {
    res.status(500).json({
      ok: false,
      error: `Failed to restart ${service}`,
      detail: e
    });
  }
});

// --------------------------------------------------
// Start server
// --------------------------------------------------

app.listen(PORT, "0.0.0.0", () => {
  console.log(`KAOKAB API listening on port ${PORT}`);
});
