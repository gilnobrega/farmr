import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/localWallets/localWallet.dart';

class HPoolWallet extends LocalWallet {
  double _undistributedBalance = -1.0;
  double get undistributedBalance => _undistributedBalance;

  HPoolWallet(int balance, this._undistributedBalance, Blockchain blockchain)
      : super(balance: balance, blockchain: blockchain);
}
