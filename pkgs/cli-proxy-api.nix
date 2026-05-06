{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "cli-proxy-api";
  version = "6.9.49";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-k89a4R+ZLiYC6guSnB1QULg0npuMjCL0yLl5Khmn62s=";
  };

  vendorHash = "sha256-qvQO7c/780UWxvM/Lp/KHqcd/pFqzyJx6ILaOeZId7A=";

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  postInstall = ''
    mv $out/bin/server $out/bin/cli-proxy-api
  '';

  meta = {
    description = "OpenAI/Gemini/Claude/Codex compatible OAuth proxy service for AI CLIs";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api";
  };
}
