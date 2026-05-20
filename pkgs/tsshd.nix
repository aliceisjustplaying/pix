{ symlinkJoin, makeWrapper, tsshd, fetchFromGitHub }:

let
  # Pinned UDP range so the firewall on tailscale0 can allow exactly this.
  # Starts at 61001 to avoid overlapping mosh (60000-61000).
  portRange = "61001-61999";
  # Pinned to our fork (https://github.com/trzsz/tsshd/pull/36) which fixes an
  # agent-forwarding hang: parked accept connections the client never claims are
  # now reaped after ConnectTimeout instead of blocking ssh-add / git SSH commit
  # signing forever. Revert to upstream v0.1.8 once the PR merges.
  # version stays "0.1.8" to match the version baked into the binary (upstream's
  # versionCheckHook greps `tsshd --help`); the fork is pinned by rev below.
  pinnedTsshd = tsshd.overrideAttrs (_finalAttrs: _oldAttrs: {
    version = "0.1.8";

    src = fetchFromGitHub {
      owner = "aliceisjustplaying";
      repo = "tsshd";
      rev = "2620d49091cba76e5b3d78d9f1c2203e301d0068";
      hash = "sha256-RTRGLWQMjik4oJDm0/bna73N7BXsHXLRgbv9PbSZ8Ys=";
    };

    vendorHash = "sha256-HJWxphZuBh3gXPoEqL/EVGtwdWyW+cMSQhKyfSymKG0=";
  });
in
symlinkJoin {
  name = "tsshd-wrapped-${pinnedTsshd.version}";
  paths = [ pinnedTsshd ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/tsshd --add-flags "--port ${portRange}"
  '';
  meta = pinnedTsshd.meta;
}
