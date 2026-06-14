#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import cp from "node:child_process";

const HOME = os.homedir();
const VIBE_DIR = path.join(HOME, ".vibe-ads");
const AD_FILE = path.join(VIBE_DIR, "codex-cli-ad.txt");
const LEGACY_STATE_FILE = path.join(VIBE_DIR, "codex-tmux-demo-state.json");
const KEY_STATE_FILE = path.join(VIBE_DIR, "codex-tmux-demo-mouse-key.tmux");
const PID_FILE = path.join(VIBE_DIR, "codex-tmux-demo.pid");
const POLL_MS = Number(process.env.KICKBACKS_CODEX_TMUX_DEMO_POLL_MS || 1000);
const AD_TITLE_PREFIX = "kickbacks-codex-ad:";

let restored = false;

function tmux(args, fallback = "") {
  try {
    return cp.execFileSync("tmux", args, { encoding: "utf8", timeout: 3000 }).replace(/\n$/, "");
  } catch {
    return fallback;
  }
}

function tmuxOk() {
  return !!process.env.TMUX && tmux(["display-message", "-p", "#{session_id}"]);
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
    "#{m/r:^kickbacks-codex-ad:,#{pane_title}}",
    `run-shell -b ${shellQuote(clickCommand)}`,
    "select-pane -t = \\; send-keys -M"
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
  tmux(["set-buffer", "-w", ad.clickUrl]);
  tmux(["display-message", `kickbacks ad link copied: ${ad.clickUrl}`]);
  process.exit(0);
}

function renderAdPane() {
  let exiting = false;

  function draw() {
    const ad = readAd();
    const width = process.stdout.columns || Number(process.env.COLUMNS) || 80;
    const prefix = "\x1b[7m ad-demo \x1b[0m ";
    const prefixWidth = 10;
    const text = truncate(terminalText(ad.text) || "kickbacks.ai", Math.max(0, width - prefixWidth));
    const body = ad.clickUrl ? osc8(ad.clickUrl, text) : text;
    process.stdout.write("\r\x1b[2K" + prefix + body);
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
  return tmux(["list-panes", "-s", "-F", "#{pane_id}\t#{window_id}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}"], "")
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [id, windowId, pid, command, title] = line.split("\t");
      return { id, windowId, pid, command, title };
    });
}

function codexPanes(panes) {
  return panes.filter((pane) => pane.command === "codex-raw" && !pane.title?.startsWith(AD_TITLE_PREFIX));
}

function adPanes(panes) {
  return panes
    .filter((pane) => pane.title?.startsWith(AD_TITLE_PREFIX))
    .map((pane) => ({ ...pane, targetPane: pane.title.slice(AD_TITLE_PREFIX.length) }));
}

function createAdPane(targetPane) {
  const command = [
    "KICKBACKS_CODEX_TARGET_PANE=" + shellQuote(targetPane),
    shellQuote(process.execPath),
    shellQuote(fs.realpathSync(process.argv[1])),
    "--pane"
  ].join(" ");
  const paneId = tmux(["split-window", "-d", "-v", "-l", "1", "-t", targetPane, "-P", "-F", "#{pane_id}", command], "");
  if (!paneId) return;
  tmux(["select-pane", "-t", paneId, "-T", AD_TITLE_PREFIX + targetPane]);
}

function killPane(paneId) {
  tmux(["kill-pane", "-t", paneId]);
}

function syncAdPanes() {
  const panes = listPanes();
  const codex = new Set(codexPanes(panes).map((pane) => pane.id));
  const ads = adPanes(panes);
  const advertised = new Set(ads.map((pane) => pane.targetPane));

  for (const ad of ads) {
    if (!codex.has(ad.targetPane)) killPane(ad.id);
  }

  for (const targetPane of codex) {
    if (!advertised.has(targetPane)) createAdPane(targetPane);
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
    console.error("kickbacks-codex-tmux-demo: run inside tmux");
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
