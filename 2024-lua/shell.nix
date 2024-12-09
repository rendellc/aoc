# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.lua
  ];

  # Optionally, set up a Lua script to run when you enter the shell
  shellHook = ''
    echo "Welcome to the Lua environment!"
  '';
}
