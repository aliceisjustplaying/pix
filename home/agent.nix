{ config, pkgs, ... }:
let
  lib = pkgs.lib;
  home = config.home.homeDirectory;
  workspaceSrc = "/workspace/src";
  tmpl = import ../lib/template.nix;

  # Render a script from files/bin/<name>.sh. Pass replacements for the
  # @placeholder@ tokens the file uses (replaceVars errors on unused vars).
  binSrc = name: replacements:
    pkgs.replaceVars (../files/bin + "/${name}.sh") replacements;

  # Files with no placeholders; included verbatim.
  binStatic = name: ../files/bin + "/${name}.sh";

  binFiles = {
    host-result = binStatic "host-result";
    rebuild = binStatic "rebuild";
    update = binStatic "update";
    rollback = binStatic "rollback";
    verify-deploy = binSrc "verify-deploy" { inherit workspaceSrc; };
    nfu = binStatic "nfu";
    dependency-freshness = binStatic "dependency-freshness";
    piclaw-restart = binStatic "piclaw-restart";
    piclaw-status = binStatic "piclaw-status";
    piclaw-logs = binStatic "piclaw-logs";
    backup = binStatic "backup";
    hermes = binStatic "hermes";
    amp-login-proxy = binStatic "amp-login-proxy";
    amp-login-upstream = binStatic "amp-login-upstream";
  };

  proxyApiKey = "CLI_PROXY_API_KEY";
  proxyBaseUrl = "http://127.0.0.1:8317";
  proxyOpenAIBaseUrl = "${proxyBaseUrl}/v1";

  openAIModels =
    let
      models = [ "gpt-5.4" "gpt-5.5" ];
      efforts = [ "none" "low" "medium" "high" "xhigh" ];
      speeds = [ "standard" "fast" ];
      titleEffort = effort:
        if effort == "xhigh" then "XHigh" else lib.toUpper (lib.substring 0 1 effort) + lib.substring 1 (-1) effort;
      modelFor = model: effort:
        if effort == "none" then model else "${model}(${effort})";
      mkModel = model: effort: speed: {
        model = modelFor model effort;
        id = "custom:${lib.replaceStrings [ "." ] [ "-" ] (lib.toUpper model)}-${titleEffort effort}-${lib.toUpper speed}-ChatGPT-Pro";
        baseUrl = proxyOpenAIBaseUrl;
        apiKey = proxyApiKey;
        displayName = "${lib.toUpper model} ${titleEffort effort} ${lib.toUpper speed} [ChatGPT Pro OAuth]";
        noImageSupport = false;
        provider = "openai";
      } // lib.optionalAttrs (speed == "fast") {
        extraArgs = {
          service_tier = "priority";
        };
      };
    in lib.concatLists (map
      (model: lib.concatLists (map
        (effort: map (speed: mkModel model effort speed) speeds)
        efforts))
      models);

  claudeModels =
    let
      models = [
        {
          id = "claude-opus-4-5-20251101";
          name = "Claude Opus 4.5";
        }
        {
          id = "claude-opus-4-6";
          name = "Claude Opus 4.6";
        }
        {
          id = "claude-opus-4-7";
          name = "Claude Opus 4.7";
        }
      ];
      efforts = [ "low" "medium" "high" "xhigh" "max" "auto" ];
      titleEffort = effort:
        if effort == "xhigh" then "XHigh" else lib.toUpper (lib.substring 0 1 effort) + lib.substring 1 (-1) effort;
      mkModel = model: effort: {
        model = model.id;
        id = "custom:${model.id}-${effort}-OAuth";
        baseUrl = proxyBaseUrl;
        apiKey = proxyApiKey;
        displayName = "${model.name} ${titleEffort effort} [OAuth]";
        noImageSupport = false;
        provider = "anthropic";
      } // {
        extraArgs = {
          thinking = {
            type = "adaptive";
          };
          output_config = {
            inherit effort;
          };
          max_tokens = 64000;
        };
      };
    in lib.concatLists (map
      (model: map (effort: mkModel model effort) efforts)
      models);

  customModels = lib.imap0 (index: model: model // { inherit index; }) (openAIModels ++ claudeModels);
  factorySettings = tmpl ../files/factory/settings.json {
    customModels = builtins.toJSON customModels;
  };
  ampSettings = tmpl ../files/amp/settings.json {
    inherit proxyBaseUrl;
  };
  cliProxyApiConfig = tmpl ../files/cli-proxy-api/config.yaml {
    inherit proxyApiKey;
  };
in {
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    EDITOR = "vim";
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    PAGER = "less -FR";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  home.sessionPath = [
    "${home}/.local/bin"
    "${home}/.bun/bin"
    "${home}/.nix-profile/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];

  home.packages = with pkgs; [
    bun
    nodejs_24
    gh
    jujutsu
    portless
    hcloud
    ncdu
    gdu
    diskus
    go_1_26
    ffmpeg
    yt-dlp
    sqlite
    tsshd
    zellij
    droid
    amp-code
    cli-proxy-api
    claude-code
    codex
    codex-acp
    python3
    uv
    agent-browser
    playwright-driver
    playwright-test
  ];

  # Host commands run through fixed NixOS-declared systemd units. Sudo is
  # scoped to exact `systemctl start --no-block <unit>` commands.
  home.file = pkgs.lib.mapAttrs'
    (name: source: {
      name = ".local/bin/${name}";
      value = {
        executable = true;
        inherit source;
      };
    })
    binFiles // {
      ".npmrc".text = ''
        prefix=${home}/.local
        min-release-age=1
      '';
      ".bunfig.toml".source = ../files/bunfig.toml;
      ".cargo/config.toml".source = ../files/cargo/config.toml;
      ".config/uv/uv.toml".source = ../files/uv/uv.toml;
      ".factory/settings.json".text = factorySettings;
      ".config/amp/settings.json".text = ampSettings;
      ".cli-proxy-api/config.yaml".text = cliProxyApiConfig;
      ".claude/CLAUDE.md".source = ../files/claude/CLAUDE.md;
      ".codex/AGENTS.md".source = ../files/codex/AGENTS.md;
    };

  systemd.user.services.cli-proxy-api = {
    Unit = {
      Description = "CLIProxyAPI local OAuth LLM proxy";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.cli-proxy-api}/bin/cli-proxy-api --config ${home}/.cli-proxy-api/config.yaml";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      sync-nix = "rebuild";
      update-force = "update --force";
      rollback-force = "rollback";
      pix = "cd /workspace/src/pix";
      pclaw = "cd /workspace/src/piclaw-customizations";
      nm = "cd ~/newmem";
      nfur = "nfu && rebuild";
      c = "claude --dangerously-skip-permissions";
      c45 = "claude --dangerously-skip-permissions --model claude-opus-4-5";
      c46 = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]'";
      c47 = "claude --dangerously-skip-permissions --model claude-opus-4-7";
      cr = "claude --dangerously-skip-permissions --resume";
      c45r = "claude --dangerously-skip-permissions --model claude-opus-4-5 --resume";
      c46r = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]' --resume";
      c47r = "claude --dangerously-skip-permissions --model claude-opus-4-7 --resume";
      y = "codex --dangerously-bypass-approvals-and-sandbox";
      yr = "codex --dangerously-bypass-approvals-and-sandbox resume";
      ta = "tmux attach";
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    escapeTime = 0;
    baseIndex = 1;
    extraConfig = builtins.readFile ../files/tmux/tmux.conf;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "alice";
      user.email = "aliceisjustplaying@gmail.com";
      user.signingKey = "~/.ssh/id_ed25519_github";
      commit.gpgSign = true;
      gpg.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_github";
        identitiesOnly = true;
        extraOptions.StrictHostKeyChecking = "accept-new";
      };
      "localhost" = {
        user = "agent";
        identityFile = "~/.ssh/id_ed25519_local";
        identitiesOnly = true;
        extraOptions.StrictHostKeyChecking = "accept-new";
      };
    };
  };
}
