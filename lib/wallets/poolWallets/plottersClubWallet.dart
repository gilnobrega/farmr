import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("Plotters.Club API");

class PlottersClubWallet extends GenericPoolWallet {
  final String poolPublicKey;

  int _shares = 0;
  int get shares => _shares;

  int _effectiveCapacity = 0;
  int get effectiveCapacity => _effectiveCapacity;

  PlottersClubWallet(
      {int pendingBalance = -1,
      double majorToMinorMultiplier = 1e12,
      String name = "Plotters.Club Wallet",
      required this.poolPublicKey,
      required Blockchain blockchain})
      : super(
            pendingBalance: pendingBalance, blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      if (poolPublicKey != "") {
        const String mainUrl = r"https://api.plotters.club/farmerinfo/";

        String contents = await http.read(Uri.parse(mainUrl + poolPublicKey));

        var object = jsonDecode(contents);

        pendingBalance =
            ((double.parse(object['xch_paid']?.toString() ?? "-1.0")) *
                    blockchain.majorToMinorMultiplier)
                .round();
      }
    } catch (error) {
      log.warning("Failed to get info from Plotters.Club API");
      log.warning(error.toString());
    }
  }
}
