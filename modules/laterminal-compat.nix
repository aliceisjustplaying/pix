{
  config,
  lib,
  pkgs,
  ...
}:

let
  agentKeys = lib.concatStringsSep "\n" config.users.users.agent.openssh.authorizedKeys.keys;
  ensureHostKey = pkgs.writeShellScript "dropbear-laterminal-hostkey" ''
    set -eu
    key=/var/lib/dropbear-laterminal/dropbear_ed25519_host_key
    if [ ! -e "$key" ]; then
      ${pkgs.dropbear}/bin/dropbearkey -t ed25519 -f "$key"
    fi
  '';
in {
  system.activationScripts.dropbearLaTerminalAuthorizedKeys.text = ''
    install -d -m 700 -o agent -g users /home/agent/.ssh
    cat > /home/agent/.ssh/authorized_keys <<'EOF'
${agentKeys}
EOF
    chown agent:users /home/agent/.ssh/authorized_keys
    chmod 600 /home/agent/.ssh/authorized_keys
  '';

  systemd.services.dropbear-laterminal = {
    description = "Dropbear SSH compatibility listener for La Terminal";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      StateDirectory = "dropbear-laterminal";
      ExecStartPre = ensureHostKey;
      ExecStart = "${pkgs.dropbear}/bin/dropbear -F -E -p 0.0.0.0:2222 -r /var/lib/dropbear-laterminal/dropbear_ed25519_host_key -s -g -w -K 30 -I 0";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2222 ];
}
