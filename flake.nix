{
  description = "parca flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      pkgsForSystem = system: (import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsForSystem system;
          inherit (pkgs)
            buildGoModule
            faketty
            lib
            nodejs
            pnpm_9
            stdenv
            ;

          commit = self.rev or self.dirtyRev or "dirty";
          version = "dev";

          ui = stdenv.mkDerivation (finalAttrs: {
            inherit version;
            pname = "parca-ui";
            src = lib.cleanSource ./. + "/ui";

            pnpmDeps = pnpm_9.fetchDeps {
              inherit (finalAttrs) pname src version;
              hash = "sha256-JFV8h4n4aUUGTEUP6b+b8wGT1Qtm5W1HxuhT/R8o2CQ=";
            };

            nativeBuildInputs = [
              faketty
              nodejs
              pnpm_9.configHook
            ];

            # faketty is required to work around a bug in nx.
            # See: https://github.com/nrwl/nx/issues/22445
            buildPhase = ''
              runHook preBuild
              faketty pnpm build
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/parca
              mv packages/app/web/build $out/share/parca/ui
              runHook postInstall
            '';
          });
        in
        rec {
          default = parca;

          parca = buildGoModule {
            pname = "parca";
            inherit version;
            src = lib.cleanSource ./.;
            vendorHash = "sha256-nhcqWuFT4cdia17QXQvb0P8gU01ZnFJu+OmS6pA4uX4=";

            ldflags = [
              "-X=main.version=${version}"
              "-X=main.commit=${commit}"
            ];

            preBuild = ''
              # Copy the built UI into the right place for the Go build to embed it.
              cp -r ${ui}/share/parca/ui/* ui/packages/app/web/build
            '';

            meta.mainProgram = "parca";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsForSystem system;
        in
        {
          default = pkgs.mkShell {
            name = "parca";
            NIX_CONFIG = "experimental-features = nix-command flakes";
            buildInputs = with pkgs; [
              buf

              go_1_23
              go-tools
              gofumpt
              gojsontoyaml
              golangci-lint
              gopls
              goreleaser
              govulncheck

              jsonnet

              nodejs_18
              nodePackages_latest.prettier
              pnpm

              pre-commit
            ];
          };
        }
      );
    };
}
