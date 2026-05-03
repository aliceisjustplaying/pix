{ symlinkJoin, makeWrapper, tsshd }:

let
  # Pinned UDP range so the firewall on tailscale0 can allow exactly this.
  portRange = "61000-61999";
in
symlinkJoin {
  name = "tsshd-wrapped-${tsshd.version}";
  paths = [ tsshd ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/tsshd --add-flags "--port ${portRange}"
  '';
  meta = tsshd.meta;
}
