let 
  unstable = import <nixos-unstable> {};
  stable = import <nixos> {};
in
stable.mkShell {
  nativeBuildInputs = [ 
    unstable.nim-unwrapped-2
    unstable.nimble
    unstable.nimlangserver
    stable.jdk21
    stable.valgrind
    stable.gdb
    stable.gcc
  ];
}
