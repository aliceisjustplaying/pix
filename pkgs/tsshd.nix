{ symlinkJoin, makeWrapper, tsshd, fetchFromGitHub }:

let
  # Pinned UDP range so the firewall on tailscale0 can allow exactly this.
  # Starts at 61001 to avoid overlapping mosh (60000-61000).
  portRange = "61001-61999";
  pinnedTsshd = tsshd.overrideAttrs (finalAttrs: _oldAttrs: {
    version = "0.1.8";

    src = fetchFromGitHub {
      owner = "trzsz";
      repo = "tsshd";
      tag = "v${finalAttrs.version}";
      hash = "sha256-YqSSJA/jP8WRbfwC5fxFE4su01ZEPQNmiNRr96pDE1g=";
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
