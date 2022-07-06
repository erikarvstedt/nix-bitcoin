srcFrontend: nodeEnv: frontendPkgs: nodejs: meta: fetchurl: rsync:
let
  # TODO: Fetch the rev and hashes via ./generate.sh
  assetRegistryRev = "49cfb7a1c50939c3fe00b7c18e52459d7e6f7723";
  assetIndex = fetchurl {
    url = "https://raw.githubusercontent.com/blockstream/asset_registry_db/${assetRegistryRev}/index.json";
    hash = "sha256-cqKpq5PW5N4VtpAPStiaVPuyC4mfu5ytCa7XpDxNFVg=";
  };
  assetIndexMinimal = fetchurl {
    url = "https://raw.githubusercontent.com/blockstream/asset_registry_db/${assetRegistryRev}/index.minimal.json";
    hash = "sha256-QUZcvYL4P7XB4s2Ol9cOxlBrWDbgQlO+WdL8F6D5fPU=";
  };
  pools = fetchurl {
    url = "https://raw.githubusercontent.com/mempool/mining-pools/3fb27ad0328c6fc4228f855d8ff1175e01f18e4c/pools.json";
    hash = "sha256-tu1Rhe5YTkQt9hPgEX/KznioY2DbW4Lof4n3URt8cXE=";
  };
in
nodeEnv.buildNodePackage (frontendPkgs.args // {
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

    # TODO-EXTERNAL:
    # `npm run build` produces incorrect output if a parent dir of $PWD is named `node_modules`:
    # https://github.com/mempool/mempool/issues/1256
    # This is the case here, where $PWD equals $out/lib/node_modules/mempool-frontend
    mv $PWD $out/lib/tmp
    cd $out/lib/tmp
    npm run build

    # Add assets that would otherwise be downloaded by sync-assets.js
    resources=dist/mempool/browser/resources/resources
    resourcesEnUS=dist/mempool/browser/en-US/resources
    cp ${assetIndex} $resources/assets.json
    cp ${assetIndex} $resourcesEnUS/assets.json
    cp ${assetIndexMinimal} $resources/assets.minimal.json
    cp ${assetIndexMinimal} $resourcesEnUS/assets.minimal.json
    cp ${pools} $resources/pools.json
    cp ${pools} $resourcesEnUS/pools.json

    # Move build to $out
    mv dist/mempool/browser/* $out

    # Remove temporary files
    rm -r $out/lib
  '';

  inherit meta;
})
