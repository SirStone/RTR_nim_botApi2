{ pkgs ? import <nixos-unstable> {} }:
  pkgs.mkShell {
    nativeBuildInputs = [ 
      pkgs.buildPackages.nim2
      pkgs.buildPackages.nimPackages.nimble
    ];
}
