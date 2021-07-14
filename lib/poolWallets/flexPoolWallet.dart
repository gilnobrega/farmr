import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("Flexpool API");

class FlexpoolWallet extends GenericPoolWallet {
  int _shares = 0;
  int get shares => _shares;

  int _effectiveCapacity = 0;
  int get effectiveCapacity => _effectiveCapacity;

  FlexpoolWallet(
      double balance,
      double daysSinceLastBlock,
      double pendingBalance,
      Blockchain blockchain,
      int syncedBlockHeight,
      int walletHeight)
      : super(balance, daysSinceLastBlock, pendingBalance, -1.0, blockchain,
            syncedBlockHeight, walletHeight);

  Future<void> init() async {
    try {
      if (blockchain.config.flexPoolAddress != "") {
        const String mainUrl =
            "https://api.flexpool.io/v2/miner/balance?coin=xch&address=";

        String contents = await http
            .read(Uri.parse(mainUrl + blockchain.config.flexPoolAddress));

        var object = jsonDecode(contents);

        if (object['error'] == null) {
          if (object['result'] != null && object['result']['balance'] != null)
            pendingBalance =
                double.tryParse(object['result']['balance'].toString()) ?? -1.0;
        } else if (object['error']) throw Exception(object['error']);
      }
    } catch (error) {
      log.warning("Failed to get info from Flexpool API");
      log.warning(error.toString());
    }
  }
}
