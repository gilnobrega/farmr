import 'package:farmr_client/blockchain.dart';

enum WalletType { Local, Cold, Pool }

class Wallet {
  //blockchain info
  late Blockchain blockchain;

  late final WalletType type;

  late int syncedBlockHeight;

  late double daysSinceLastBlock;

  Wallet(
      {required this.type,
      required this.blockchain,
      this.syncedBlockHeight = -1,
      this.daysSinceLastBlock = -1});

  Map toJson() => {
        'type': type.index,
        'majorToMinorMultiplier': blockchain.majorToMinorMultiplier,
        'currency': blockchain.currencySymbol
      };

  Wallet.fromJson(dynamic json) {
    type = WalletType.values[json['type'] ?? 0];
    blockchain = Blockchain.fromSymbol(json['currency'] ?? "xch",
        majorToMinorMultiplier: json['majorToMinorMultiplier'] ?? 1e12);
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
}
