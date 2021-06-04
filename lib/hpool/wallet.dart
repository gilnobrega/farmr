import 'package:chiabot/farmer/wallet.dart';

class HPoolWallet extends Wallet {
  double _undistributedBalance = -1.0;
  double get undistributedBalance => _undistributedBalance;

  HPoolWallet(double balance, this._undistributedBalance) : super(balance, 0);
}
