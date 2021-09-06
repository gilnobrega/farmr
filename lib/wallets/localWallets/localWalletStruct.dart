import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

enum LocalWalletStatus { Synced, Syncing, NotSynced }

class LocalWalletStruct extends Wallet {
  //wallet balance
  int get balance => confirmedBalance; //-1.0 is default value if disabled
  double get balanceMajor => balance / blockchain.majorToMinorMultiplier;

  late int confirmedBalance;
  double get confirmedBalanceMajor =>
      confirmedBalance / blockchain.majorToMinorMultiplier;

  late int unconfirmedBalance;
  double get unconfirmedBalanceMajor =>
      unconfirmedBalance / blockchain.majorToMinorMultiplier;

  late int walletHeight;

  late LocalWalletStatus status;

  int? fingerprint;

  @override
  Map toJson() {
    Map<dynamic, dynamic> walletMap = super.toJson();

    walletMap.addAll({
      "confirmedBalance": confirmedBalance,
      "unconfirmedBalance": unconfirmedBalance,
      "walletHeight": walletHeight,
      "status": status.index
    });
    return walletMap;
  }

  LocalWalletStruct(
      {this.confirmedBalance = -1,
      this.unconfirmedBalance = -1,
      int syncedBlockHeight = -1,
      required Blockchain blockchain,
      double daysSinceLastBlock = -1,
      this.walletHeight = -1,
      String name = "Local Wallet",
      this.status = LocalWalletStatus.Synced,
      this.fingerprint,
      List<String> addresses = const []})
      : super(
            type: WalletType.Local,
            blockchain: blockchain,
            daysSinceLastBlock: daysSinceLastBlock,
            syncedBlockHeight: syncedBlockHeight,
            name: name,
            addresses: addresses);

  LocalWalletStruct.fromJson(dynamic json) : super.fromJson(json) {
    confirmedBalance = json['confirmedBalance'] ?? -1;
    unconfirmedBalance = json['unconfirmedBalance'] ?? -1;
    walletHeight = json['walletHeight'] ?? -1;
    status = LocalWalletStatus.values[json['status'] ?? 0];
  }

  LocalWalletStruct operator *(LocalWalletStruct wallet2) {
    if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
      return LocalWalletStruct(
          blockchain: blockchain,
          confirmedBalance: Wallet.sumTwoBalances(
              this.confirmedBalance, wallet2.unconfirmedBalance),
          unconfirmedBalance: Wallet.sumTwoBalances(
              this.unconfirmedBalance, wallet2.unconfirmedBalance),
          walletHeight: this.walletHeight,
          daysSinceLastBlock: Wallet.compareDaysSinceBlock(
              this.daysSinceLastBlock, wallet2.daysSinceLastBlock));
    else
      throw Exception("Cannot combine local wallets of different blockchains");
  }

  void getAllAddresses() {}
  void parseWalletBalance(String binPath) {}
}
