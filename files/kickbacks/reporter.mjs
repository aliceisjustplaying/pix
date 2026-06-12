import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import cp from "node:child_process";

const BASE = process.env.KICKBACKS_BASE || "https://kickbacks-backend-gmdaqm2c7q-uw.a.run.app";
const EXT_VERSION = "0.3.174";
const POLL_MS = 1000;
const VIEW_TICK_MS = 5000;
const PORTFOLIO_MS = 120000;
const REFRESH_MS = 45 * 60 * 1000;
const HOME = os.homedir();
const AUTH_FILE = path.join(HOME, ".kickbacks", "auth.json");
const VIBE_DIR = path.join(HOME, ".vibe-ads");
const CLI_AD = path.join(VIBE_DIR, "cli-ad.json");
const CODEX_AD = path.join(VIBE_DIR, "codex-cli-ad.txt");
const STATE_FILE = path.join(VIBE_DIR, "reporter-state.json");
const LOG_FILE = path.join(VIBE_DIR, "reporter.log");
const IDLE_STALE_MS = 90000;
const FRESH_ACTIVITY_MS = 4000;
const RERESOLVE_MIN_MS = 15000;

let accessToken = "";
let refreshAt = 0;
let portfolioAt = 0;
let ad = null;
let ccVersion = "unknown";
let viewThresholdMs = 5000;
let showing = false;
let visibleMs = 0;
let lastAccrualMs = 0;
let lastTickMs = 0;
let shownKey = "";
let statuslineThresholdSent = false;
let spinnerThresholdSent = false;
let cliLogPath = "";
let lastReresolveAt = 0;
let firstSeen = Date.now();
let lastTool = "";

function log(message, extra = {}) {
  fs.mkdirSync(VIBE_DIR, { recursive: true });
  const line = JSON.stringify({ ts: new Date().toISOString(), message, ...extra });
  fs.appendFileSync(LOG_FILE, line + "\n");
}

function readJson(file, fallback = {}) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(file, value, mode = 0o644) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  try {
    if (fs.lstatSync(file).isSymbolicLink()) fs.unlinkSync(file);
  } catch {}
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + "\n", { mode });
  try {
    fs.chmodSync(file, mode);
  } catch {}
}

function writeText(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  try {
    if (fs.lstatSync(file).isSymbolicLink()) fs.unlinkSync(file);
  } catch {}
  fs.writeFileSync(file, value, "utf8");
}

function stripControl(value) {
  return String(value || "").replace(/[\x00-\x1f\x7f-\x9f]/g, "");
}

function auth() {
  const value = readJson(AUTH_FILE, {});
  if (!value.clientId) {
    value.clientId = crypto.randomBytes(12).toString("hex");
    writeJson(AUTH_FILE, value, 0o600);
  }
  return value;
}

function detectClaudeVersion() {
  try {
    return cp.execFileSync("claude", ["--version"], { encoding: "utf8", timeout: 3000 }).trim();
  } catch {
    return "unknown";
  }
}

function supportsSpinner(version) {
  const match = /(\d+)\.(\d+)\.(\d+)/.exec(version);
  if (!match) return true;
  const got = match.slice(1).map(Number);
  const floor = [2, 1, 143];
  for (let i = 0; i < 3; i++) {
    if (got[i] !== floor[i]) return got[i] > floor[i];
  }
  return true;
}

async function refreshAccess(force = false) {
  if (!force && accessToken && Date.now() < refreshAt) return true;
  const current = auth();
  if (!current.refresh) {
    log("auth.missing_refresh");
    return false;
  }
  const response = await fetch(BASE + "/v1/auth/refresh", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ refresh_token: current.refresh })
  });
  if (!response.ok) {
    log("auth.refresh_failed", { status: response.status });
    accessToken = "";
    return false;
  }
  const body = await response.json();
  accessToken = body.access_token || "";
  if (body.refresh_token) {
    writeJson(AUTH_FILE, { ...current, refresh: body.refresh_token }, 0o600);
  }
  refreshAt = Date.now() + REFRESH_MS;
  log("auth.refresh_ok");
  return !!accessToken;
}

async function fetchPortfolio(force = false) {
  if (!force && ad && Date.now() < portfolioAt) return ad;
  if (!(await refreshAccess())) return null;
  ccVersion = detectClaudeVersion();
  const response = await fetch(BASE + "/v1/portfolio?claude_code_version=" + encodeURIComponent(ccVersion), {
    headers: { authorization: "Bearer " + accessToken }
  });
  if (!response.ok) {
    log("portfolio.failed", { status: response.status });
    if (response.status === 401 || response.status === 403) await refreshAccess(true);
    return ad;
  }
  const body = await response.json();
  const first = Array.isArray(body.ads) ? body.ads[0] : null;
  if (!first) {
    log("portfolio.empty");
    portfolioAt = Date.now() + 30000;
    return ad;
  }
  viewThresholdMs = Math.max(1000, Number(body.view_threshold_seconds || 5) * 1000);
  ad = {
    adId: String(first.ad_id || ""),
    campaignId: String(first.campaign_id || ""),
    adText: stripControl(first.title_text),
    iconRef: stripControl(first.icon_ref),
    iconUrl: stripControl(first.icon_url),
    clickUrl: stripControl(first.click_url || "https://kickbacks.ai"),
    sessionToken: String(first.session_token || "")
  };
  writeJson(CLI_AD, {
    adText: ad.adText,
    iconRef: ad.iconRef,
    iconUrl: ad.iconUrl,
    clickUrl: ad.clickUrl,
    ts: Date.now()
  }, 0o644);
  writeText(CODEX_AD, ad.adText + "\n");
  portfolioAt = Date.now() + PORTFOLIO_MS;
  log("portfolio.ok", { adId: ad.adId, text: ad.adText });
  return ad;
}

