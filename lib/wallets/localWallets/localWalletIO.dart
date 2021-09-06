import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/utils/sqlite.dart';
import 'package:farmr_client/wallets/localWallets/localWalletStruct.dart';
import 'package:hex/hex.dart';
import 'package:universal_io/io.dart' as io;

import 'dart:io' as io;
import 'package:sqlite3/sqlite3.dart'; //sqlite library

import 'package:bech32m/bech32m.dart'; //puzzle hash library

import 'package:logging/logging.dart';

final log = Logger('FarmerWallet');

class LocalWallet extends LocalWalletStruct {
  LocalWallet(
      {int confirmedBalance = -1,
      int unconfirmedBalance = -1,
      int syncedBlockHeight = -1,
      required Blockchain blockchain,
      double daysSinceLastBlock = -1,
      int walletHeight = -1,
      String name = "Local Wallet",
      LocalWalletStatus status = LocalWalletStatus.Synced,
      int? fingerprint,
      List<String> addresses = const []})
      : super(
            confirmedBalance: confirmedBalance,
            unconfirmedBalance: unconfirmedBalance,
            walletHeight: walletHeight,
            fingerprint: fingerprint,
            blockchain: blockchain,
            daysSinceLastBlock: daysSinceLastBlock,
            syncedBlockHeight: syncedBlockHeight,
            name: name,
            addresses: addresses);

  LocalWallet.fromJson(dynamic json) : super.fromJson(json);

  void parseWalletBalance(String binPath) {
    var walletOutput =
        io.Process.runSync(binPath, const ["wallet", "show"]).stdout.toString();

    try {
      //If user enabled showWalletBalance then parses ``chia wallet show``
      RegExp walletRegex = RegExp(
          "-Total Balance:(.*)${this.blockchain.currencySymbol.toLowerCase()} \\(([0-9]+) ${this.blockchain.minorCurrencySymbol.toLowerCase()}\\)",
          multiLine: false);

      //converts minor symbol to major symbol
      confirmedBalance = int.tryParse(
              walletRegex.firstMatch(walletOutput)?.group(2) ?? '-1') ??
          -1;
    } catch (e) {
      log.warning("Error: could not parse wallet balance.");
    }

    //tries to get synced wallet height
    try {
      RegExp walletHeightRegex =
          RegExp("Wallet height: ([0-9]+)", multiLine: false);
      walletHeight = int.tryParse(
              walletHeightRegex.firstMatch(walletOutput)?.group(1) ?? '-1') ??
          -1;
    } catch (e) {
      log.warning("Error: could not parse wallet height");
    }
  }

  //checks all addresses associated with it from database
  void getAllAddresses() {
    if (fingerprint != null) {
      Database? db;

      try {
        //tries to open database
        //if that fails loads pre bundled libraries

        const mode = OpenMode.readOnly;
        final String dbLocation = blockchain.walletPath +
            "/db/blockchain_wallet_v1_${blockchain.dbNet}_$fingerprint.sqlite";

        db = openSQLiteDB(dbLocation, mode);

        //Use the database

        const String query =
            "SELECT puzzle_hash,coinbase,coin_parent FROM coin_record";
        var results = db.select(query);

        for (var result in results) {
          final String puzzleHash = result['puzzle_hash'];

          if (result['coinbase'] == 1 &&
              coinbaseParentHeight(result['coin_parent']) != null)
            farmedHeights.add(coinbaseParentHeight(result['coin_parent'])!);

          final String address = segwit.encode(
              Segwit(blockchain.currencySymbol, HEX.decode(puzzleHash)));

          addresses.add(address);
        }

        addresses = addresses.toSet().toList(); //filters duplicate addresses;
      } catch (error) {
        log.info("Failed to get hot wallet addresses");
        log.info(error);
      }

      //print(addresses);
      db?.dispose(); //disposes database and closes connection
      //only if it was initialized
    }
  }
}
