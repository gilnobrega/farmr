import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';

class GenericPoolWallet extends Wallet {
  //pending balance in MOJO
  late int pendingBalance;
  double get pendingBalanceMajor =>
      pendingBalance / blockchain.majorToMinorMultiplier;

  //collateral balance in MOJO
  late int collateralBalance;
  double get collateralBalanceMajor =>
      collateralBalance / blockchain.majorToMinorMultiplier;

  GenericPoolWallet(
      {this.collateralBalance = -1,
      this.pendingBalance = -1,
      required Blockchain blockchain,
      String name = "Pool Wallet"})
      : super(type: WalletType.Pool, blockchain: blockchain, name: name);

  @override
  Map toJson() {
    Map<dynamic, dynamic> walletMap = super.toJson();

    walletMap.addAll({
      'pendingBalance': pendingBalance,
      'collateralBalance': collateralBalance
    });
    return walletMap;
  }

  GenericPoolWallet.fromJson(dynamic json) : super.fromJson(json) {
    collateralBalance = json['collateralBalance'] ?? -1.0;
    pendingBalance = json['pendingBalance'] ?? -1.0;
  }

  @override
  Wallet operator +(Wallet wallet2) {
    if (wallet2 is GenericPoolWallet) {
      if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
        return GenericPoolWallet(
            blockchain: blockchain,
            pendingBalance: this.pendingBalance + wallet2.pendingBalance,
            collateralBalance:
                ((this.collateralBalance > 0) ? this.collateralBalance : 0) +
                    ((wallet2.collateralBalance > 0)
                        ? wallet2.collateralBalance
                        : 0));
      else
        throw Exception("Cannot combine pool wallets of different blockchains");
    } else
      return (this as Wallet) + wallet2;
  }
}
