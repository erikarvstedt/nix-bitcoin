{ pkgs, lib, fetchFromGitHub, fetchurl, makeWrapper, rsync }:
rec {
  nodejs = pkgs.nodejs-16_x;
  nodejsRuntime = pkgs.nodejs-slim-16_x;

  src = fetchFromGitHub {
    owner = "erikarvstedt";
    repo = "mempool";
    # https://github.com/erikarvstedt/mempool/commits/dev
    rev = "8924873bfde2b9c2bd218e77800eff4008bd0122";
    hash = "sha256-YZyUQ42sz+eLNFvi1o/2lu3aHXk6UhpTbeDJdiCDyTQ=";
  };

  # node2nix requires that the backend and frontend are available as distinct node
  # packages
  srcBackend = pkgs.runCommand "mempool-backend" {} ''
    cp -r ${src}/backend $out
  '';
  srcFrontend = pkgs.runCommand "mempool-frontend" {} ''
    cp -r ${src}/frontend $out
  '';

  nodeEnv = import "${toString pkgs.path}/pkgs/development/node-packages/node-env.nix" {
    inherit (pkgs) stdenv lib python2 runCommand writeTextFile writeShellScript;
    inherit pkgs nodejs;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };

  nodePkgs = file: import file {
    inherit (pkgs) fetchurl nix-gitignore stdenv lib fetchgit;
    inherit nodeEnv;
  };
  backendPkgs = nodePkgs ./node-packages-backend.nix;
  frontendPkgs = nodePkgs ./node-packages-frontend.nix;

  mempool-backend = nodeEnv.buildNodePackage (backendPkgs.args // {
    src = srcBackend;

    nativeBuildInputs = (backendPkgs.args.nativeBuildInputs or []) ++ [
      makeWrapper
    ];

    # PWD at this point: $out/lib/node_modules/mempool-backend
    postInstall = ''
      npm run package

      mv package $out/lib/mempool-backend
      rm -r $out/lib/node_modules/

      makeWrapper ${nodejsRuntime}/bin/node $out/bin/mempool-backend \
        --add-flags $out/lib/mempool-backend/index.js
    '';

    inherit meta;

    passthru = {
      inherit nodejs nodejsRuntime;
    };
  });

  mempool-frontend =
    import ./frontend.nix srcFrontend nodeEnv frontendPkgs nodejs meta fetchurl rsync;

  meta = with lib; {
    description = "Bitcoin blockchain and mempool explorer";
    homepage = "https://github.com/mempool/mempool/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ nixbitcoin earvstedt ];
    platforms = platforms.unix;
  };
}
