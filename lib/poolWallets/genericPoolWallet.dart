import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/farmer/wallet.dart';

class GenericPoolWallet extends Wallet {
  //pending balance
  double pendingBalance = -1.0;

  //collateral balance
  double collateralBalance = -1.0;

  GenericPoolWallet(
      double balance,
      double daysSinceLastBlock,
      this.pendingBalance,
      this.collateralBalance,
      Blockchain blockchain,
      int syncedBlockHeight,
      int walletHeight)
      : super(balance, daysSinceLastBlock, blockchain, syncedBlockHeight,
            walletHeight);
}
