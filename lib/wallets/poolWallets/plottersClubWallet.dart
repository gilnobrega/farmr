import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

Logger log = Logger("Plotters.Club API");

class PlottersClubWallet extends GenericPoolWallet {
  final String poolPublicKey;

  PlottersClubWallet(
      {String name = "Plotters.Club Wallet",
      required this.poolPublicKey,
      required Blockchain blockchain})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      if (poolPublicKey != "") {
        const String mainUrl = r"https://api.plotters.club/farmerinfo/";

        String contents = await http.read(Uri.parse(mainUrl + poolPublicKey));

        var object = jsonDecode(contents);

        paidBalance =
            ((double.parse(object['xch_paid']?.toString() ?? "-1.0")) *
                    blockchain.majorToMinorMultiplier)
                .round();

        currentPoints = object['points'] ?? -1;
        totalPoints = object['overall_points'] ?? -1;
        capacity =
            (double.tryParse(object['capacityBytes']?.toString() ?? "-1.0") ??
                    -1.0)
                .round();

        difficulty = object['difficulty'] ?? -1;
      }
    } catch (error) {
      log.warning("Failed to get info from Plotters.Club API");
      log.warning(error.toString());
    }
  }
}
