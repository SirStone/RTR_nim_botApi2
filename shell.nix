let 
  unstable = import <nixos-unstable> {};
  stable = import <nixos> {};
in
stable.mkShell {
  nativeBuildInputs = [ 
    stable.nim2
    unstable.nimble
    stable.jdk21
    stable.valgrind
    stable.gdb
  ];
}