function transcriptEntrypoint(file) {
  try {
    const fd = fs.openSync(file, "r");
    let text;
    try {
      const buffer = Buffer.alloc(16 * 1024);
      const n = fs.readSync(fd, buffer, 0, buffer.length, 0);
      text = buffer.toString("utf8", 0, n);
    } finally {
      fs.closeSync(fd);
    }
    for (const line of text.split("\n")) {
      if (!line) continue;
      try {
        const obj = JSON.parse(line);
        if (typeof obj.entrypoint === "string") return obj.entrypoint;
      } catch {}
    }
    return null;
  } catch {
    return null;
  }
}

function scanTranscripts() {
  const root = path.join(HOME, ".claude", "projects");
  try {
    return fs.readdirSync(root).flatMap((project) => {
      const dir = path.join(root, project);
      try {
        return fs.readdirSync(dir)
          .filter((name) => name.endsWith(".jsonl"))
          .map((name) => {
            const file = path.join(dir, name);
            return { file, mtimeMs: fs.statSync(file).mtimeMs };
          });
      } catch {
        return [];
      }
    }).sort((a, b) => b.mtimeMs - a.mtimeMs);
  } catch {
    return [];
  }
}

function locateClaudeCliLog() {
  if (process.env.KICKBACKS_CLI_LOG && fs.existsSync(process.env.KICKBACKS_CLI_LOG)) {
    return process.env.KICKBACKS_CLI_LOG;
  }
  let newestUntagged = "";
  for (const candidate of scanTranscripts().slice(0, 20)) {
    const tag = transcriptEntrypoint(candidate.file);
    if (tag === "cli") return candidate.file;
    if (tag === null && !newestUntagged) newestUntagged = candidate.file;
  }
  return newestUntagged;
}

function currentCliLogPath() {
  try {
    if (cliLogPath && fs.existsSync(cliLogPath)) {
      const age = Date.now() - fs.statSync(cliLogPath).mtimeMs;
      if (age <= IDLE_STALE_MS) return cliLogPath;
      if (Date.now() - lastReresolveAt < RERESOLVE_MIN_MS) return cliLogPath;
      lastReresolveAt = Date.now();
    }
    const next = locateClaudeCliLog();
    if (next && next !== cliLogPath) {
      cliLogPath = next;
      lastTool = "";
      firstSeen = Date.now();
    }
    return cliLogPath;
  } catch {
    return cliLogPath;
  }
}

function activityAgeMs() {
  try {
    const file = currentCliLogPath();
    if (!file || !fs.existsSync(file)) return null;
    return Math.max(0, Date.now() - fs.statSync(file).mtimeMs);
  } catch {
    return null;
  }
}

function currentActivity() {
  try {
    const file = currentCliLogPath();
    if (!file || !fs.existsSync(file)) return null;
    const stat = fs.statSync(file);
    const want = Math.min(stat.size, 128 * 1024);
    if (want === 0) return null;
    const fd = fs.openSync(file, "r");
    let text;
    try {
      const buffer = Buffer.alloc(want);
      fs.readSync(fd, buffer, 0, want, stat.size - want);
      text = buffer.toString("utf8");
    } finally {
      fs.closeSync(fd);
    }
    const lines = text.split("\n");
    if (want < stat.size) lines.shift();
    let tool = "";
    let done = null;
    let pendingUserAfterAssistant = false;
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i];
      if (!line) continue;
      let obj;
      try {
        obj = JSON.parse(line);
      } catch {
        continue;
      }
      const msg = obj.message;
      if (done === null && obj.type === "user") {
        pendingUserAfterAssistant = true;
        continue;
      }
      if (obj.type === "assistant" && msg) {
        if (done === null) {
          if (pendingUserAfterAssistant) done = false;
          else {
            const stopReason = msg.stop_reason;
            done = !!stopReason && stopReason !== "tool_use";
          }
        }
        if (!tool && Array.isArray(msg.content)) {
          for (const block of msg.content) {
            if (block && block.type === "tool_use" && typeof block.name === "string") {
              tool = block.name;
              break;
            }
          }
        }
      }
      if (tool && done !== null) break;
    }
    if (done === null && pendingUserAfterAssistant) done = false;
    if (!tool && done === null) return null;
    if (tool && tool !== lastTool) {
      lastTool = tool;
      firstSeen = Date.now();
    }
    return {
      tool,
      done: done === true || Date.now() - stat.mtimeMs > IDLE_STALE_MS,
      elapsedMs: Date.now() - firstSeen
    };
  } catch {
    return null;
  }
}

