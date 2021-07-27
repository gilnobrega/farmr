import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:proper_filesize/proper_filesize.dart';

Logger log = Logger("FoxyPool API");

class FoxyPoolWallet extends GenericPoolWallet {
  final String publicKey;
  final bool og; //og uses chia-og/flax-og protocols

  FoxyPoolWallet(
      {required Blockchain blockchain,
      required this.publicKey,
      required this.og,
      String name = "FoxyPool Wallet"})
      : super(blockchain: blockchain, name: name);

  static String _foxyPoolUrl(String poolIdentifier, bool og) =>
      "https://api2.foxypool.io/api/v1/$poolIdentifier${(og) ? "-og" : ""}/account/";

  Future<void> init() async {
    if (publicKey != "") {
      try {
        String contents = await http.read(Uri.parse(
            _foxyPoolUrl("${blockchain.binaryName}", og) + publicKey));

        var data = jsonDecode(contents);

        if (data['error'] == null) {
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
            capacity =
                ProperFilesize.parseHumanReadableFilesize("${data['ec']} GiB")
                    .round();
          } catch (error) {
            log.warning("Error parsing FoxyPool info!");
            log.info(error.toString());
          }
        } else {
          log.warning(
              "Failed to get FoxyPool ${(og) ? "OG" : "NFT"} Balance, make sure your pool public key is correct.\nIgnore this error if you are not farming with FoxyPool ${(og) ? "OG" : "NFT"} protocol.");
          log.info(data['error'].toString());
        }
      } catch (e) {
        log.warning("Failed to reach FoxyPool API");
        log.info(e.toString());
      }
    }
  }
}
