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

  # TODO Make a separate backup (plugin) package so that the cli is also available
  # TODO Handle conflict between sauron and bcli plugins

  plugins = with nbPython3Packages; {
    autopilot = {
      extraPkgs = [ dnspython networkx numpy ];
      patchRequirements = "--replace networkx==2.3 networkx==2.4";
    };
    donations = {
      extraPkgs = [ flask-bootstrap flask_wtf pillow qrcode ];
    };
    drain = {};
    feeadjuster = {
      # Fix requirements error: pyln-client 0.8.2 doesn't exist yet, 0.8.0 is the
      # version from clightning master
      patchRequirements = "--replace 'pyln-client>=0.8.2' pyln-client==0.8.0";
    };
    helpme = {};
    jitrebalance = {
      patchRequirements = "--replace pyln-client==0.7.3 pyln-client>=0.7.3";
    };
    monitor = {};
    noise = {
      extraPkgs = [ bitstring pyln-proto ];
      patchRequirements = "--replace bitstring==3.1.6 bitstring==3.1.5";
    };
    persistent-channels = {};
    probe = {
      extraPkgs = [ sqlalchemy ];
      patchRequirements = "--replace sqlalchemy==1.3.6 sqlalchemy==1.3.19";
    };
    prometheus = {
      extraPkgs = [ prometheus_client ];
      patchRequirements = "--replace prometheus-client==0.6.0 prometheus-client==0.8.0";
    };
    rebalance = {};
    sendinvoiceless = {};
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
