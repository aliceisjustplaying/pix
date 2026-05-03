{ symlinkJoin, makeWrapper, tsshd, fetchFromGitHub }:

let
  # Pinned UDP range so the firewall on tailscale0 can allow exactly this.
  portRange = "61000-61999";
  pinnedTsshd = tsshd.overrideAttrs (finalAttrs: _oldAttrs: {
    version = "0.1.7";

    src = fetchFromGitHub {
      owner = "trzsz";
      repo = "tsshd";
      tag = "v${finalAttrs.version}";
      hash = "sha256-9llfXzAAQgAOeaD+o3AVyhP0uL88uQsCNlqAPNfzDVw=";
    };

    vendorHash = "sha256-btTWkuLkT2e58TYqe0e/cE/0Try/g8XoahiABSSFaGU=";
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
