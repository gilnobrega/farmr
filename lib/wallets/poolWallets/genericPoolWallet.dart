import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/wallet.dart';

class GenericPoolWallet extends Wallet {
  //pending balance in MOJO
  late int pendingBalance;
  double get pendingBalanceMajor =>
      pendingBalance / blockchain.majorToMinorMultiplier;

  //pending balance in MOJO
  late int paidBalance;
  double get paidBalanceMajor =>
      paidBalance / blockchain.majorToMinorMultiplier;

  //collateral balance in MOJO
  late int collateralBalance;
  double get collateralBalanceMajor =>
      collateralBalance / blockchain.majorToMinorMultiplier;

  late int currentPoints; //points in current share window
  late int totalPoints; //total points since user began farming in pool

  //effective capacity of plots in pool in bytes
  late int capacity;
  late int difficulty;

  late int lastPartial; //last partial in unix time

  GenericPoolWallet(
      {this.collateralBalance = -1,
      this.pendingBalance = -1,
      this.paidBalance = -1,
      this.currentPoints = -1,
      this.totalPoints = -1,
      this.capacity = -1,
      this.difficulty = -1,
      this.lastPartial = -1,
      required Blockchain blockchain,
      String name = "Pool Wallet"})
      : super(type: WalletType.Pool, blockchain: blockchain, name: name);

  @override
  Map toJson() {
    Map<dynamic, dynamic> walletMap = super.toJson();

    walletMap.addAll({
      'pendingBalance': pendingBalance,
      'collateralBalance': collateralBalance,
      'paidBalance': paidBalance,
      'currentPoints': currentPoints,
      'totalPoints': totalPoints,
      'capacity': capacity,
      'difficulty': difficulty,
      'lastPartial': lastPartial
    });
    return walletMap;
  }

  GenericPoolWallet.fromJson(dynamic json) : super.fromJson(json) {
    collateralBalance = json['collateralBalance'] ?? -1;
    pendingBalance = json['pendingBalance'] ?? -1;
    paidBalance = json['paidBalance'] ?? -1;
    currentPoints = json['currentPoints'] ?? -1;
    totalPoints = json['totalPoints'] ?? -1;
    capacity = json['capacity'] ?? -1;
    difficulty = json['difficulty'] ?? -1;
    lastPartial = json['lastPartial'] ?? -1;
  }

  GenericPoolWallet operator *(GenericPoolWallet wallet2) {
    if (this.blockchain.currencySymbol == wallet2.blockchain.currencySymbol)
      return GenericPoolWallet(
          blockchain: blockchain,
          pendingBalance: Wallet.sumTwoBalances(
              this.pendingBalance, wallet2.pendingBalance),
          collateralBalance: Wallet.sumTwoBalances(
              this.collateralBalance, wallet2.collateralBalance),
          paidBalance:
              Wallet.sumTwoBalances(this.paidBalance, wallet2.paidBalance),
          currentPoints:
              Wallet.sumTwoBalances(this.currentPoints, wallet2.currentPoints),
          totalPoints:
              Wallet.sumTwoBalances(this.totalPoints, wallet2.totalPoints),
          capacity: Wallet.sumTwoBalances(this.capacity, wallet2.capacity));
    else
      throw Exception("Cannot combine pool wallets of different blockchains");
  }
}
