/**
 * KAOKAB5GC Ops Console – Backend API
 * Minimal, safe foundation
 */

const express = require("express");
const { execFile } = require("child_process");

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// ---------- helpers ----------
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

// ---------- routes ----------

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

// Apply configuration (777.sh)
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

// ---------- start ----------
app.listen(PORT, "0.0.0.0", () => {
  console.log(`KAOKAB API listening on port ${PORT}`);
});
