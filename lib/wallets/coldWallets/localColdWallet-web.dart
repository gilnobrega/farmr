import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:logging/logging.dart';

Logger log = Logger("Local Cold Wallet");

class LocalColdWallet extends ColdWallet {
  final String address;
  final String rootPath;

  LocalColdWallet(
      {required Blockchain blockchain,
      required this.address,
      required this.rootPath,
      String name = "Local Cold Wallet"})
      : super(blockchain: blockchain, name: name);
}
