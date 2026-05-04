{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      gtk3
      glib
      dbus-glib
      alsa-lib
      nss
      nspr
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libXtst
      xorg.libXScrnSaver
      xorg.libxcb
      xorg.libXi
      pango
      cairo
      atk
      at-spi2-atk
      cups.lib
      libdrm
      mesa
      expat
      gdk-pixbuf
      fontconfig
      freetype
    ];
  };
}
