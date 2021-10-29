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

  static const String mainUrl = r"https://developer.pool.space/api/v1/farms/";

  static const magicArray1 = [
    68,
    101,
    118,
    101,
    108,
    111,
    112,
    101,
    114,
    45,
    75,
    101,
    121
  ];

  static const magicArray2 = [
    89,
    79,
    121,
    65,
    90,
    116,
    110,
    122,
    49,
    116,
    120,
    106,
    66,
    97,
    115,
    117,
    71,
    105,
    107,
    113,
    84,
    49,
    56,
    69,
    80,
    113,
    86,
    100,
    89,
    107,
    89,
    106,
    100,
    78,
    57,
    117,
    113,
    84,
    88,
    111,
    114,
    53,
    49,
    106,
    118,
    121,
    74,
    109,
    97,
    113,
    106,
    67,
    83,
    71,
    78,
    54,
    117,
    54,
    120,
    83,
    116,
    69,
    97,
    103
  ];

  Future<void> init() async {
    try {
      if (poolPublicKey != "") {
        final Map<String, String> headers = {
          "Accept": "text/plain",
          utf8.decode(magicArray1): utf8.decode(magicArray2)
        };

        String contents = await http.read(Uri.parse(mainUrl + poolPublicKey),
            headers: headers);

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

        //totalPoints = object['totalPoints'] ?? -1;
        //Deprecated

        capacity = ProperFilesize.parseHumanReadableFilesize(
                "${object['estimatedPlotSizeTiB']?.toString() ?? "-1"} TiB")
            .round();

        difficulty = object['difficulty'] ?? -1;
      }
    } catch (error) {
      log.warning("Failed to get info from SpacePool API");
      log.warning(error.toString());
    }
  }
}
