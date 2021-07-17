import 'package:farmr_client/blockchain.dart';

class GenericPoolWallet {
  //blockchain info
  late Blockchain blockchain;

  //pending balance in MOJO
  late int pendingBalance;
  double get pendingBalanceMajor =>
      pendingBalance * blockchain.majorToMinorMultiplier;

  //collateral balance in MOJO
  late int collateralBalance;
  double get collateralBalanceMajor =>
      collateralBalance * blockchain.majorToMinorMultiplier;

  GenericPoolWallet(
      {this.collateralBalance = -1,
      this.pendingBalance = -1,
      required this.blockchain});

  Map toJson() => {
        'pendingBalance': pendingBalance,
        'collateralBalance': collateralBalance,
        'majorToMinorMultiplier': blockchain.majorToMinorMultiplier,
        'majorCurrency': blockchain.currencySymbol
      };

  GenericPoolWallet.fromJson(dynamic json) {
    collateralBalance = json['collateralBalance'] ?? -1.0;
    pendingBalance = json['pendingBalance'] ?? -1.0;
    blockchain = Blockchain.fromSymbol(json['majorCurrency'] ?? "xch",
        majorToMinorMultiplier: json['majorToMinorMultiplier'] ?? 1e12);
  }
}
