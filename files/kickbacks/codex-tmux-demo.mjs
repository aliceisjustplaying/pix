#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import cp from "node:child_process";

const HOME = os.homedir();
const VIBE_DIR = path.join(HOME, ".vibe-ads");
const AD_FILE = path.join(VIBE_DIR, "codex-cli-ad.txt");
const CLICK_QUEUE_FILE = path.join(VIBE_DIR, "codex-clicks.jsonl");
const ACTIVITY_FILE = path.join(VIBE_DIR, "codex-tmux-activity.json");
const LEGACY_STATE_FILE = path.join(VIBE_DIR, "codex-tmux-demo-state.json");
const KEY_STATE_FILE = path.join(VIBE_DIR, "codex-tmux-demo-mouse-key.tmux");
const PID_FILE = path.join(VIBE_DIR, "codex-tmux-demo.pid");
const POLL_MS = Number(process.env.KICKBACKS_CODEX_TMUX_DEMO_POLL_MS || 1000);
const ACTIVE_GRACE_MS = Number(process.env.KICKBACKS_CODEX_TMUX_ACTIVE_GRACE_MS || 4000);
const SHOW_IDLE = process.env.KICKBACKS_CODEX_TMUX_SHOW_IDLE === "1";
const AD_POSITION = process.env.KICKBACKS_CODEX_TMUX_AD_POSITION || "auto";
const USE_OSC8 = process.env.KICKBACKS_CODEX_TMUX_OSC8 === "1";
const AD_TITLE_PREFIX = "kickbacks-codex-ad:";

let restored = false;
const activeUntil = new Map();
let lastActivityWriteAt = 0;

function tmux(args, fallback = "") {
  try {
    return cp.execFileSync("tmux", args, { encoding: "utf8", timeout: 3000 }).replace(/\n$/, "");
  } catch {
    return fallback;
  }
}

function tmuxOk() {
  return !!tmux(["list-sessions", "-F", "#{session_id}"]);
}

function sanitize(value) {
  return String(value || "")
    .replace(/[\x00-\x1f\x7f-\x9f]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 180);
}

function terminalText(value) {
  return sanitize(value);
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

function readAd() {
  try {
    const cached = JSON.parse(fs.readFileSync(path.join(VIBE_DIR, "cli-ad.json"), "utf8"));
    return {
      text: sanitize(cached.adText || fs.readFileSync(AD_FILE, "utf8").split("\n")[0]),
      clickUrl: safeHttpUrl(cached.clickUrl)
    };
  } catch {}
  try {
    return { text: sanitize(fs.readFileSync(AD_FILE, "utf8").split("\n")[0]), clickUrl: "" };
  } catch {}
  return { text: "Your ad here - kickbacks.ai", clickUrl: "https://kickbacks.ai/" };
}

function adLineText(value) {
  return "ad· " + (terminalText(value) || "kickbacks.ai");
}

function truncate(value, max) {
  if (value.length <= max) return value;
  if (max <= 0) return "";
  if (max <= 3) return value.slice(0, max);
  return value.slice(0, max - 3) + "...";
}

function osc8(url, text) {
  return `\x1b]8;;${url}\x1b\\${text}\x1b]8;;\x1b\\`;
}

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function randomUuid() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
  return "local-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2);
}

function queueClick(ad) {
  fs.mkdirSync(VIBE_DIR, { recursive: true });
  const event = {
    ts: Date.now(),
    eventUuid: randomUuid(),
    surface: "codex_overlay",
    adText: ad.text,
    clickUrl: ad.clickUrl
  };
  fs.appendFileSync(CLICK_QUEUE_FILE, JSON.stringify(event) + "\n", { mode: 0o600 });
}

function saveMouseBinding() {
  if (fs.existsSync(KEY_STATE_FILE)) return;
  fs.mkdirSync(VIBE_DIR, { recursive: true });
  fs.writeFileSync(KEY_STATE_FILE, tmux(["list-keys", "-T", "root", "MouseDown1Pane"], "") + "\n", { mode: 0o600 });
}

