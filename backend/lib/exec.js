/**
 * KAOKAB5GC – Safe command execution helper
 * All system calls are funneled through this module
 */

const { spawn } = require("child_process");

/**
 * Execute a command safely and return stdout
 * @param {string} cmd
 * @param {string[]} args
 * @param {number} timeoutMs
 */
function run(cmd, args = [], timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, {
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    const timer = setTimeout(() => {
      p.kill("SIGKILL");
      reject(new Error(`Command timeout after ${timeoutMs} ms: ${cmd}`));
    }, timeoutMs);

    p.stdout.on("data", (d) => (stdout += d.toString()));
    p.stderr.on("data", (d) => (stderr += d.toString()));

    p.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });

    p.on("close", (code) => {
      clearTimeout(timer);
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(
          new Error(
            `Command failed (${code}): ${cmd} ${args.join(" ")}\n${stderr}`
          )
        );
      }
    });
  });
}

module.exports = { run };
