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
      {int netBalance = -1,
      required Blockchain blockchain,
      required this.address,
      String name = "AllTheBlocks Cold Wallet"})
      : super(netBalance: netBalance, blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      String contents = await http.read(Uri.parse(
          _allTheBlocksURL + "${blockchain.binaryName}/address/" + address));

      var object = jsonDecode(contents);

      netBalance = object['balance'] ?? -1;

      String coins = await http.read(Uri.parse(_allTheBlocksURL +
          "${blockchain.binaryName}/coin/address/" +
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
      //404 error means wallet is empty
      if (error is http.ClientException && error.toString().contains("404")) {
        //if wallet is empty then assumes both gross balance and net balance are 0
        grossBalance = 0;
        netBalance = 0;
      } else {
        log.warning(
            "Failed to get info about ${blockchain.binaryName} cold wallet");
      }
    }
  }
}
