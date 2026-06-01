{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;
  workspaceSrc = "/workspace/src";
  tmpl = import ../../lib/template.nix;
  hermesLibraryPath = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.krb5
    pkgs.openssl
    pkgs.icu70
    pkgs.lz4
    pkgs.readline
    pkgs.xz
    pkgs.zlib
    pkgs.zstd
  ];
  hermesBuildPath = pkgs.lib.makeBinPath [
    pkgs.gnumake
    pkgs.nodejs_24
    pkgs.pkg-config
    pkgs.python312
    pkgs.stdenv.cc
  ];

  proxyApiKey = "CLI_PROXY_API_KEY";
  proxyBaseUrl = "http://127.0.0.1:8317";
  proxyOpenAIBaseUrl = "${proxyBaseUrl}/v1";

  modelCatalog = import ./model-catalog.nix {
    inherit (pkgs) lib;
    inherit tmpl proxyApiKey proxyBaseUrl proxyOpenAIBaseUrl;
  };

  # Render a script from files/bin/<name>.sh. Pass replacements for the
  # @placeholder@ tokens the file uses (replaceVars errors on unused vars).
  binSrc = name: replacements:
    pkgs.replaceVars (../../files/bin + "/${name}.sh") replacements;

  # Files with no placeholders; included verbatim.
  binStatic = name: ../../files/bin + "/${name}.sh";

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
    hermes = binSrc "hermes" { inherit hermesBuildPath hermesLibraryPath; };
    hermes-gateway-smoke = binStatic "hermes-gateway-smoke";
    amp-login-proxy = binStatic "amp-login-proxy";
    amp-login-upstream = binStatic "amp-login-upstream";
  };
in
{
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
      ".bunfig.toml".source = ../../files/bunfig.toml;
      ".cargo/config.toml".source = ../../files/cargo/config.toml;
      ".config/pnpm/config.yaml".source = ../../files/pnpm/config.yaml;
      ".config/uv/uv.toml".source = ../../files/uv/uv.toml;
      ".factory/settings.json".text = modelCatalog.factorySettings;
      ".config/amp/settings.json".text = modelCatalog.ampSettings;
      ".cli-proxy-api/config.yaml".text = modelCatalog.cliProxyApiConfig;
      ".claude/CLAUDE.md".source = ../../files/claude/CLAUDE.md;
      ".codex/AGENTS.md".source = ../../files/codex/AGENTS.md;
    };
}
