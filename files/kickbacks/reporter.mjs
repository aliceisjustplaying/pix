import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import cp from "node:child_process";

const BASE = process.env.KICKBACKS_BASE || "https://kickbacks-backend-gmdaqm2c7q-uw.a.run.app";
const EXT_VERSION = "0.3.177";
const POLL_MS = 1000;
const VIEW_TICK_MS = 5000;
const PORTFOLIO_MS = 60000;
const REFRESH_MS = 45 * 60 * 1000;
const AUTH_REJECT_BREAK_N = 3;
const AUTH_REJECT_SUPPRESS_MS = 20000;
const CLICK_THRESHOLD_MS = 15000;
const CLICK_EVENT_MAX_AGE_MS = 30000;
const HOME = os.homedir();
const TMUX_ENV = {
  ...process.env,
  TMUX_TMPDIR: process.env.TMUX_TMPDIR || process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`
};
const AUTH_FILE = path.join(HOME, ".kickbacks", "auth.json");
const VIBE_DIR = path.join(HOME, ".vibe-ads");
const CLI_AD = path.join(VIBE_DIR, "cli-ad.json");
const CODEX_AD = path.join(VIBE_DIR, "codex-cli-ad.txt");
const CODEX_CLICK_QUEUE = path.join(VIBE_DIR, "codex-clicks.jsonl");
const CODEX_ACTIVITY_FILE = path.join(VIBE_DIR, "codex-tmux-activity.json");
const STATE_FILE = path.join(VIBE_DIR, "reporter-state.json");
const LOG_FILE = path.join(VIBE_DIR, "reporter.log");
const CODEX_TMUX_AD_TITLE_PREFIX = "kickbacks-codex-ad:";
const IDLE_STALE_MS = 90000;
const FRESH_ACTIVITY_MS = 4000;
const CODEX_ACTIVITY_STALE_MS = 3000;
const RERESOLVE_MIN_MS = 15000;

let accessToken = "";
let refreshInFlight = null;
let refreshAt = 0;
let portfolioAt = 0;
let ad = null;
let ccVersion = "unknown";
let showing = false;
let visibleMs = 0;
let lastAccrualMs = 0;
let lastTickMs = 0;
let shownAtMs = 0;
let shownKey = "";
let cliLogPath = "";
let lastReresolveAt = 0;
let firstSeen = Date.now();
let lastTool = "";
let consecutiveAuthRejects = 0;
let suppressedUntil = 0;

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

function normalizeAdText(value) {
  return stripControl(value).replace(/\s+/g, " ").trim().slice(0, 180);
}

function safeHttpUrl(value) {
  try {
    const url = new URL(String(value || ""));
    if (url.protocol !== "https:" && url.protocol !== "http:") return "";
    return url.toString();
  } catch {
    return "";
  }
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
  if (refreshInFlight) return refreshInFlight;
  const promise = refreshAccessInner(force);
  refreshInFlight = promise;
  try {
    return await promise;
  } finally {
    if (refreshInFlight === promise) refreshInFlight = null;
  }
}

async function refreshAccessInner(force = false) {
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

function hasVisibleCodexTmuxAdPane() {
  try {
    const lines = cp.execFileSync("tmux", [
      "list-panes",
      "-a",
      "-F",
      "#{session_attached}\t#{window_active}\t#{pane_title}"
    ], { encoding: "utf8", timeout: 3000, env: TMUX_ENV }).split("\n");
    return lines.some((line) => {
      const [attached, activeWindow, title] = line.split("\t");
      return Number(attached) > 0 &&
        activeWindow === "1" &&
        String(title || "").startsWith(CODEX_TMUX_AD_TITLE_PREFIX);
    });
  } catch {
    return false;
  }
}

function codexTmuxActive() {
  try {
    const value = readJson(CODEX_ACTIVITY_FILE, {});
    return value.active === true &&
      Number.isFinite(value.ts) &&
      Date.now() - value.ts <= CODEX_ACTIVITY_STALE_MS;
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
  const codexTmux = hasVisibleCodexTmuxAdPane();
  const codexTmuxBillable = codexTmux && codexTmuxActive();
  return { claude, codexTmux, codexTmuxBillable, any: claude || codexTmux };
}

function state() {
  return readJson(STATE_FILE, { sent: {} });
}

function saveState(value) {
  writeJson(STATE_FILE, value, 0o644);
}

async function sendMetric(event, surface, visible = undefined, includeSessionToken = true) {
  if (!ad || !accessToken) return null;
  const current = auth();
  const eventUuid = crypto.randomUUID();
  return sendMetricWithNonce(event, surface, eventUuid, visible, includeSessionToken, current.clientId);
}

async function sendMetricWithNonce(event, surface, eventUuid, visible = undefined, includeSessionToken = true, clientId = auth().clientId) {
  if (!ad || !accessToken) return null;
  const body = {
    event_type: event,
    ad_id: ad.adId,
    campaign_id: ad.campaignId,
    client_id: clientId,
    ts: new Date().toISOString(),
    claude_code_version: ccVersion,
    extension_version: EXT_VERSION,
    nonce: eventUuid,
    surface,
    ext: { os: process.platform, arch: process.arch, os_version: os.release(), editor: "kickbacks-local-reporter" }
  };
  if (includeSessionToken && ad.sessionToken) body.session_token = ad.sessionToken;
  if (typeof visible === "number") body.visible_ms = Math.max(0, Math.floor(visible));
  if (event === "impression_viewable") {
    body.viewable = true;
    body.view_pct = 100;
  }

  try {
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
    if (response.status === 401 || response.status === 403) void refreshAccess(true);
    return response.status;
  } catch (error) {
    log("metric.send_error", { event, error: error instanceof Error ? error.message : String(error) });
    return null;
  }
}

async function beginExposure(surfaces) {
  const key = ad.adId;
  shownKey = key;
  showing = true;
  visibleMs = 0;
  lastAccrualMs = Date.now();
  lastTickMs = 0;
  shownAtMs = Date.now();
  consecutiveAuthRejects = 0;

  const current = state();
  current.sent ||= {};
  if (!current.sent[key]) {
    current.sent[key] = { at: new Date().toISOString(), statusline: false, spinner: false, codexOverlay: false };
  }
  if (!current.sent[key].statusline && surfaces.claude) {
    await sendMetric("impression_rendered", "statusline", undefined, false);
    await sendMetric("impression_viewable", "statusline");
    current.sent[key].statusline = true;
  }
  if (!current.sent[key].spinner && surfaces.claude && supportsSpinner(ccVersion)) {
    await sendMetric("impression_rendered", "spinner", undefined, false);
    await sendMetric("impression_viewable", "spinner");
    current.sent[key].spinner = true;
  }
  if (!current.sent[key].codexOverlay && surfaces.codexTmux) {
    await sendMetric("impression_rendered", "codex_overlay", undefined, false);
    await sendMetric("impression_viewable", "codex_overlay");
    current.sent[key].codexOverlay = true;
  }
  saveState(current);
}

function drainCodexClickQueue() {
  const batch = CODEX_CLICK_QUEUE + ".processing." + process.pid + "." + Date.now();
  try {
    fs.renameSync(CODEX_CLICK_QUEUE, batch);
  } catch {
    return [];
  }
  try {
    return fs.readFileSync(batch, "utf8")
      .split("\n")
      .filter(Boolean)
      .flatMap((line) => {
        try {
          const event = JSON.parse(line);
          return event && typeof event === "object" ? [event] : [];
        } catch {
          log("click.drop_malformed");
          return [];
        }
      });
  } finally {
    try {
      fs.unlinkSync(batch);
    } catch {}
  }
}

function codexClickMatchesCurrentAd(click) {
  return normalizeAdText(click.adText) === normalizeAdText(ad?.adText) &&
    safeHttpUrl(click.clickUrl) === safeHttpUrl(ad?.clickUrl);
}

async function processCodexClicks(surfaces) {
  const clicks = drainCodexClickQueue();
  for (const click of clicks) {
    const ts = Number(click.ts);
    const ageMs = Date.now() - ts;
    const eventUuid = typeof click.eventUuid === "string" && click.eventUuid ? click.eventUuid : crypto.randomUUID();
    if (click.surface !== "codex_overlay") {
      log("click.drop_surface", { surface: String(click.surface || "") });
      continue;
    }
    if (!Number.isFinite(ts) || ageMs < 0 || ageMs > CLICK_EVENT_MAX_AGE_MS) {
      log("click.drop_stale", { ageMs: Number.isFinite(ageMs) ? ageMs : null });
      continue;
    }
    if (!ad || !showing || shownKey !== ad.adId || !surfaces.codexTmux || ts < shownAtMs) {
      log("click.drop_not_visible", { adId: ad?.adId || "", visibleMs });
      continue;
    }
    if (!codexClickMatchesCurrentAd(click)) {
      log("click.drop_ad_mismatch", { adId: ad.adId });
      continue;
    }
    if (visibleMs < CLICK_THRESHOLD_MS) {
      log("click.early", { adId: ad.adId, visibleMs, thresholdMs: CLICK_THRESHOLD_MS, eventUuid });
      continue;
    }
    await sendMetricWithNonce("click", "codex_overlay", eventUuid);
  }
}

async function tickExposure(surfaces) {
  const now = Date.now();
  const billable = surfaces.claude || surfaces.codexTmuxBillable;
  if (showing && billable) {
    visibleMs += Math.min(now - lastAccrualMs, 2 * POLL_MS);
  }
  lastAccrualMs = now;
  if (now - lastTickMs >= VIEW_TICK_MS) {
    lastTickMs = now;
    if (surfaces.claude) {
      const status = await sendMetric("view_tick", "statusline", visibleMs);
      if (status === 401 || status === 403) {
        consecutiveAuthRejects++;
        if (consecutiveAuthRejects >= AUTH_REJECT_BREAK_N) {
          showing = false;
          suppressedUntil = Date.now() + AUTH_REJECT_SUPPRESS_MS;
          log("metric.auth_reject_break", { adId: ad.adId });
        }
      } else if (status !== null) {
        consecutiveAuthRejects = 0;
      }
    }
    if (surfaces.codexTmuxBillable) {
      const status = await sendMetric("view_tick", "codex_overlay", visibleMs);
      if (status === 401 || status === 403) {
        consecutiveAuthRejects++;
        if (consecutiveAuthRejects >= AUTH_REJECT_BREAK_N) {
          showing = false;
          suppressedUntil = Date.now() + AUTH_REJECT_SUPPRESS_MS;
          log("metric.auth_reject_break", { adId: ad.adId });
        }
      } else if (status !== null) {
        consecutiveAuthRejects = 0;
      }
    }
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
      if (Date.now() < suppressedUntil) {
        showing = false;
        return;
      }
      const key = ad.adId;
      if (!showing || shownKey !== key) await beginExposure(surfaces);
      else await tickExposure(surfaces);
      if (showing && shownKey === key) await processCodexClicks(surfaces);
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
