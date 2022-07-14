{ lib
, stdenvNoCC
, nodejs-16_x
, nodejs-slim-16_x
, fetchFromGitHub
, fetchNodeModules
, runCommand
, makeWrapper
, fetchurl
, fetchzip
, curl
, cacert
, rsync
}:
rec {
  nodejs = nodejs-16_x;
  nodejsRuntime = nodejs-slim-16_x;

  src = fetchFromGitHub {
    owner = "erikarvstedt";
    repo = "mempool";
    rev = "1b91d3e5d60fedb60eb7b8f57035de3b7082364d";
    hash = "sha256-7YXwK/IZ1wPtstazDtBX69Cp5xOgfl6W8XdBIp5y8uk=";
  };

  nodeModules = {
    backend = fetchNodeModules {
      inherit src nodejs;
      preBuild = "cd backend";
      hash = "sha256-/DRFhMGHRePnGs8hHjtnu/wvV9lmBAlfCXZJBD6VoEY=";
    };
    frontend = fetchNodeModules {
      inherit src nodejs;
      preBuild = "cd frontend";
      hash = "sha256-6+znCa+P9n9S8h1/bJQ/G3JMyWrOC1TSl+lMQy7Mh/k=";
    };
  };

  frontendAssets = fetchFiles {
    name = "mempool-frontend-assets";
    hash = "sha256-vUyW92XcaPA2J2oAzandMi2mnl6VhGxK3fBZ5GSTDvI=";
    fetcher = ./frontend-assets-fetch.sh;
  };

  mempool-backend = mkDerivationMempool {
    pname = "mempool-backend";

    buildPhase = ''
      cd backend
      rsync -a --chmod=+w ${nodeModules.backend}/lib/node_modules .
      patchShebangs node_modules

      npm run package

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p $out/lib/mempool-backend
      rsync -a package/ $out/lib/mempool-backend

      makeWrapper ${nodejsRuntime}/bin/node $out/bin/mempool-backend \
        --add-flags $out/lib/mempool-backend/index.js

      runHook postInstall
    '';

    passthru = {
      inherit nodejs nodejsRuntime;
    };
  };

  mempool-frontend = mkDerivationMempool {
    pname = "mempool-frontend";

    buildPhase = let
      assets = import ./frontend-assets.nix fetchurl fetchzip;
    in ''
      cd frontend

      rsync -a --chmod=+w ${nodeModules.frontend}/lib/node_modules .
      patchShebangs node_modules

      # sync-assets.js is called during `npm run build` and downloads assets from the
      # internet. Disable this script and instead add the assets manually after building.
      : > sync-assets.js

      # If this produces incomplete output (when run in a different build setup),
      # see https://github.com/mempool/mempool/issues/1256
      npm run build

      # Add assets that would otherwise be downloaded by sync-assets.js
      rsync -a ${frontendAssets}/ dist/mempool/browser/resources

      runHook postBuild
    '';

    installPhase = ''
      rsync -a dist/mempool/browser/ $out

      runHook postInstall
    '';

    passthru = { assets = frontendAssets; };
  };

  mempool-nginx-conf = runCommand "mempool-nginx-conf" {} ''
    ${rsync}/bin/rsync -a --copy-links --exclude=/README.md ${src}/nginx/ $out
  '';

  mkDerivationMempool = args: stdenvNoCC.mkDerivation ({
    version = src.rev;
    inherit src meta;

    nativeBuildInputs = [
      makeWrapper
      nodejs
      rsync
    ];

    phases = "unpackPhase patchPhase buildPhase installPhase";
  } // args);

  fetchFiles = { name, hash, fetcher }: stdenvNoCC.mkDerivation {
    inherit name;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = hash;
    nativeBuildInputs = [ curl cacert ];
    buildCommand = ''
      mkdir $out
      cd $out
      ${builtins.readFile fetcher}
    '';
  };

  meta = with lib; {
    description = "Bitcoin blockchain and mempool explorer";
    homepage = "https://github.com/mempool/mempool/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ earvstedt ];
    platforms = platforms.unix;
  };
}
