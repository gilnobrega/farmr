import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/farmer/wallet.dart';

class FoxyPoolWallet extends Wallet {
  //pending balance
  double _pendingBalance = -1.0;
  double get pendingBalance => _pendingBalance;

  //collateral balance
  double _collateralBalance = -1.0;
  double get collateralBalance => _collateralBalance;

  FoxyPoolWallet(
      double balance,
      double daysSinceLastBlock,
      this._pendingBalance,
      this._collateralBalance,
      Blockchain blockchain,
      int syncedBlockHeight,
      int walletHeight)
      : super(balance, daysSinceLastBlock, blockchain, syncedBlockHeight,
            walletHeight);
}
