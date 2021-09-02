import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:logging/logging.dart';

import 'package:farmr_client/utils/sqlite.dart';
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
  final String rootPath;
  bool success = true;

  LocalColdWallet(
      {required Blockchain blockchain,
      required String address,
      required this.rootPath,
      String name = "Local Cold Wallet"})
      : super(blockchain: blockchain, name: name, address: address);

  Future<void> init() async {
    Database? db;

    try {
      //generates puzzle hash from address
      final Segwit puzzleHash = segwit.decode(this.addresses.first);
      //print("Puzzle hash: ${puzzleHash.scriptPubKey}");

      //tries to open database
      //if that fails loads pre bundled libraries

      final mode = OpenMode.readOnly;

      db = openSQLiteDB(
          blockchain.dbPath + "/blockchain_v1_${blockchain.dbNet}.sqlite",
          mode);

      //Use the database
      const String query = """
        SELECT amount,coinbase,spent,timestamp,coin_parent FROM coin_record 
        WHERE puzzle_hash = ?
        """;
      var result = db.select(query, [puzzleHash.scriptPubKey]);

      farmedBalance = 0;
      grossBalance = 0;
      netBalance = 0;

      for (var coin in result) {
        //print("${coin['puzzle_hash']}");
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

          print(coin['coin_parent']);

          if (coinbaseParentHeight(coin['coin_parent']) != null)
            farmedHeights.add(coinbaseParentHeight(coin['coin_parent'])!);

          //sets last farmed timestamp
          if (coin['timestamp'] is int)
            setDaysAgoWithTimestamp((coin['timestamp'] as int) * 1000);
        }
      }
    } catch (error) {
      print(error);
      success = false;
      log.info(success);
    }

    //closes database connection
    db?.dispose();
  }
}
