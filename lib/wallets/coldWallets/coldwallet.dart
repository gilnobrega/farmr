import 'package:farmr_client/blockchain.dart';

import 'package:logging/logging.dart';

Logger log = Logger("Cold Wallet");

//Wallet that uses chiaexplorer/flaxexplorer/posat.io
class ColdWallet {
  late Blockchain blockchain;

  //gross balance
  //CHIAEXPLORER ONLY
  late int grossBalance;
  double get grossBalanceMajor =>
      grossBalance * blockchain.majorToMinorMultiplier;

  //net balance
  late int netBalance;
  double get netBalanceMajor => netBalance * blockchain.majorToMinorMultiplier;

  //farmed balance
  //FLAX EXPLORER ONLY
  late int farmedBalance;
  double get farmedBalanceMajor =>
      farmedBalance * blockchain.majorToMinorMultiplier;

  Map toJson() => {
        "grossBalance": grossBalance,
        "netBalance": netBalance,
        "farmedBalance": farmedBalance,
        "majorToMinorMultiplier": blockchain.majorToMinorMultiplier,
        "majorCurrency": blockchain.currencySymbol
      };

  ColdWallet(
      {this.grossBalance = -1,
      this.netBalance = -1,
      this.farmedBalance = -1,
      required this.blockchain});

  ColdWallet.fromJson(dynamic json) {
    grossBalance = json['grossBalance'] ?? -1;
    netBalance = json['netBalance'] ?? -1;
    farmedBalance = json['farmedBalance'] ?? -1;
    blockchain = Blockchain.fromSymbol(json['majorCurrency'] ?? "xch",
        majorToMinorMultiplier: json['majortoMinorMultiplier'] ?? 1e12);
  }
}
