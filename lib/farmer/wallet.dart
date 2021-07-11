import 'package:farmr_client/blockchain.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

class Wallet {
  Blockchain blockchain;

  //wallet balance
  double _balance = -1.0; //-1.0 is default value if disabled
  double get balance => _balance; //hides balance if string

  int _walletHeight = 0;
  int get walletHeight => _walletHeight;

  int _syncedBlockHeight = 0;

  int _lastBlockFarmed = 0;

  double _daysSinceLastBlock = 0;
  double get daysSinceLastBlock => (_daysSinceLastBlock == 0)
      ? _estimateLastFarmedTime()
      : _daysSinceLastBlock;

  Wallet(this._balance, this._daysSinceLastBlock, this.blockchain,
      this._syncedBlockHeight, this._walletHeight);

  void parseWalletBalance(
      String binPath, int lastBlockFarmed, bool showWalletBalance) {
    _lastBlockFarmed = lastBlockFarmed;

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
        _balance =
            int.parse(walletRegex.firstMatch(walletOutput)?.group(2) ?? '-1') /
                1e12;
      } catch (e) {
        log.warning("Error: could not parse wallet balance.");
      }

      //tries to get synced wallet height
      try {
        RegExp walletHeightRegex =
            RegExp("Wallet height: ([0-9]+)", multiLine: false);
        _walletHeight = int.tryParse(
                walletHeightRegex.firstMatch(walletOutput)?.group(1) ?? '-1') ??
            -1;
      } catch (e) {
        log.warning("Error: could not parse wallet height");
      }
    }
  }

  double getCurrentEffort(double etw, double farmedTimeDays) {
    if (etw > 0 && daysSinceLastBlock > 0) {
      //if user has not found a block then it will assume that effort starts counting from when it began farming
      double percentage = (farmedTimeDays > daysSinceLastBlock)
          ? 100 * (daysSinceLastBlock / etw)
          : 100 * (farmedTimeDays / etw);
      return percentage;
    }
    return 0.0;
  }

  double _estimateLastFarmedTime() {
    int blockDiff = _syncedBlockHeight - _lastBlockFarmed;

    log.info("Last block farmed: " + _lastBlockFarmed.toString());

    int blocksPerDay = (blockchain.blocksPer10Mins * 6 * 24).round();

    //estimate of number of days ago, it tends to exaggerate
    double numberOfDays = (blockDiff / blocksPerDay);

    log.info("Days since last block: " + numberOfDays.toString());

    return numberOfDays;
  }

  //only updates last block farmed if it is a higher block than what's in local wallet
  void setLastBlockFarmed(int lastBlockFarmed) {
    if (lastBlockFarmed > _lastBlockFarmed) {
      _lastBlockFarmed = lastBlockFarmed;
      _daysSinceLastBlock = _estimateLastFarmedTime();
    }
  }

  //updates block n Days ago with a unix timestamp
  void setDaysAgoWithTimestamp(int blockTimestamp) {
    double daysSinceBlock = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(blockTimestamp))
            .inHours /
        24.0;

    if (daysSinceBlock < daysSinceLastBlock || daysSinceLastBlock < 0) {
      log.info("Days since last block: " + daysSinceBlock.toString());

      _daysSinceLastBlock = daysSinceBlock;
    }
  }
}
