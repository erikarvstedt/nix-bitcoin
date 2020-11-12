pkgs:

let version = {
      plugins = "b7804408f4004efca9e6d83a975c0a5f82fd533f";
      mach-nix = "3.0.2";
    };

    src = {
      mach-nix = fetchTarball {
        url = "https://github.com/DavHau/mach-nix/archive/${version.mach-nix}.tar.gz";
        sha256 = "0w6i3wx9jyn29nnp6lsdk5kwlffpnsr4c80jk10s3drqyarckl2f";
      };

      plugins = fetchTarball {
        url = "https://github.com/lightningd/plugins/archive/${version.plugins}.tar.gz";
        sha256 = "13cccwxanhmwmhr4prs13gn5am9l2xqckk80ad41kp2a4jq4gdsy";
      };
    };

    mach-nix = import src.mach-nix { inherit pkgs; };

    mkPython = name: mach-nix.mkPython {
      requirements =
        let reqsFromFile = builtins.readFile (src.plugins + "/${name}/requirements.txt"); in
        ''
        pyln-client>=0.7.3
        ${reqsFromFile}
        '';
    };

    mkPlugin = name: scriptName: pkgs.stdenv.mkDerivation {
      pname = "clightning-plugin-${name}";
      version = version.plugins;

      src = src.plugins;

      propagatedBuildInputs = [ (mkPython name) ];

      installPhase = let script = "${name}/${scriptName}.py"; in
        ''
        patchShebangs ${script}
        find ${name} -type f -exec chmod -x {} \;
        chmod +x ${script}
        mkdir -p $out
        cp -R ${name}/* $out/
        '';

      meta = {
        description = "C-lightning plugin: ${name}";
        homepage = "https://github.com/lightningd/plugins";
        license = pkgs.lib.licenses.bsd3;
        maintainers = [];
      };
    };

    toRecord = name: scriptName: {
      inherit name;
      value = mkPlugin name scriptName;
    };

    defaultRecord = name: toRecord name name;

    # TODO Make a separate backup (plugin) package so that the cli is also available
    # TODO Fix the noise plugin installation
    # TODO Handle conflict between sauron and bcli plugins

    plugins = rec {
      names = [
        "autopilot"
        "donations"
        "drain"
        "feeadjuster"
        "helpme"
        "jitrebalance"
        "monitor"
        "persistent-channels"
        "probe"
        "prometheus"
        "rebalance"
        "sendinvoiceless"
        "summary"
      ];
      standard = map defaultRecord names;
      special = [ (toRecord "zmq" "cl-zmq") ];
    };

in builtins.listToAttrs (plugins.standard ++ plugins.special)
