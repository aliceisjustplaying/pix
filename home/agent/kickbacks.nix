{ config, lib, pkgs, ... }:

let
  home = config.home.homeDirectory;
  adText = "Your ad here - kickbacks.ai";
  clickUrl = "https://kickbacks.ai";
  statuslineScript = pkgs.runCommand "kickbacks-statusline.mjs" { } ''
    substitute ${pkgs.kickbacks-ai}/share/kickbacks-ai/extension/dist/adapters/claude-cli/statusline.asset.mjs "$out" \
      --replace-fail "__VIBE_ADS_CLI_AD_PATH__" ${lib.escapeShellArg (builtins.toJSON "${home}/.vibe-ads/cli-ad.json")} \
      --replace-fail "__VIBE_ADS_CLI_PREV_PATH__" ${lib.escapeShellArg (builtins.toJSON "${home}/.vibe-ads/cli-prev-statusline.json")} \
      --replace-fail "__VIBE_ADS_FRESH_MS__" "3153600000000" \
      --replace-fail "__VIBE_ADS_SCRIPT_NAME__" ${lib.escapeShellArg (builtins.toJSON "vibe-ads-statusline.mjs")} \
      --replace-fail "__VIBE_ADS_CHAIN_TIMEOUT_MS__" "5000"
  '';
