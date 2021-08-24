import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:logging/logging.dart';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bech32m/bech32m.dart';

Logger log = Logger("Local Cold Wallet");

main() {
  Segwit address = segwit
      .decode("xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9");

  print(address.scriptPubKey);

  LocalColdWallet(
          address:
              "xch1z9wes90p356aqn9svvmr7du8yrr03payla02nkfpmfrtpeh23s4qmhx9q9",
          blockchain: Blockchain.fromSymbol("xch"))
      .init();
}

class LocalColdWallet extends ColdWallet {
  final String address;

  LocalColdWallet(
      {required Blockchain blockchain,
      required this.address,
      String name = "Local Cold Wallet"})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    Segwit puzzleHash = segwit.decode(this.address);

    print(puzzleHash.scriptPubKey);

    // Init ffi loader if needed.
    sqfliteFfiInit();

    var databaseFactory = databaseFactoryFfi;

    final dbPath = blockchain.dbPath + "/blockchain_v1_mainnet.sqlite";

    var db = await databaseFactory.openDatabase(dbPath);
    var result = await db.rawQuery('''
SELECT * FROM coin_record WHERE puzzle_hash='0x${puzzleHash.scriptPubKey}'
  ''');

    print(result);
    // prints [{id: 1, title: Product 1}, {id: 2, title: Product 1}]
    await db.close();
  }
}
