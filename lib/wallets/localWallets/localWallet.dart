import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

class LocalWallet extends Wallet {
  //wallet balance
  int balance; //-1.0 is default value if disabled
  double get balanceMajor => balance / blockchain.majorToMinorMultiplier;

  late int walletHeight;

  LocalWallet(
      {this.balance = -1,
      int syncedBlockHeight = -1,
      required Blockchain blockchain,
      double daysSinceLastBlock = -1,
      this.walletHeight = -1})
      : super(
            type: WalletType.Local,
            blockchain: blockchain,
            daysSinceLastBlock: daysSinceLastBlock,
            syncedBlockHeight: syncedBlockHeight);

  void parseWalletBalance(
      String binPath, int lastBlockFarmed, bool showWalletBalance) {
    setLastBlockFarmed(lastBlockFarmed);

    if (showWalletBalance) {
      var walletOutput = io.Process.runSync(binPath, const ["wallet", "show"])
          .stdout
          .toString();

      try {
        //If user enabled showWalletBalance then parses ``chia wallet show``
        RegExp walletRegex = RegExp(
            "-Total Balance:(.*)${this.blockchain.currencySymbol.toLowerCase()} \\(([0-9]+) ${this.blockchain.minorCurrencySymbol.toLowerCase()}\\)",
            multiLine: false);
        //converts minor symbol to major symbol
        balance =
            int.parse(walletRegex.firstMatch(walletOutput)?.group(2) ?? '-1');
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
  }

  @override
  Wallet operator +(Wallet wallet2) {
    if (wallet2 is LocalWallet) {
      if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
        return LocalWallet(
            blockchain: blockchain,
            balance: (this.balance >= 0 && wallet2.balance >= 0)
                ? this.balance + wallet2.balance
                : 0,
            walletHeight: this.walletHeight,
            daysSinceLastBlock: Wallet.compareDaysSinceBlock(
                this.daysSinceLastBlock, wallet2.daysSinceLastBlock));
      else
        throw Exception(
            "Cannot combine local wallets of different blockchains");
    } else
      return (this as Wallet) + wallet2;
  }
}
