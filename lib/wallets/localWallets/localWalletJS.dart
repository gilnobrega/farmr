import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/localWallets/localWalletStruct.dart';

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

class LocalWallet extends LocalWalletStruct {
  LocalWallet(
      {int confirmedBalance = -1,
      int unconfirmedBalance = -1,
      int syncedBlockHeight = -1,
      required Blockchain blockchain,
      double daysSinceLastBlock = -1,
      int walletHeight = -1,
      String name = "Local Wallet",
      LocalWalletStatus status = LocalWalletStatus.Synced,
      int? fingerprint,
      List<String> addresses = const []})
      : super(
            confirmedBalance: confirmedBalance,
            unconfirmedBalance: unconfirmedBalance,
            walletHeight: walletHeight,
            fingerprint: fingerprint,
            blockchain: blockchain,
            daysSinceLastBlock: daysSinceLastBlock,
            syncedBlockHeight: syncedBlockHeight,
            name: name,
            addresses: addresses);

  LocalWallet.fromJson(dynamic json) : super.fromJson(json);
}
