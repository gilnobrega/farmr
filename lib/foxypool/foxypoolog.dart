import 'dart:convert';

import 'package:farmr_client/config.dart';
import 'package:farmr_client/farmer/wallet.dart';
import 'package:farmr_client/foxypool/api.dart';
import 'package:farmr_client/foxypool/wallet.dart';
import 'package:farmr_client/farmer/farmer.dart';
import 'package:farmr_client/debug.dart' as Debug;

class FoxyPoolOG extends Farmer {
  //public pool key
  String _publicKey = '';

  FoxyPoolWallet _wallet = FoxyPoolWallet(-1.0, 0, -1.0, -1.0);
  @override
  Wallet get wallet => _wallet;

  @override
  final ClientType type = ClientType.FoxyPoolOG;

  FoxyPoolOG(
      {required Config config, required Debug.Log log, String version = ''})
      : super(config: config, log: log, version: version, hpool: false) {
    _publicKey = config.poolPublicKey;
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
          double.parse(object['collateralBalance'].toString()));
  }

  @override
  Map toJson() {
    Map farmerMap = (super.toJson());

    farmerMap.update("walletBalance", (value) => _wallet.balance);
    farmerMap.update(
        "daysSinceLastBlock", (value) => _wallet.daysSinceLastBlock);

    farmerMap.addEntries({
      'pendingBalance': _wallet.pendingBalance, //pending balance
      'collateralBalance': _wallet.collateralBalance //collateral balance
    }.entries);

    return farmerMap;
  }

  Future<void> init(String chiaConfigPath) async {
    super.init(chiaConfigPath);

    //tries to parse hpool api
    FoxyPoolApi api = FoxyPoolApi();
    await api.init(_publicKey);

    //normal wallet + foxypool pening income + foxypool collateral balance
    _wallet = FoxyPoolWallet(
        super.wallet.balance,
        super.wallet.daysSinceLastBlock,
        api.pendingBalance,
        api.collateralBalance);

    await super.init(chiaConfigPath);
  }
}
