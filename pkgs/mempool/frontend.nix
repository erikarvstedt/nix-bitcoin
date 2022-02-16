srcFrontend: nodeEnv: frontendPkgs: nodejs: meta: fetchurl: rsync: pkgs:
let
  # TODO: Fetch the rev and hashes via ./generate.sh
  assetRegistryRev = "689456ad4d653055eb690dca282b9f8faab1e873";
  assetIndex = fetchurl {
    url = "https://raw.githubusercontent.com/mempool/asset_registry_db/${assetRegistryRev}/index.json";
    hash = "sha256-9pqWQoe3AkTswUt9lFXs02YB5/RB2tFzIQpRDUG34/U=";
  };
  assetIndexMinimal = fetchurl {
    url = "https://raw.githubusercontent.com/mempool/asset_registry_db/${assetRegistryRev}/index.minimal.json";
    hash = "sha256-RobjVsefsUEPomqYARu4d9s/cDfhb0ra+63IUNeYWuw=";
  };
  pools = fetchurl {
    url = "https://raw.githubusercontent.com/btccom/Blockchain-Known-Pools/8446d4d156035e128a2e98742e91880265c61d6c/pools.json";
    hash = "sha256-wX6+Q7ykKXHoHhiJnb12X4x1PqTrpK3h89vpwdDf2zw=";
  };

  frontend = nodeEnv.buildNodePackage (frontendPkgs.args // {
    src = srcFrontend;

    nativeBuildInputs = (frontendPkgs.args.nativeBuildInputs or []) ++ [
      # Required by /bin scripts generated by node packages
      nodejs
      # Required by node script `sync-assets` (defined in frontend/package.json)
      rsync
    ];

    npmFlags = "--no-optional";

    postInstall = ''
      # Patch shebangs of scripts that were generated by `npm ... rebuild`
      patchShebangs node_modules

      # sync-assets.js is called during `npm run build` and downloads assets from the
      # internet. Disable this script and instead add the assets manually after building.
      true > sync-assets.js

      npm run build

      # Add assets that would otherwise be downloaded by sync-assets.js
      resources=dist/mempool/browser/resources/resources
      cp ${assetIndex} $resources/assets.json
      cp ${assetIndexMinimal} $resources/assets.minimal.json
      cp ${pools} $resources/pools.json

      # Move build to $out
      mv dist/mempool/browser/* $out
      # Remove temporary files
      rm -r $out/lib
    '';

    inherit meta;
  });

  # Wrap the builder of `drv` with a bubblewrap mount namespace
  # that includes /usr/bin/env
  addUsrBinEnv = drv:
    pkgs.lib.overrideDerivation drv (old: {
      builder = "${pkgs.bubblewrap}/bin/bwrap";
      args = [
        # Add all contents of `/` that are present in a nix build environemnt
        "--bind" "/bin" "/bin"
        "--bind" "/build" "/build"
        "--bind" "/etc" "/etc"
        "--bind" "/nix" "/nix"
        "--bind" "/tmp" "/tmp"
        "--proc" "/proc"
        "--dev-bind" "/dev" "/dev"
        # Add /usr/bin/env
        "--bind" "${pkgs.coreutils}/bin/env" "/usr/bin/env"
        "--"
      ]
      ++ [ old.builder ] ++ old.args;
    });
in
# Reason for using addUsrBinEnv:
# While `npm rebuild` is run, it dynamically creates script files
# (e.g. `node_modules/.bin/node-gyp-build`) with a `#!/usr/bin/env` shebang
# and calls them afterwards.
# To make this succed, we have to provide /usr/bin/env in the builder.
addUsrBinEnv frontend
