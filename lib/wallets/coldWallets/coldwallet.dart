import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';

import 'package:logging/logging.dart';

Logger log = Logger("Cold Wallet");

//Wallet that uses chiaexplorer/flaxexplorer/posat.io
class ColdWallet extends Wallet {
  late Blockchain blockchain;

  //gross balance
  //CHIAEXPLORER ONLY
  late int grossBalance;
  double get grossBalanceMajor =>
      grossBalance / blockchain.majorToMinorMultiplier;

  //net balance
  late int netBalance;
  double get netBalanceMajor => netBalance / blockchain.majorToMinorMultiplier;

  //farmed balance
  //FLAX EXPLORER ONLY
  late int farmedBalance;
  double get farmedBalanceMajor =>
      farmedBalance / blockchain.majorToMinorMultiplier;

  @override
  Map toJson() {
    Map<dynamic, dynamic> walletMap = super.toJson();

    walletMap.addAll({
      "grossBalance": grossBalance,
      "netBalance": netBalance,
      "farmedBalance": farmedBalance,
    });
    return walletMap;
  }

  ColdWallet(
      {this.grossBalance = -1,
      this.netBalance = -1,
      this.farmedBalance = -1,
      required Blockchain blockchain})
      : super(type: WalletType.Cold, blockchain: blockchain);

  ColdWallet.fromJson(dynamic json) : super.fromJson(json) {
    grossBalance = json['grossBalance'] ?? -1;
    netBalance = json['netBalance'] ?? -1;
    farmedBalance = json['farmedBalance'] ?? -1;
  }
}
