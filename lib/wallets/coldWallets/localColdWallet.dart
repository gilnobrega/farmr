import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:logging/logging.dart';

import 'dart:ffi';
import 'package:universal_io/io.dart' as io;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart'; //sqlite library

import 'package:bech32m/bech32m.dart'; //puzzle hash library

import "dart:typed_data"; //to convert int lists to uints

Logger log = Logger("Local Cold Wallet");

//Testing purposes
/*main() {
  Segwit address = segwit
      .decode("xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9");

  print(address.scriptPubKey);

  LocalColdWallet(
          rootPath: "",
          address:
              "xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9",
          blockchain: Blockchain.fromSymbol("xch"))
      .init();
}*/

class LocalColdWallet extends ColdWallet {
  final String address;
  final String rootPath;

  LocalColdWallet(
      {required Blockchain blockchain,
      required this.address,
      required this.rootPath,
      String name = "Local Cold Wallet"})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      //generates puzzle hash from address
      final Segwit puzzleHash = segwit.decode(this.address);

      late final db;

      //tries to open database
      //if that fails loads pre bundled libraries
      try {
        db = sqlite3.open(blockchain.dbPath + "/blockchain_v1_mainnet.sqlite");
      } catch (error) {
        open.overrideFor(
            OperatingSystem.linux, _openOnLinux); //provides .so file to linux
        open.overrideFor(OperatingSystem.windows,
            _openOnWindows); // provides .dll file to windows
        db = sqlite3.open(blockchain.dbPath + "/blockchain_v1_mainnet.sqlite");
      }
      // Use the database

      var result = db.select('SELECT * FROM coin_record WHERE puzzle_hash=?',
          ["${puzzleHash.scriptPubKey}"]);

      for (var coin in result) {
        //converts list of bytes to an uint64
        final int amountToAdd =
            (Uint8List.fromList(coin['amount'] as List<int>))
                .buffer
                .asByteData()
                .getUint64(0);

        //gross balance
        grossBalance += amountToAdd;

        //if coin was not spent, adds that amount to netbalance
        if (coin['spent'] == 0) netBalance += amountToAdd;

        //if coin was farmed to address, adds it to farmed balance
        if (coin['coinbase'] == 1) {
          farmedBalance += amountToAdd;

          //sets last farmed timestamp
          if (coin['timestamp'] is int)
            setDaysAgoWithTimestamp((coin['timestamp'] as int) * 1000);
        }
      }

      //closes database connection
      db.dispose();
    } catch (error) {
      log.warning("Exception in getting local cold wallet info");
      log.info(error);
    }
  }

  DynamicLibrary _openOnLinux() {
    late final libraryNextToScript;

    if (io.File("/etc/farmr/libsqlite3.so").existsSync())
      libraryNextToScript = io.File("/etc/farmr/libsqlite3.so");
    else
      libraryNextToScript = io.File(rootPath + 'libsqlite3.so');

    return DynamicLibrary.open(libraryNextToScript.path);
  }

  DynamicLibrary _openOnWindows() {
    final libraryNextToScript = io.File(rootPath + 'sqlite3.dll');
    return DynamicLibrary.open(libraryNextToScript.path);
  }
}
