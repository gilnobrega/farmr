import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:farmr_client/server/netspace.dart';
import 'package:logging/logging.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

Logger log = Logger("FoxyPool API");

class FoxyPoolWallet extends GenericPoolWallet {
  final String publicKey;
  IO.Socket? _socket;

  bool _queryComplete = false;

  FoxyPoolWallet(
      {required Blockchain blockchain,
      required this.publicKey,
      String name = "FoxyPool Wallet"})
      : super(blockchain: blockchain, name: name);

  Future<void> init() async {
    if (publicKey != "") {
      Stopwatch stopwatch = Stopwatch();

      stopwatch.start();

      try {
        _getBalance(publicKey, blockchain);
      } catch (e) {
        log.warning(
            "Failed to get FoxyPool Info, make sure your pool public key is correct.");
      }

      //maximum of 5 seconds
      while (!_queryComplete && stopwatch.elapsedMilliseconds < 5000) {
        await Future.delayed(Duration(seconds: 1));
      }

      //print("finished");
      stopwatch.stop();
      //print(stopwatch.elapsedMilliseconds);

      //print(this.collateralBalance);
      //print(this.pendingBalance);
      //print(this.effectiveCapacity);
      //print(this.shares);
    }
  }

  void _getBalance(String poolPublicKey, Blockchain blockchain) {
    // Dart client
    _socket = IO.io(
      'https://api.${blockchain.binaryName}-og.foxypool.io/stats',
      <String, dynamic>{
        'transports': ['websocket'],
      },
    );
    _socket?.onConnect((_) {
      _socket?.emitWithAck('account:fetch', {
        '${blockchain.binaryName}-og',
        {'poolPublicKey': poolPublicKey}
      }, ack: (data) {
        //print('ack $data');
        if (data != null) {
          //print(data);
          try {
            pendingBalance = (double.parse(data['pending'].toString()) *
                    blockchain.majorToMinorMultiplier)
                .round();
            collateralBalance = (double.parse(data['collateral'].toString()) *
                    blockchain.majorToMinorMultiplier)
                .round();
            currentPoints = double.parse(data['shares'].toString()).round();
            capacity = NetSpace.sizeStringToInt("${data['ec']} GiB").round();
          } catch (error) {
            log.warning("Error parsing FoxyPool info!");
            log.info(error.toString());
          }
        } else {
          log.warning(
              "Failed to get FoxyPool Info, make sure your pool public key is correct.");
        }
        _queryComplete = true;

        _socket?.dispose();
      });
    });
  }
}
