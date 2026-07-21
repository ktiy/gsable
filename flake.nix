{
  description = "sable compiler";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell rec {
          buildInputs = with pkgs; [
            zig
            zola

            libGL
            vulkan-loader
            wayland
            libxkbcommon
            libdecor
            xorg.libX11
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
          ];

          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
        };
      });
}
