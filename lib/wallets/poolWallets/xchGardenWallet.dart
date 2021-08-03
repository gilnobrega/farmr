import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:proper_filesize/proper_filesize.dart';

Logger log = Logger("XCH Garden API");

class XchGardenWallet extends GenericPoolWallet {
  final String poolPublicKey;

  XchGardenWallet(
      {String name = "XCH Garden Wallet",
      required this.poolPublicKey,
      required Blockchain blockchain})
      : super(blockchain: blockchain, name: name);

  static const String mainUrl = r"https://api.xch.garden/user/";

  Future<void> init() async {
    try {
      if (poolPublicKey != "") {
        String contents = await http.read(Uri.parse(mainUrl + poolPublicKey));

        var object = jsonDecode(contents);

        paidBalance = int.parse(object['paidTotal']?.toString() ?? "-1");

        currentPoints = object['points'] ?? -1;
        capacity = ProperFilesize.parseHumanReadableFilesize(
                "${object['netspace']?.toString() ?? "-1"} TiB")
            .round();
      }
    } catch (error) {
      log.warning("Failed to get info from XCH Garden API");
      log.warning(error.toString());
    }
  }
}
