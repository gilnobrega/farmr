import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';

import 'package:logging/logging.dart';

Logger log = Logger("Cold Wallet");

//Wallet that uses chiaexplorer/flaxexplorer/posat.io
class ColdWallet extends Wallet {
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
      double daysSinceLastBlock = -1,
      int syncedBlockHeight = -1,
      required Blockchain blockchain,
      String name = "Cold Wallet",
      String? address})
      : super(
            type: WalletType.Cold,
            blockchain: blockchain,
            daysSinceLastBlock: daysSinceLastBlock,
            syncedBlockHeight: syncedBlockHeight,
            name: name,
            addresses: (address != null) ? [address] : []);

  ColdWallet.fromJson(dynamic json) : super.fromJson(json) {
    grossBalance = json['grossBalance'] ?? -1;
    netBalance = json['netBalance'] ?? -1;
    farmedBalance = json['farmedBalance'] ?? -1;
  }

  ColdWallet operator *(ColdWallet wallet2) {
    if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
      return ColdWallet(
        blockchain: this.blockchain,
        netBalance: Wallet.sumTwoBalances(this.netBalance, wallet2.netBalance),
        grossBalance:
            Wallet.sumTwoBalances(this.grossBalance, wallet2.grossBalance),
        farmedBalance:
            Wallet.sumTwoBalances(this.farmedBalance, wallet2.farmedBalance),
        daysSinceLastBlock: Wallet.compareDaysSinceBlock(
            this.daysSinceLastBlock, wallet2.daysSinceLastBlock),
      );
    else
      throw Exception("Cannot combine cold wallets of different blockchains");
  }
}
