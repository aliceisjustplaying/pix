{
  config,
  lib,
  pkgs,
  ...
}:

let
  compatOpenSsh = pkgs.openssh.overrideAttrs {
    version = "9.0p1";
    src = pkgs.fetchurl {
      url = "mirror://openbsd/OpenSSH/portable/openssh-9.0p1.tar.gz";
      hash = "sha256-A5dDAhYenszjIVPPoQAS8eZcjzdQ9XOnOrG+/Vlyooo=";
    };
  };
  agentKeys = lib.concatStringsSep "\n" config.users.users.agent.openssh.authorizedKeys.keys;
  ensureHostKey = pkgs.writeShellScript "dropbear-laterminal-hostkey" ''
    set -eu
    key=/var/lib/dropbear-laterminal/dropbear_ed25519_host_key
    if [ ! -e "$key" ]; then
      ${pkgs.dropbear}/bin/dropbearkey -t ed25519 -f "$key"
    fi
  '';
  ensureOpenSshHostKey = pkgs.writeShellScript "openssh-laterminal-hostkey" ''
    set -eu
    key=/var/lib/openssh-laterminal/ssh_host_ed25519_key
    if [ ! -e "$key" ]; then
      ${compatOpenSsh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$key"
    fi
  '';
  openSshConfig = pkgs.writeText "sshd-laterminal-config" ''
    Port 2223
    ListenAddress 0.0.0.0
    Protocol 2
    HostKey /var/lib/openssh-laterminal/ssh_host_ed25519_key
    PidFile /run/openssh-laterminal.pid

    AllowUsers agent
    AuthorizedKeysFile .ssh/authorized_keys
    UsePAM yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PubkeyAuthentication yes
    PermitRootLogin no
    StrictModes yes

    PermitTTY yes
    X11Forwarding no
    AllowTcpForwarding yes
    PermitOpen any
    PermitListen any
    GatewayPorts no
    DisableForwarding no
    PermitUserRC no

    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256
    Ciphers aes256-ctr,aes128-ctr,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    MACs hmac-sha2-256,hmac-sha2-512,hmac-sha1
    HostKeyAlgorithms ssh-ed25519
    PubkeyAcceptedAlgorithms ssh-ed25519

    Subsystem sftp internal-sftp
    LogLevel DEBUG3
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

  systemd.services.openssh-laterminal = {
    description = "OpenSSH compatibility listener for La Terminal";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      StateDirectory = "openssh-laterminal";
      RuntimeDirectory = "openssh-laterminal";
      ExecStartPre = ensureOpenSshHostKey;
      ExecStart = "${compatOpenSsh}/bin/sshd -D -e -f ${openSshConfig}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2222 2223 ];
}
