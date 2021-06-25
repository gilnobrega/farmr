import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/farmer/wallet.dart';
import 'package:farmr_client/foxypool/api.dart';
import 'package:farmr_client/foxypool/wallet.dart';
import 'package:farmr_client/farmer/farmer.dart';

class FoxyPoolOG extends Farmer {
  //public pool key
  String _publicKey = '';

  FoxyPoolWallet _wallet =
      FoxyPoolWallet(-1.0, -1.0, -1.0, -1.0, Blockchain.fromSymbol("xch"));
  @override
  Wallet get wallet => _wallet;

  @override
  final ClientType type = ClientType.FoxyPoolOG;

  FoxyPoolOG({required Blockchain blockchain, String version = ''})
      : super(blockchain: blockchain, version: version, hpool: false) {
    _wallet = FoxyPoolWallet(-1.0, 0, -1.0, -1.0, this.blockchain);
    _publicKey = this.blockchain.config.poolPublicKey;
  }

  FoxyPoolOG.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    if (object['walletBalance'] != null &&
        object['daysSinceLastBlock'] != null &&
        object['pendingBalance'] != null &&
        object['collateralBalance'] != null)
      _wallet = FoxyPoolWallet(
          double.parse(object['walletBalance'].toString()),
          double.parse(object['daysSinceLastBlock'].toString()),
          double.parse(object['pendingBalance'].toString()),
          double.parse(object['collateralBalance'].toString()),
          this.blockchain);
  }

  @override
  Map toJson() {
    Map farmerMap = (super.toJson());

    farmerMap.update("walletBalance", (value) => _wallet.balance);
    farmerMap.addEntries({
      'pendingBalance': _wallet.pendingBalance, //pending balance
      'collateralBalance': _wallet.collateralBalance //collateral balance
    }.entries);

    return farmerMap;
  }

  Future<void> init() async {
    FoxyPoolApi api = FoxyPoolApi();

    //parses foxypool api if that option is enabled
    if (blockchain.config.foxyPoolOverride)
      //tries to parse foxypool api
      await api.init(_publicKey, blockchain);

    //normal wallet + foxypool pending income + foxypool collateral balance
    _wallet = FoxyPoolWallet(
        super.wallet.balance,
        super.wallet.daysSinceLastBlock,
        api.pendingBalance,
        api.collateralBalance,
        this.blockchain);

    await super.init();
  }
}