function installMouseBinding() {
  saveMouseBinding();
  const clickCommand = `${shellQuote(process.execPath)} ${shellQuote(fs.realpathSync(process.argv[1]))} --click`;
  tmux([
    "bind-key",
    "-T",
    "root",
    "MouseDown1Pane",
    "if",
    "-F",
    "-t",
    "=",
    "#{m/r:^kickbacks-codex-ad:,#{pane_title}}",
    `run-shell -b ${shellQuote(clickCommand)}`,
    "send-keys -M"
  ]);
}

function restoreMouseBinding() {
  try {
    const binding = fs.readFileSync(KEY_STATE_FILE, "utf8").trim();
    if (binding) tmux(["source-file", KEY_STATE_FILE]);
    else tmux(["unbind-key", "-T", "root", "MouseDown1Pane"]);
  } catch {}
  try {
    fs.unlinkSync(KEY_STATE_FILE);
  } catch {}
}

function handleClick() {
  const ad = readAd();
  if (!ad.clickUrl) process.exit(0);
  try {
    queueClick(ad);
  } catch {}
  tmux(["set-buffer", "-w", ad.clickUrl]);
  tmux(["display-message", `kickbacks ad link copied: ${ad.clickUrl}`]);
  process.exit(0);
}

function renderAdPane() {
  let exiting = false;

  function draw() {
    const ad = readAd();
    const width = process.stdout.columns || Number(process.env.COLUMNS) || 80;
    const text = truncate(adLineText(ad.text), Math.max(0, width));
    const body = USE_OSC8 && ad.clickUrl ? osc8(ad.clickUrl, text) : text;
    process.stdout.write("\r\x1b[2K" + body);
  }

  function exit() {
    if (exiting) return;
    exiting = true;
    process.stdout.write("\r\x1b[2K\x1b[?25h");
    process.exit(0);
  }

  process.stdout.write("\x1b[?25l");
  draw();
  setInterval(draw, POLL_MS);
  process.on("SIGINT", exit);
  process.on("SIGTERM", exit);
}

function sessionId() {
  return tmux(["display-message", "-p", "#{session_id}"]);
}

function listPanes() {
  return tmux([
    "list-panes",
    "-a",
    "-F",
    "#{pane_id}\t#{session_name}\t#{window_id}\t#{window_height}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}"
  ], "")
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [id, sessionName, windowId, windowHeight, pid, command, title] = line.split("\t");
      return { id, sessionName, windowId, windowHeight: Number(windowHeight), pid, command, title };
    });
}

function codexPanes(panes) {
  return panes.filter((pane) =>
    pane.command === "codex-raw" &&
    !pane.title?.startsWith(AD_TITLE_PREFIX) &&
    codexPaneActive(pane)
  );
}

function adPanes(panes) {
  return panes
    .filter((pane) => pane.title?.startsWith(AD_TITLE_PREFIX))
    .map((pane) => ({ ...pane, targetPane: pane.title.slice(AD_TITLE_PREFIX.length) }));
}

function createAdPane(pane) {
  const command = [
    "KICKBACKS_CODEX_TARGET_PANE=" + shellQuote(pane.id),
    shellQuote(process.execPath),
    shellQuote(fs.realpathSync(process.argv[1])),
    "--pane"
  ].join(" ");
  const args = ["split-window", "-d", "-v", "-l", "1"];
  if (placeAdAbove(pane)) args.push("-b");
  args.push("-t", pane.id, "-P", "-F", "#{pane_id}", command);
  const paneId = tmux(args, "");
  if (!paneId) return;
  tmux(["select-pane", "-t", paneId, "-T", AD_TITLE_PREFIX + pane.id]);
}

function killPane(paneId) {
  tmux(["kill-pane", "-t", paneId]);
}

function minClientHeight(sessionName) {
  const heights = tmux(["list-clients", "-F", "#{client_session}\t#{client_height}"], "")
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [clientSession, height] = line.split("\t");
      return clientSession === sessionName ? Number(height) : 0;
    })
    .filter((height) => height > 0);
  return heights.length ? Math.min(...heights) : 0;
}

