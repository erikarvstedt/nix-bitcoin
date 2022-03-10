config: lib:

with lib;
{
  allowedNodes = mkOption {
    type = types.listOf types.str;
    default = [];
    example = [ "0266e4598d1d3c415f572a8488830b60f7e744ed9235eb0b1ba93283b315c03518" ];
    description = ''
      IDs of nodes that are authorized to send a peerswap request to your node.
    '';
  };
  allowAll = mkOption {
    type = types.bool;
    default = false;
    description = "UNSAFE: Allow all nodes to swap with your node.";
  };
  enableBitcoin = mkOption {
    type = types.bool;
    default = true;
    description = "Enable bitcoin swaps.";
  };
  enableLiquid = mkOption {
    type = types.bool;
    default = config.services.liquidd.enable or false;
    description = "Enable liquid-btc swaps.";
  };
  liquidRpcWallet = mkOption {
    type = types.str;
    default = "peerswap";
    description = "The liquid rpc wallet to use peerswap with";
  };
}
