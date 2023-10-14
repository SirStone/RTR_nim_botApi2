let 
  unstable = import <nixos-unstable> {};
  stable = import <nixos> {};
in
stable.mkShell {
  nativeBuildInputs = [ 
    unstable.buildPackages.nim2
    unstable.buildPackages.nimPackages.nimble
    stable.openjdk
  ];
}