function placeAdAbove(pane) {
  if (AD_POSITION === "top") return true;
  if (AD_POSITION === "bottom") return false;
  const clientHeight = minClientHeight(pane.sessionName);
  return clientHeight > 0 && pane.windowHeight > clientHeight;
}

function titleHasSpinner(title) {
  const first = String(title || "").trim().codePointAt(0);
  return typeof first === "number" && first >= 0x2800 && first <= 0x28ff;
}

function paneTextLooksActive(paneId) {
  const text = tmux(["capture-pane", "-p", "-t", paneId, "-S", "-20"], "");
  return /Working \(\d+[smh]|Running|Thinking/.test(text);
}

function codexPaneActive(pane) {
  if (SHOW_IDLE) return true;
  const now = Date.now();
  const active = titleHasSpinner(pane.title) || paneTextLooksActive(pane.id);
  if (active) activeUntil.set(pane.id, now + ACTIVE_GRACE_MS);
  return active || (activeUntil.get(pane.id) || 0) > now;
}

function codexPaneLooksActive(pane) {
  return paneTextLooksActive(pane.id);
}

function writeActivityState(panes) {
  const now = Date.now();
  if (now - lastActivityWriteAt < POLL_MS) return;
  lastActivityWriteAt = now;
  const activePanes = panes
    .filter((pane) =>
      pane.command === "codex-raw" &&
      !pane.title?.startsWith(AD_TITLE_PREFIX) &&
      codexPaneLooksActive(pane)
    )
    .map((pane) => pane.id);
  const active = activePanes.length > 0;
  let previous = {};
  try {
    previous = JSON.parse(fs.readFileSync(ACTIVITY_FILE, "utf8"));
  } catch {}
  const since = active && previous.active === true && Number.isFinite(previous.since) ? previous.since : now;
  fs.mkdirSync(VIBE_DIR, { recursive: true });
  fs.writeFileSync(ACTIVITY_FILE, JSON.stringify({ active, activePanes, ts: now, since }) + "\n", { mode: 0o644 });
}

function syncAdPanes() {
  const panes = listPanes();
  writeActivityState(panes);
  const codexPanesById = new Map(codexPanes(panes).map((pane) => [pane.id, pane]));
  const codex = new Set(codexPanesById.keys());
  const ads = adPanes(panes);
  const advertised = new Set(ads.map((pane) => pane.targetPane));

  for (const ad of ads) {
    if (!codex.has(ad.targetPane)) {
      activeUntil.delete(ad.targetPane);
      killPane(ad.id);
    }
  }

  for (const [targetPane, pane] of codexPanesById) {
    if (!advertised.has(targetPane)) createAdPane(pane);
  }
}

function restore() {
  if (restored) return;
  restored = true;
  restoreMouseBinding();
  try {
    fs.unlinkSync(LEGACY_STATE_FILE);
  } catch {}
  try {
    fs.unlinkSync(PID_FILE);
  } catch {}
  for (const pane of adPanes(listPanes())) {
    killPane(pane.id);
  }
}

if (process.argv.includes("--pane")) {
  renderAdPane();
} else if (process.argv.includes("--click")) {
  handleClick();
} else {
  if (process.argv.includes("--stop")) {
    try {
      const pid = Number(fs.readFileSync(PID_FILE, "utf8").trim());
      if (pid && pid !== process.pid) process.kill(pid, "SIGTERM");
    } catch {}
    restore();
    process.exit(0);
  }

  if (process.argv.includes("--restore")) {
    restore();
    process.exit(0);
  }

  if (!tmuxOk()) {
    console.error("kickbacks-codex-tmux-demo: no tmux server available");
    process.exit(1);
  }

  fs.mkdirSync(VIBE_DIR, { recursive: true });
  installMouseBinding();
  fs.writeFileSync(PID_FILE, String(process.pid) + "\n", { mode: 0o600 });
  setInterval(() => {
    syncAdPanes();
  }, POLL_MS);

  process.on("SIGINT", () => {
    restore();
    process.exit(0);
  });
  process.on("SIGTERM", () => {
    restore();
    process.exit(0);
  });

  console.log("kickbacks-codex-tmux-demo: running; Ctrl-C or --restore removes ad panes and mouse binding");
}
