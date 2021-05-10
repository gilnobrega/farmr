import 'dart:io' as io;

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

class Wallet {
  //wallet balance
  double _balance = -1.0; //-1.0 is default value if disabled
  double get balance => _balance; //hides balance if string

  //final DateTime currentTime = DateTime.now();
  int _syncedBlockHeight = 0;

  int _lastBlockFarmed = 0;

  double _daysSinceLastBlock = 0;
  double get daysSinceLastBlock =>
      (_daysSinceLastBlock == 0) ? _estimateLastFarmedTime() : _daysSinceLastBlock;

  Wallet(this._balance, this._daysSinceLastBlock);

  void parseWalletBalance(String binPath, int lastBlockFarmed) {
    _lastBlockFarmed = lastBlockFarmed;

    try {
      var walletOutput = io.Process.runSync(binPath, ["wallet", "show"]).stdout.toString();

      RegExp walletRegex = RegExp("-Total Balance: ([0-9\\.]+)", multiLine: false);

      _balance = double.parse(walletRegex.firstMatch(walletOutput).group(1));

      RegExp walletHeightRegex = RegExp("Wallet height: ([0-9]+)", multiLine: false);
      _syncedBlockHeight = int.parse(walletHeightRegex.firstMatch(walletOutput).group(1));
    } catch (e) {
      log.warning("Error: could not parse wallet balance.");
    }
  }

  double getCurrentEffort(double etw, double farmedTimeDays) {
    if (etw > 0 && daysSinceLastBlock > 0) {
      //if user has not found a block then it will assume that effort starts counting from when it began farming
      double percentage = (farmedTimeDays > daysSinceLastBlock) ? 100 * (daysSinceLastBlock / etw) : 100*(farmedTimeDays/etw);
      return percentage;
    }
    return 0.0;
  }

  double _estimateLastFarmedTime() {
    int blockDiff = _syncedBlockHeight - _lastBlockFarmed;

    int blocksPerDay = 32 * 6 * 24;

    //estimate of number of days ago, it tends to exaggerate
    double numberOfDays = (blockDiff / blocksPerDay);

    return numberOfDays;
  }
}
