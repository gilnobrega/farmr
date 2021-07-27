import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:proper_filesize/proper_filesize.dart';

Logger log = Logger("FoxyPool API");

enum FoxyPoolProtocol { OG, NFT }

class FoxyPoolWallet extends GenericPoolWallet {
  final String publicKey;
  final FoxyPoolProtocol protocol; //og uses chia-og/flax-og protocols

  FoxyPoolWallet(
      {required Blockchain blockchain,
      required this.publicKey,
      required this.protocol,
      String name = "FoxyPool Wallet"})
      : super(blockchain: blockchain, name: name);

  static String _foxyPoolUrl(
          String poolIdentifier, FoxyPoolProtocol protocol) =>
      "https://api2.foxypool.io/api/v1/$poolIdentifier${(protocol == FoxyPoolProtocol.OG) ? "-og" : ""}/account/";

  Future<void> init() async {
    if (publicKey != "") {
      try {
        String contents = await http.read(Uri.parse(
            _foxyPoolUrl("${blockchain.binaryName}", protocol) + publicKey));

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
              "Failed to get FoxyPool ${(protocol == FoxyPoolProtocol.OG) ? "OG" : "NFT"} Balance, make sure your pool public key or launcher_id is correct.");
          log.info(data['error'].toString());
        }
      } catch (e) {
        log.warning("Failed to reach FoxyPool API");
        log.info(e.toString());
      }
    }
  }
}
