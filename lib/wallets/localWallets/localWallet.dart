import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

enum LocalWalletStatus { Synced, Syncing, NotSynced }

class LocalWallet extends Wallet {
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

  LocalWallet(
      {this.confirmedBalance = -1,
      this.unconfirmedBalance = -1,
      int syncedBlockHeight = -1,
      required Blockchain blockchain,
      double daysSinceLastBlock = -1,
      this.walletHeight = -1,
      String name = "Local Wallet",
      this.status = LocalWalletStatus.Synced,
      String? address})
      : super(
            type: WalletType.Local,
            blockchain: blockchain,
            daysSinceLastBlock: daysSinceLastBlock,
            syncedBlockHeight: syncedBlockHeight,
            name: name,
            address: address);

  LocalWallet.fromJson(dynamic json) : super.fromJson(json) {
    confirmedBalance = json['confirmedBalance'] ?? -1;
    unconfirmedBalance = json['unconfirmedBalance'] ?? -1;
    walletHeight = json['walletHeight'] ?? -1;
    status = LocalWalletStatus.values[json['status'] ?? 0];
  }

  void parseWalletBalance(String binPath) {
    var walletOutput =
        io.Process.runSync(binPath, const ["wallet", "show"]).stdout.toString();

    try {
      //If user enabled showWalletBalance then parses ``chia wallet show``
      RegExp walletRegex = RegExp(
          "-Total Balance:(.*)${this.blockchain.currencySymbol.toLowerCase()} \\(([0-9]+) ${this.blockchain.minorCurrencySymbol.toLowerCase()}\\)",
          multiLine: false);

      //converts minor symbol to major symbol
      confirmedBalance = int.tryParse(
              walletRegex.firstMatch(walletOutput)?.group(2) ?? '-1') ??
          -1;
    } catch (e) {
      log.warning("Error: could not parse wallet balance.");
    }

    //tries to get synced wallet height
    try {
      RegExp walletHeightRegex =
          RegExp("Wallet height: ([0-9]+)", multiLine: false);
      walletHeight = int.tryParse(
              walletHeightRegex.firstMatch(walletOutput)?.group(1) ?? '-1') ??
          -1;
    } catch (e) {
      log.warning("Error: could not parse wallet height");
    }
  }

  LocalWallet operator *(LocalWallet wallet2) {
    if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
      return LocalWallet(
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
}