in
{
  home.file = {
    ".vibe-ads/vibe-ads-statusline.mjs".source = statuslineScript;
    ".vibe-ads/config.json".text = builtins.toJSON {
      backendBaseUrl = "";
      updateBaseUrl = "https://invalid.example.invalid";
      localVsixPath = "";
      updatePollIntervalMs = 2147483647;
      debugMode = false;
    };
    ".local/bin/codex" = {
      executable = true;
      text = ''
        #!/bin/sh
        # ===== VIBE-ADS-CODEX-CLI =====
        AD_FILE="$HOME/.vibe-ads/codex-cli-ad.txt"
        AD_TEXT=${lib.escapeShellArg adText}
        if [ -r "$AD_FILE" ]; then
          AD_TEXT=$(head -n 1 "$AD_FILE" 2>/dev/null || printf '%s\n' "$AD_TEXT")
        fi
        printf '\n  [ad]  %s\n\n' "$AD_TEXT"
        exec /etc/profiles/per-user/agent/bin/codex "$@"
      '';
    };
    ".local/bin/kickbacks-login" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        exec ${pkgs.nodejs_24}/bin/node <<'NODE'
        const fs = require("node:fs");
        const os = require("node:os");
        const path = require("node:path");
        const crypto = require("node:crypto");
        const cp = require("node:child_process");

        const base = process.env.KICKBACKS_BASE || "https://kickbacks-backend-gmdaqm2c7q-uw.a.run.app";
        const home = os.homedir();
        const kickbacksDir = path.join(home, ".kickbacks");
        const vibeDir = path.join(home, ".vibe-ads");
        const authFile = path.join(kickbacksDir, "auth.json");
        fs.mkdirSync(kickbacksDir, { recursive: true, mode: 0o700 });
        fs.mkdirSync(vibeDir, { recursive: true });

        function readJson(file) {
          try { return JSON.parse(fs.readFileSync(file, "utf8")); } catch { return {}; }
        }

        function writeJson(file, value, mode = 0o600) {
          try {
            if (fs.lstatSync(file).isSymbolicLink()) fs.unlinkSync(file);
          } catch {}
          fs.writeFileSync(file, JSON.stringify(value, null, 2) + "\n", { mode });
          try { fs.chmodSync(file, mode); } catch {}
        }

        function writeText(file, value) {
          try {
            if (fs.lstatSync(file).isSymbolicLink()) fs.unlinkSync(file);
          } catch {}
          fs.writeFileSync(file, value, "utf8");
        }

        function clientId() {
          const auth = readJson(authFile);
          if (typeof auth.clientId === "string" && auth.clientId) return auth.clientId;
          const id = crypto.randomBytes(12).toString("hex");
          writeJson(authFile, { ...auth, clientId: id });
          return id;
        }

        async function refreshAd(access) {
          let version = "unknown";
          try {
            version = cp.execFileSync("claude", ["--version"], { encoding: "utf8", timeout: 3000 }).trim();
          } catch {}
          const url = base + "/v1/portfolio?claude_code_version=" + encodeURIComponent(version);
          const r = await fetch(url, { headers: { authorization: "Bearer " + access } });
          if (!r.ok) throw new Error("portfolio " + r.status);
          const body = await r.json();
          const ad = Array.isArray(body.ads) ? body.ads[0] : null;
          if (!ad) return false;
          const text = String(ad.title_text || "Your ad here - kickbacks.ai").replace(/[\x00-\x1f\x7f-\x9f]/g, "");
          const clickUrl = String(ad.click_url || "https://kickbacks.ai").replace(/[\x00-\x1f\x7f-\x9f]/g, "");
          writeJson(path.join(vibeDir, "cli-ad.json"), {
            adText: text,
            iconRef: String(ad.icon_ref || ""),
            iconUrl: String(ad.icon_url || ""),
            clickUrl,
            ts: Date.now()
          }, 0o644);
          writeText(path.join(vibeDir, "codex-cli-ad.txt"), text + "\n");
          return true;
        }

        async function main() {
          const id = clientId();
          const start = await fetch(base + "/v1/auth/extension/start", { redirect: "manual" });
          const loc = start.headers.get("location");
          if (!loc) throw new Error("auth start returned no Location header");
          const state = new URL(loc).searchParams.get("state");
          if (!state) throw new Error("auth start returned no state");

          console.log("Open this URL to sign in:");
          console.log(loc);
          console.log("");
          console.log("waiting for browser login...");

          for (let i = 0; i < 120; i++) {
            const r = await fetch(base + "/v1/auth/extension/poll?state=" + encodeURIComponent(state));
            const j = await r.json().catch(() => ({}));
            if (j.access_token) {
              const auth = readJson(authFile);
              writeJson(authFile, {
                ...auth,
                clientId: id,
                refresh: j.refresh_token || auth.refresh || ""
              });
              let adOk = false;
              try { adOk = await refreshAd(j.access_token); } catch (e) { console.error("signed in, but ad refresh failed: " + e.message); }
              console.log(adOk ? "signed in; refreshed current ad" : "signed in");
              return;
            }
            await new Promise((resolve) => setTimeout(resolve, 1500));
          }
          throw new Error("sign-in timed out");
        }

        main().catch((e) => {
          console.error("kickbacks-login: " + e.message);
          process.exit(1);
        });
        NODE
      '';
    };
    ".local/bin/kickbacks-reporter" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        exec ${pkgs.nodejs_24}/bin/node ${../../files/kickbacks/reporter.mjs}
      '';
    };
    ".local/bin/kickbacks-codex-tmux-demo" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        exec ${pkgs.nodejs_24}/bin/node ${../../files/kickbacks/codex-tmux-demo.mjs} "$@"
      '';
    };
  };

  systemd.user.services.kickbacks-reporter = {
    Unit = {
      Description = "Kickbacks local terminal reporter";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${home}/.local/bin/kickbacks-reporter";
      Restart = "always";
      RestartSec = "10s";
      Environment = [
        "PATH=${home}/.local/bin:/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.activation.kickbacksClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude" "$HOME/.vibe-ads"
    if [ ! -e "$settings" ]; then
      printf '{\n}\n' > "$settings"
    fi

    if [ -L "$HOME/.vibe-ads/cli-ad.json" ]; then
      rm -f "$HOME/.vibe-ads/cli-ad.json"
    fi
    if [ ! -e "$HOME/.vibe-ads/cli-ad.json" ]; then
      printf '%s\n' '{"adText":"Your ad here - kickbacks.ai","iconRef":"","iconUrl":"","clickUrl":"https://kickbacks.ai","ts":4102444800000}' > "$HOME/.vibe-ads/cli-ad.json"
    fi

    if [ -L "$HOME/.vibe-ads/codex-cli-ad.txt" ]; then
      rm -f "$HOME/.vibe-ads/codex-cli-ad.txt"
    fi
    if [ ! -e "$HOME/.vibe-ads/codex-cli-ad.txt" ]; then
      printf '%s\n' ${lib.escapeShellArg adText} > "$HOME/.vibe-ads/codex-cli-ad.txt"
    fi

    if ${pkgs.jq}/bin/jq -e '.statusLine.type == "command" and (.statusLine.command | contains("vibe-ads-statusline.mjs") | not)' "$settings" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq '{statusLine: .statusLine}' "$settings" > "$HOME/.vibe-ads/cli-prev-statusline.json"
    fi

    tmp="$(mktemp)"
    ${pkgs.jq}/bin/jq \
      --arg cmd "node \"$HOME/.vibe-ads/vibe-ads-statusline.mjs\"" \
      --arg verb ${lib.escapeShellArg adText} \
      '.statusLine = {type: "command", command: $cmd, padding: 0} | .spinnerVerbs = {mode: "replace", verbs: [$verb]}' \
      "$settings" > "$tmp"
    cat "$tmp" > "$settings"
    rm -f "$tmp"
  '';
}
