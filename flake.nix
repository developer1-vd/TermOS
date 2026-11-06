{
  description = "TermOS tools: termos-fetch and termos-run";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        termos = pkgs.stdenvNoCC.mkDerivation {
          pname = "termos";
          version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./VERSION);
          src = ./.;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = ''
            make install PREFIX=$out
            wrapProgram $out/bin/termos-fetch \
              --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.fastfetch pkgs.fortune ]}
            wrapProgram $out/bin/termos-run \
              --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.file pkgs.openssh ]}
          '';
          meta = {
            description = "TermOS fetch logos and run-anything launcher";
            license = pkgs.lib.licenses.gpl3Only;
            platforms = systems;
          };
        };
        default = termos;
      });

      apps = forAll (pkgs: {
        default = { type = "app"; program = "${self.packages.${pkgs.system}.termos}/bin/termos-fetch"; };
        termos-fetch = { type = "app"; program = "${self.packages.${pkgs.system}.termos}/bin/termos-fetch"; };
        termos-run = { type = "app"; program = "${self.packages.${pkgs.system}.termos}/bin/termos-run"; };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.shellcheck pkgs.gnumake pkgs.fastfetch pkgs.fortune pkgs.file ];
        };
      });
    };
}
