import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:logging/logging.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart'; //sqlite library

import 'package:bech32m/bech32m.dart'; //puzzle hash library

import "dart:typed_data"; //to convert int lists to uints

Logger log = Logger("Local Cold Wallet");

//Testing purposes
/*main() {
  Segwit address = segwit
      .decode("xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9");

  print(address.scriptPubKey);

  LocalColdWallet(
          address:
              "xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9",
          blockchain: Blockchain.fromSymbol("xch"))
      .init();
}*/

class LocalColdWallet extends ColdWallet {
  final String address;

  LocalColdWallet(
      {required Blockchain blockchain,
      required this.address,
      String name = "Local Cold Wallet"})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    try {
      //generates puzzle hash from address
      Segwit puzzleHash = segwit.decode(this.address);
      print(puzzleHash.scriptPubKey);

      // Init ffi loader if needed.
      sqfliteFfiInit();

      var databaseFactory = databaseFactoryFfi;

      final dbPath = blockchain.dbPath + "/blockchain_v1_mainnet.sqlite";

      var db = await databaseFactory.openDatabase(dbPath);
      var result = await db.query('coin_record',
          where: 'puzzle_hash= ?', whereArgs: ["${puzzleHash.scriptPubKey}"]);

      for (var coin in result) {
        print(coin);

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

          if (coin['timestamp'] is int)
            setDaysAgoWithTimestamp((coin['timestamp'] as int) * 1000);
        }
      }

      //closes database connection
      await db.close();
    } catch (error) {
      log.warning("Exception in getting local cold wallet info");
      log.info(error);
    }
  }
}
