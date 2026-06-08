{
  lib,
  beam27Packages,
  elixir_1_18,
  buildNpmPackage,
  rustPlatform,
  fetchFromGitHub,
  nodejs,
  runCommand,
  nixosTests,
  npm-lockfile-fix,
  nix-update-script,
  brotli,
  cmake,
  tailwindcss_4,
  esbuild,
  buildPackages,
}:

let
  pname = "plausible";
  version = "3.2.1";
  mjmlVersion = "4.0.0";
  mixEnv = "ce";

  src = fetchFromGitHub {
    owner = "plausible";
    repo = "analytics";
    rev = "v${version}";
    hash = "sha256-2roIj0s2cybYdGmmJSPJ5Rc1gNunxlYew9JR5xxMv+k=";
    postFetch = ''
      ${lib.getExe npm-lockfile-fix} $out/assets/package-lock.json
      sed -ie '
        /defp deps do/ {
          n
          /\[/ a\
            \{:rustler, ">= 0.0.0", optional: true \},
          }
      ' $out/mix.exs
      cat >> $out/config/config.exs <<EOF
      config :mjml, Mjml.Native,
        crate: :mjml_nif,
        skip_compilation?: true
      EOF
    '';
  };

  assets = buildNpmPackage {
    pname = "${pname}-assets";
    inherit version;
    src = "${src}/assets";
    npmDepsHash = "sha256-grYxPRzpu3pcv3lyTQxx0RDhmgFhsOKZoYbzd701xjA=";
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      runHook postInstall
    '';
  };

  tracker = buildNpmPackage {
    pname = "${pname}-tracker";
    inherit version;
    src = "${src}/tracker";
    npmDepsHash = "sha256-hrsvQXvbcfRDUc1qinyUJ7Oh4yMM1e+UEdYudjYyJxk=";
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      runHook postInstall
    '';
  };

  mixFodDeps = beamPackages.fetchMixDeps {
    inherit
      pname
      version
      src
      mixEnv
      ;
    hash = "sha256-fm/elkCNpu5sduBxly06i/z30Y9BMtt+qthXmLuvlUc=";
  };

  mjmlNif = rustPlatform.buildRustPackage {
    pname = "mjml-native";
    version = "";
    src = "${mixFodDeps}/mjml/native/mjml_nif";

    cargoHash = "sha256-a8xSRdFtMYF0n2rl7A5ZgHoaunUJLVJwHvrkc9uyZKo=";
    doCheck = false;

    env = {
      RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
      RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";
    };
  };

  lexbor = fetchFromGitHub {
    owner = "lexbor";
    repo = "lexbor";
    rev = "244b84956a6dc7eec293781d051354f351274c46";
    hash = "sha256-Oup/lGU8a9Dqfho4Llg39t9Y9n4xfUmGk0772OkpnLQ=";
  };

  patchedMixFodDeps =
    runCommand mixFodDeps.name
      {
        inherit (mixFodDeps) hash;
      }
      ''
        mkdir $out
        cp -r --no-preserve=mode ${mixFodDeps}/. $out

        mkdir -p $out/mjml/priv/native
        for lib in ${mjmlNif}/lib/*
        do
          file=''${lib##*/}
          base=''${file%.*}
          ln -s "$lib" $out/mjml/priv/native/$base.so
          if [ "$base" = "libmjml_nif" ]; then
            ln -s "$lib" $out/mjml/priv/native/mjml_nif.so
          fi
        done

        mkdir -p $out/lazy_html/_build/c/third_party/lexbor
        cp --no-preserve=mode -r ${lexbor} \
          $out/lazy_html/_build/c/third_party/lexbor/244b84956a6dc7eec293781d051354f351274c46
      '';

  beamPackages = beam27Packages.extend (_self: _super: { elixir = elixir_1_18; });

in
beamPackages.mixRelease rec {
  inherit
    pname
    version
    src
    mixEnv
    ;

  nativeBuildInputs = [
    cmake
    nodejs
    brotli
  ];

  mixFodDeps = patchedMixFodDeps;

  passthru = {
    tests = {
      inherit (nixosTests) plausible;
    };
    updateScript = nix-update-script {
      extraArgs = [
        "-s"
        "tracker"
        "-s"
        "assets"
        "-s"
        "mjmlNif"
      ];
    };
    inherit
      assets
      tracker
      mjmlNif
      ;
  };

  env = {
    APP_VERSION = version;
    RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
    RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";
    XDG_CACHE_HOME = "/build/.cache";
  };

  preBuild = ''
    rm -r assets tracker
    cp --no-preserve=mode -r ${assets} assets
    cp --no-preserve=mode -r ${tracker} tracker

    cat >> config/config.exs <<EOF
    config :tailwind, path: "${lib.getExe buildPackages.tailwindcss_4}"
    config :esbuild, path: "${lib.getExe esbuild}"
    EOF
  '';

  postBuild = ''
    npm run deploy --prefix ./tracker

    mix do deps.loadpaths --no-deps-check, assets.deploy
    mix do deps.loadpaths --no-deps-check, phx.digest priv/static
  '';

  postInstall = ''
    mkdir -p $out/lib/mjml-${mjmlVersion}/priv/native
    ln -sf ${mjmlNif}/lib/libmjml_nif.so $out/lib/mjml-${mjmlVersion}/priv/native/mjml_nif.so
  '';

  meta = {
    license = lib.licenses.agpl3Plus;
    homepage = "https://plausible.io/";
    changelog = "https://github.com/plausible/analytics/blob/${src.rev}/CHANGELOG.md";
    description = "Simple, open-source, lightweight privacy-friendly web analytics";
    mainProgram = "plausible";
    maintainers = with lib.maintainers; [
      e1mo
      xanderio
    ];
    platforms = lib.platforms.unix;
  };
}
