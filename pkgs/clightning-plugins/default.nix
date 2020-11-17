pkgs: nbPython3Packages:

let
  inherit (pkgs) lib;

  src = pkgs.fetchFromGitHub {
    owner = "lightningd";
    repo = "plugins";
    rev = "b7804408f4004efca9e6d83a975c0a5f82fd533f";
    sha256 = "13cccwxanhmwmhr4prs13gn5am9l2xqckk80ad41kp2a4jq4gdsy";
  };

  version = builtins.substring 0 7 src.rev;

  plugins = with nbPython3Packages; {
    helpme = {};
    monitor = {};
    prometheus = {
      extraPkgs = [ prometheus_client ];
      patchRequirements = "--replace prometheus-client==0.6.0 prometheus-client==0.8.0";
    };
    rebalance = {};
    summary = {
      extraPkgs = [ packaging requests ];
    };
    zmq = {
      scriptName = "cl-zmq";
      extraPkgs = [ twisted txzmq ];
    };
  };

  basePkgs = [ nbPython3Packages.pyln-client ];

  mkPlugin = name: plugin: pkgs.stdenv.mkDerivation (
    let
      python = pkgs.python3.withPackages (_: basePkgs ++ (plugin.extraPkgs or []));
    in {
      pname = "clightning-plugin-${name}";
      inherit version;

      buildInputs = [ python ];

      buildCommand = ''
        cp --no-preserve=mode -r ${src}/${name} $out
        cd $out
        ${lib.optionalString (plugin ? patchRequirements) ''
          substituteInPlace requirements.txt ${plugin.patchRequirements}
        ''}

        # Check that requirements are met
        PYTHONPATH=${toString python}/${python.sitePackages} \
          ${pkgs.python3Packages.pip}/bin/pip install -r requirements.txt --no-cache --no-index

        script=${plugin.scriptName or name}.py
        chmod +x $script
        patchShebangs $script
      '';
    }
);
in
  builtins.mapAttrs mkPlugin plugins
