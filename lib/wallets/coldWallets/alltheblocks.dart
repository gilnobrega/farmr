import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("AllTheBlocks Wallet");

class AllTheBlocksWallet extends ColdWallet {
  static const String _allTheBlocksURL = "https://api.alltheblocks.net/";
  final String address;

  AllTheBlocksWallet(
      {required Blockchain blockchain,
      required this.address,
      String name = "AllTheBlocks Cold Wallet"})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      String contents = await http.read(Uri.parse(_allTheBlocksURL +
          "${blockchain.allTheBlocksName}/address/" +
          address));

      var object = jsonDecode(contents);

      netBalance = object['balance'] ?? -1;

      String coins = await http.read(Uri.parse(_allTheBlocksURL +
          "${blockchain.allTheBlocksName}/coin/address/" +
          address));

      var coinsObject = jsonDecode(coins);

      for (int i = 0;
          coinsObject['content'] != null && i < coinsObject['content'].length;
          i++) {
        var coin = coinsObject['content'][i];
        if (coin['coinbase'] &&
            int.tryParse(coin['timestamp'].toString()) != null)
          setDaysAgoWithTimestamp(
              int.parse(coin['timestamp'].toString()) * 1000);
      }
    } catch (error) {
      log.warning(
          "Failed to get info about ${blockchain.binaryName} cold wallet");
    }
  }
}
