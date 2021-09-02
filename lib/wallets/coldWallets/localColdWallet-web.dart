import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:logging/logging.dart';

Logger log = Logger("Local Cold Wallet");

class LocalColdWallet extends ColdWallet {
  final String rootPath;
  bool success = true;

  LocalColdWallet(
      {required Blockchain blockchain,
      required String address,
      required this.rootPath,
      String name = "Local Cold Wallet"})
      : super(blockchain: blockchain, name: name, address: address);
}
