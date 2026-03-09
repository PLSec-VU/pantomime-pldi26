{ pkgs ? import (fetchTarball
  "https://github.com/NixOS/nixpkgs/archive/ed6c38bce3eee7a7e7b870d52a72eb8370890e50.tar.gz")
  { } }:
let
  hlib = pkgs.haskell.lib;

  haskellBuildInputs = with pkgs; [
    zlib
    cacert
    z3
  ];

  texlive = pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-small booktabs makecell graphics psnfss xcolor tools latexmk;
  };

  ghc = pkgs.haskell.compiler.ghc9102;

  artifact = pkgs.copyPathToStore ./artifact;

  aimcoreBuilt = pkgs.runCommand "aimcore-built" {
    buildInputs = with pkgs; [ stack ghc z3 zlib glibc gnumake gnutar xz cacert git nix gcc glibcLocales ];
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
  } ''
    export HOME=$out
    export STACK_ROOT=$out/.stack
    mkdir -p $out
    cp -r ${artifact} $out/artifact
    chmod -R u+w $out/artifact
    cd $out/artifact/aimcore
    stack build --no-nix --system-ghc --no-install-ghc
  '';

in pkgs.dockerTools.buildImage {
  name = "pantomime";
  tag = "latest";
  created = "now";
  diskSize = 20480;
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    pathsToLink = [ "/bin" "/lib" "/include" "/share" "/etc" ];
    paths = with pkgs; [
      zlib
      glibc
      xz
      gnumake
      gnutar
      cacert
      z3
      stack
      ghc
      texlive
      coreutils
      bash
      less
      nano
      janet
      (python3.withPackages (ps: [
           ps.pyyaml
           ps.lark
         ]))
      yices
      yosys
      iverilog
      gcc
      which
      readline
      gnused
      bat
      vim
      emacs
    ];
  };

  runAsRoot = ''
    mkdir -p /tmp
    chmod 1777 /tmp

    mkdir /.cache
    chmod 777 /.cache
    export XDG_CACHE_HOME=/.cache

    cp -r ${aimcoreBuilt}/artifact /artifact
    cp -r ${aimcoreBuilt}/.stack /artifact/.stack
    chmod -R u+w /artifact
  '';

  config = {
    Cmd = [ "/bin/bash" ];
    WorkingDir = "/artifact";
    Env = [ "STACK_ROOT=/artifact/.stack"
            "LIBRARY_PATH=/lib"
            "C_INCLUDE_PATH=/include"
            "CPLUS_INCLUDE_PATH=/include"
    ];
  };
}
