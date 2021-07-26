import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:farmr_client/server/netspace.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

Logger log = Logger("FoxyPool API");

class FoxyPoolWallet extends GenericPoolWallet {
  String publicKey;

  FoxyPoolWallet(
      {required Blockchain blockchain,
      required this.publicKey,
      String name = "FoxyPool Wallet"})
      : super(blockchain: blockchain, name: name);

  static String _foxyPoolUrl(String poolIdentifier) =>
      "https://api2.foxypool.io/api/v1/$poolIdentifier/account/";

  Future<void> init() async {
    if (publicKey != "") {
      //appends 0x at beginning of public key if it doesnt start with it
      if (!publicKey.startsWith("0x")) publicKey = "0x$publicKey";

      try {
        String contents = await http.read(
            Uri.parse(_foxyPoolUrl("${blockchain.binaryName}-og") + publicKey));

        var data = jsonDecode(contents);

        try {
          pendingBalance =
              (double.parse(data['pending']?.toString() ?? "-1.0") *
                      blockchain.majorToMinorMultiplier)
                  .round();
          collateralBalance =
              (double.parse(data['collateral']?.toString() ?? "-1.0") *
                      blockchain.majorToMinorMultiplier)
                  .round();
          currentPoints = data['shares'] ?? -1;
          capacity = NetSpace.sizeStringToInt("${data['ec']} GiB").round();
        } catch (error) {
          log.warning("Error parsing FoxyPool info!");
          log.info(error.toString());
        }
      } catch (e) {
        log.warning(
            "Failed to get FoxyPool Info, make sure your pool public key is correct.");
      }
    }
  }
}
