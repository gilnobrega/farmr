import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:proper_filesize/proper_filesize.dart';

Logger log = Logger("Elysium Pool API");

class ElysiumPoolWallet extends GenericPoolWallet {
  final String launcherID;

  ElysiumPoolWallet(
      {String name = "Elysium Pool Wallet",
      required this.launcherID,
      required Blockchain blockchain})
      : super(blockchain: blockchain, name: name);

  static const String mainUrl =
      r"https://app.elysiumpool.com/public_api/v1/farmer/";

  Future<void> init() async {
    try {
      if (launcherID != "") {
        final id = (launcherID.contains("0x"))
            ? launcherID.replaceFirst("0x", "")
            : launcherID;

        String contents =
            await http.read(Uri.parse(mainUrl + id + r"/?format=json"));

        var object = jsonDecode(contents);

        paidBalance = object['paid_mojo'] ?? -1;

        currentPoints = object['points'] ?? -1;
        difficulty = object['difficulty'] ?? -1;

        if (object['my_space_tib'] != null)
          capacity = ProperFilesize.parseHumanReadableFilesize(
                  "${object['my_space_tib'].toString()} TiB")
              .round();

        lastPartial = object['my_last_partial_submitted_utc'] ?? -1;
      }
    } catch (error) {
      log.warning("Failed to get info from Elysium Pool API");
      log.warning(error.toString());
    }
  }
}
