import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

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
      {int pendingBalance = -1,
      double majorToMinorMultiplier = 1e12,
      required Blockchain blockchain})
      : super(pendingBalance: pendingBalance, blockchain: blockchain);

  Future<void> init() async {
    try {
      if (blockchain.config.flexPoolAddress != "") {
        const String mainUrl =
            r"https://api.flexpool.io/v2/miner/balance?coin=xch&address=";

        String contents = await http
            .read(Uri.parse(mainUrl + blockchain.config.flexPoolAddress));

        var object = jsonDecode(contents);

        if (object['error'] == null) {
          if (object['result'] != null && object['result']['balance'] != null)
            //balance is in mojo, not xch, so it converts mojo to xch then makes sure its rounded to 12 decimals
            pendingBalance =
                int.tryParse(object['result']['balance'].toString()) ?? -1;
        } else if (object['error']) throw Exception(object['error']);
      }
    } catch (error) {
      log.warning("Failed to get info from Flexpool API");
      log.warning(error.toString());
    }
  }
}
