import 'package:farmr_client/blockchain.dart';
import 'dart:math' as Math;

enum WalletType { Local, Cold, Pool }

class Wallet {
  //blockchain info
  late Blockchain blockchain;

  late final WalletType type;

  late int syncedBlockHeight;

  late double daysSinceLastBlock;

  late String name;

  late List<String> addresses;

  Wallet(
      {required this.type,
      required this.blockchain,
      this.syncedBlockHeight = -1,
      this.daysSinceLastBlock = -1,
      this.name = "Wallet",
      this.addresses = const []});

  Map toJson() => {
        'type': type.index,
        'majorToMinorMultiplier': blockchain.majorToMinorMultiplier,
        'currency': blockchain.currencySymbol,
        'name': name,
        'daysSinceLastBlock': daysSinceLastBlock.toStringAsFixed(1)
        //rounds days since last blocks so its harder to track wallets
        //precision of 0.1 days means uncertainty of 140 minutes
      };

  Wallet.fromJson(dynamic json) {
    addresses = []; //doesnt load addresses

    type = WalletType.values[json['type'] ?? 0];
    blockchain = Blockchain.fromSymbol(json['currency'] ?? "xch",
        majorToMinorMultiplier: double.tryParse(
                json['majorToMinorMultiplier']?.toString() ?? "1e12") ??
            1e12);
    daysSinceLastBlock =
        double.tryParse(json['daysSinceLastBlock'] ?? "-1.0") ?? -1.0;
    name = json['name'] ?? "${type.toString().split('.')[1]} Wallet";
  }

  Wallet operator +(Wallet wallet2) {
    if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
      return Wallet(
          type: type,
          blockchain: blockchain,
          syncedBlockHeight: -1,
          daysSinceLastBlock: compareDaysSinceBlock(
              this.daysSinceLastBlock, wallet2.daysSinceLastBlock));
    else
      throw Exception("Cannot combine wallets of different blockchains");
  }

  static double estimateLastFarmedTime(
      int syncedBlockHeight, int lastBlockFarmed, Blockchain blockchain) {
    int blockDiff = syncedBlockHeight - lastBlockFarmed;

    int blocksPerDay = (blockchain.blocksPer10Mins * 6 * 24).round();

    //estimate of number of days ago, it tends to exaggerate
    double numberOfDays = (blockDiff / blocksPerDay);

    return numberOfDays;
  }

  //only updates last block farmed if it is a higher block than what's in local wallet
  void setLastBlockFarmed(int lastBlockFarmed) {
    double daysSinceBlock = Wallet.estimateLastFarmedTime(
        syncedBlockHeight, lastBlockFarmed, blockchain);

    if (daysSinceBlock < daysSinceLastBlock || daysSinceLastBlock < 0)
      daysSinceLastBlock = daysSinceBlock;
  }

  //updates block n Days ago with a unix timestamp
  void setDaysAgoWithTimestamp(int blockTimestamp) {
    double daysSinceBlock = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(blockTimestamp))
            .inHours /
        24.0;

    if (daysSinceBlock < daysSinceLastBlock || daysSinceLastBlock < 0) {
      daysSinceLastBlock = daysSinceBlock;
    }
  }

  static double compareDaysSinceBlock(double day1, double day2) {
    if (day1 < 0)
      return day2;
    else if (day2 < 0)
      return day1;
    else
      return Math.min(day1, day2);
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

  //placeholder function, only used in cold wallets and pool wallets
  Future<void> init() async {}

  static int sumTwoBalances(balance1, balance2) {
    if (balance1 < 0 && balance2 >= 0)
      return balance2;
    else if (balance2 < 0 && balance1 >= 0)
      return balance1;
    else if (balance2 >= 0 && balance1 >= 0)
      return balance2 + balance1;
    else
      return -1;
  }

  static int minimumTwoBalances(balance1, balance2) {
    if (balance1 < 0 && balance2 >= 0)
      return balance2;
    else if (balance2 < 0 && balance1 >= 0)
      return balance1;
    else if (balance2 >= 0 && balance1 >= 0)
      return Math.min(balance1, balance2);
    else
      return -1;
  }

  static int maximumTwoBalances(balance1, balance2) {
    if (balance1 < 0 && balance2 >= 0)
      return balance2;
    else if (balance2 < 0 && balance1 >= 0)
      return balance1;
    else if (balance2 >= 0 && balance1 >= 0)
      return Math.max(balance1, balance2);
    else
      return -1;
  }
}
