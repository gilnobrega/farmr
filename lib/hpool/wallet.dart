import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/localWallets/localWalletJS.dart'
    if (dart.library.io) 'package:farmr_client/wallets/localWallets/localWalletIO.dart';

class HPoolWallet extends LocalWallet {
  double _undistributedBalance = -1.0;
  double get undistributedBalance => _undistributedBalance;

  HPoolWallet(double balance, this._undistributedBalance, Blockchain blockchain)
      : super(
            confirmedBalance:
                (balance * blockchain.majorToMinorMultiplier).round(),
            blockchain: blockchain);
}
