{ lib, buildNpmPackage, fetchurl, nodejs }:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.16.2";

  inherit nodejs;

  src = fetchurl {
    url = "https://registry.npmjs.org/@zed-industries/claude-code-acp/-/claude-code-acp-${version}.tgz";
    hash = "sha256-RxOzu6BGUIUJKeTbHmgAc9A79V3N+L/LO7HL2CvPqZ4=";
  };

  # The published tarball ships package.json but no lockfile. Drop ours in so
  # buildNpmPackage can run an offline `npm ci`.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-Lk3Wq0/kqfDLmTLTu1Op43Hv+ZKaSQIw93sixiT4CRc=";

  # Tarball already ships pre-compiled dist/, no build step needed.
  dontNpmBuild = true;

  meta = with lib; {
    description = "ACP-compatible coding agent powered by Claude Code";
    homepage = "https://github.com/zed-industries/claude-code-acp";
    license = licenses.asl20;
    mainProgram = "claude-code-acp";
    platforms = platforms.linux;
  };
}
