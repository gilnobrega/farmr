import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:proper_filesize/proper_filesize.dart';

Logger log = Logger("SpacePool API");

class SpacePoolWallet extends GenericPoolWallet {
  final String poolPublicKey;

  SpacePoolWallet(
      {String name = "SpacePool Wallet",
      required this.poolPublicKey,
      required Blockchain blockchain})
      : super(blockchain: blockchain, name: name);

  static const String mainUrl = r"https://pool.space/api/farms/";

  Future<void> init() async {
    try {
      if (poolPublicKey != "") {
        String contents = await http.read(Uri.parse(mainUrl + poolPublicKey));

        var object = jsonDecode(contents);

        pendingBalance = ((double.parse(
                    object['unpaidBalanceInXCH']?.toString() ?? "-1.0")) *
                blockchain.majorToMinorMultiplier)
            .round();

        paidBalance =
            ((double.parse(object['totalPaidInXCH']?.toString() ?? "-1.0")) *
                    blockchain.majorToMinorMultiplier)
                .round();

        currentPoints = object['pendingPoints'] ?? -1;
        totalPoints = object['totalPoints'] ?? -1;
        capacity = ProperFilesize.parseHumanReadableFilesize(
                "${object['estimatedPlotSizeTiB']?.toString() ?? "-1"} TiB")
            .round();
      }
    } catch (error) {
      log.warning("Failed to get info from SpacePool API");
      log.warning(error.toString());
    }
  }
}