function hasClaudeCliProcess() {
  try {
    const lines = cp.execFileSync("ps", ["-u", String(process.getuid()), "-o", "pid=,comm=,args="], {
      encoding: "utf8",
      timeout: 3000
    }).split("\n");
    return lines.some((line) =>
      (line.includes(" claude ") || line.includes(" .claude-unwrapp ")) &&
      !line.includes("kickbacks-reporter")
    );
  } catch {
    return false;
  }
}

function visibleSurfaces() {
  const activity = currentActivity();
  const age = activityAgeMs();
  const fresh = age !== null && age <= FRESH_ACTIVITY_MS;
  const active = activity ? !activity.done : fresh;
  const claude = active && hasClaudeCliProcess();
  return { claude, any: claude };
}

function state() {
  return readJson(STATE_FILE, { sent: {} });
}

function saveState(value) {
  writeJson(STATE_FILE, value, 0o644);
}

async function sendMetric(event, surface, visible = undefined) {
  if (!ad || !accessToken) return false;
  const current = auth();
  const eventUuid = crypto.randomUUID();
  const body = {
    event_type: event,
    ad_id: ad.adId,
    campaign_id: ad.campaignId,
    client_id: current.clientId,
    ts: new Date().toISOString(),
    claude_code_version: ccVersion,
    extension_version: EXT_VERSION,
    nonce: eventUuid,
    surface,
    session_token: ad.sessionToken,
    ext: { os: process.platform, arch: process.arch, os_version: os.release(), editor: "kickbacks-local-reporter" }
  };
  if (typeof visible === "number") body.visible_ms = Math.max(0, Math.floor(visible));
  if (event === "impression_viewable" || event === "view_threshold_met") {
    body.viewable = true;
    body.view_pct = 100;
  }
  if (event === "view_threshold_met") body.view_ms = Math.max(0, Math.floor(visible || viewThresholdMs));

  const response = await fetch(BASE + "/v1/metrics", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + accessToken,
      "X-Kickbacks-Corr": "local." + event + "." + ad.adId,
      "X-Vibe-Corr": "local." + event + "." + ad.adId
    },
    body: JSON.stringify(body)
  });
  log("metric." + event, { surface, status: response.status, visibleMs: body.visible_ms ?? null });
  return response.ok;
}

async function beginExposure(surfaces) {
  const key = ad.adId + ":" + ad.sessionToken;
  shownKey = key;
  showing = true;
  visibleMs = 0;
  lastAccrualMs = Date.now();
  lastTickMs = 0;
  statuslineThresholdSent = false;
  spinnerThresholdSent = false;

  const current = state();
  current.sent ||= {};
  if (!current.sent[key]) {
    current.sent[key] = { at: new Date().toISOString(), statusline: false, spinner: false };
  }
  if (!current.sent[key].statusline && surfaces.any) {
    await sendMetric("impression_rendered", "statusline");
    await sendMetric("impression_viewable", "statusline");
    current.sent[key].statusline = true;
  }
  if (!current.sent[key].spinner && surfaces.claude && supportsSpinner(ccVersion)) {
    await sendMetric("impression_rendered", "spinner");
    await sendMetric("impression_viewable", "spinner");
    current.sent[key].spinner = true;
  }
  saveState(current);
}

async function tickExposure(surfaces) {
  const now = Date.now();
  if (showing) {
    visibleMs += Math.min(now - lastAccrualMs, 2 * POLL_MS);
  }
  lastAccrualMs = now;
  if (now - lastTickMs >= VIEW_TICK_MS) {
    lastTickMs = now;
    if (surfaces.any) await sendMetric("view_tick", "statusline", visibleMs);
    if (surfaces.claude && supportsSpinner(ccVersion)) await sendMetric("view_tick", "spinner", visibleMs);
  }
  if (!statuslineThresholdSent && surfaces.any && visibleMs >= viewThresholdMs) {
    statuslineThresholdSent = true;
    await sendMetric("view_threshold_met", "statusline", visibleMs);
  }
  if (!spinnerThresholdSent && surfaces.claude && supportsSpinner(ccVersion) && visibleMs >= viewThresholdMs) {
    spinnerThresholdSent = true;
    await sendMetric("view_threshold_met", "spinner", visibleMs);
  }
}

async function loop() {
  await fetchPortfolio(true);
  let busy = false;
  setInterval(async () => {
    if (busy) return;
    busy = true;
    try {
      await fetchPortfolio();
      const surfaces = visibleSurfaces();
      if (!ad || !surfaces.any) {
        showing = false;
        return;
      }
      const key = ad.adId + ":" + ad.sessionToken;
      if (!showing || shownKey !== key) await beginExposure(surfaces);
      else await tickExposure(surfaces);
    } catch (error) {
      log("loop.error", { error: error instanceof Error ? error.message : String(error) });
    } finally {
      busy = false;
    }
  }, POLL_MS);
}

process.on("unhandledRejection", (error) => {
  log("unhandled", { error: error instanceof Error ? error.message : String(error) });
});

log("start");
loop();
