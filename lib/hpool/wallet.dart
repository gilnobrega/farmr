import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/localWallets/wallet.dart';

class HPoolWallet extends Wallet {
  double _undistributedBalance = -1.0;
  double get undistributedBalance => _undistributedBalance;

  HPoolWallet(double balance, this._undistributedBalance, Blockchain blockchain)
      : super(balance, -1.0, blockchain, -1, -1);
}
