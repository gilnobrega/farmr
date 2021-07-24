import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("Flexpool API");

class FlexpoolWallet extends GenericPoolWallet {
  final String address;

  FlexpoolWallet(
      {String name = "Flexpool Wallet",
      required this.address,
      required Blockchain blockchain})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      if (address != "") {
        const String mainUrlBalance =
            r"https://api.flexpool.io/v2/miner/balance?coin=xch&address=";

        String contents = await http.read(Uri.parse(mainUrlBalance + address));

        var object = jsonDecode(contents);

        if (object['error'] == null) {
          if (object['result'] != null && object['result']['balance'] != null)
            //balance is in mojo, not xch, so it converts mojo to xch then makes sure its rounded to 12 decimals
            pendingBalance =
                int.tryParse(object['result']['balance'].toString()) ?? -1;
        } else if (object['error']) throw Exception(object['error']);

        const String mainUrlShares =
            r"https://api.flexpool.io/v2/miner/stats?coin=xch&address=";

        String contents2 = await http.read(Uri.parse(mainUrlShares + address));

        var object2 = jsonDecode(contents2);

        if (object2['error'] == null) {
          capacity = object2['averageEffectiveHashrate'] ?? -1;
          currentPoints = object2['validShares'] ?? -1;
        } else if (object2['error']) throw Exception(object2['error']);
      }
    } catch (error) {
      log.warning("Failed to get info from Flexpool API");
      log.warning(error.toString());
    }
  }
}
