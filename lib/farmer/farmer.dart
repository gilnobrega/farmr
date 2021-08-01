import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/farmer/status.dart';
import 'package:farmr_client/rpc.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/config.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/debug.dart' as Debug;
import 'package:farmr_client/wallets/localWallets/localWallet.dart';
import 'package:farmr_client/farmer/connections.dart';
import 'package:farmr_client/log/shortsync.dart';
import 'package:http/http.dart' as http;

final log = Logger('Farmer');

class Farmer extends Harvester with FarmerStatusMixin {
  Connections? _connections;

  double get balance =>
      farmedBalance /
      blockchain.majorToMinorMultiplier; //hides balance if string

  //number of full nodes connected to farmer
  int _fullNodesConnected = 0;
  int get fullNodesConnected => _fullNodesConnected;

  @override
  late ClientType type;

  //SubSlots with 64 signage points
  int _completeSubSlots = 0;
  int get completeSubSlots => _completeSubSlots;

  //Signagepoints in an incomplete sub plot
  int _looseSignagePoints = 0;
  int get looseSignagePoints => _looseSignagePoints;

  List<ShortSync> shortSyncs = [];

  int _peakBlockHeight = -1;
  int get peakBlockHeight => _peakBlockHeight;

  //number of poolErrors events
  int _poolErrors = -1; // -1 means client doesnt support
  int get poolErrors => _poolErrors;

  @override
  Map toJson() {
    //loads harvester's map (since farmer is an extension of it)
    Map harvesterMap = (super.toJson());

    //adds extra farmer's entries
    harvesterMap.addEntries({
      'balance': balance, //farmed balance
      //rounds days since last blocks so its harder to track wallets
      //precision of 0.1 days means uncertainty of 140 minutes

      'completeSubSlots': completeSubSlots,
      'looseSignagePoints': looseSignagePoints,

      'fullNodesConnected': fullNodesConnected,
      "shortSyncs": shortSyncs,
      "netSpace": netSpace.size,
      "syncedBlockHeight": syncedBlockHeight,
      "peakBlockHeight": peakBlockHeight,
      "poolErrors": poolErrors
    }.entries);

    //returns complete map with both farmer's + harvester's entries
    return harvesterMap;
  }

  Farmer(
      {required Blockchain blockchain, String version = '', required this.type})
      : super(blockchain, version) {
    if (type != ClientType.HPool) {
      getNodeHeight(); //sets _syncedBlockHeight

      //initializes connections and counts peers
      _connections = Connections(blockchain.config.cache!.binPath);

      _fullNodesConnected = _connections?.connections
              .where((connection) => connection.type == ConnectionType.FullNode)
              .length ??
          0; //whats wrong with this vs code formatting lmao

      //Parses logs for sub slots info
      if (blockchain.config.parseLogs) {
        calculateSubSlots(blockchain.log);
      }

      shortSyncs = blockchain.log.shortSyncs; //loads short sync events

      _poolErrors = blockchain.cache.poolErrors.length;
    }
  }

  Future<void> getLocalWallets() async {
    final bool? isWalletServiceRunning =
        ((await blockchain.rpcPorts?.isServiceRunning([RPCService.Wallet])) ??
            {})[RPCService.Wallet];

    //checks if wallet rpc service is running and wallet port is defined
    if (isWalletServiceRunning ?? false) {
      RPCConfiguration rpcConfig = RPCConfiguration(
          blockchain: blockchain,
          service: RPCService.Wallet,
          endpoint: "get_wallets",
          dataToSend: {});

      final walletsObject = await RPCConnection.getEndpoint(rpcConfig);

      int walletHeight = -1;
      String name = "Wallet";
      bool synced = true;
      bool syncing = false;

      //if wallet balance is enabled and
      //if rpc works
      if (walletsObject != null && (walletsObject['success'] ?? false)) {
        if (blockchain.config.showBalance &&
            walletsObject['wallets'].length > 0) farmedBalance = 0;

        for (var walletID in walletsObject['wallets'] ?? []) {
          final int id = walletID['id'] ?? 1;
          name = walletID['name'] ?? "Wallet";
          //final int walletType = walletID['type'] ?? 0;

          RPCConfiguration rpcConfig2 = RPCConfiguration(
              blockchain: blockchain,
              service: RPCService.Wallet,
              endpoint: "get_wallet_balance",
              dataToSend: {"wallet_id": id});

          final walletInfo = await RPCConnection.getEndpoint(rpcConfig2);

          if (walletInfo != null && (walletInfo['success'] ?? false)) {
            final int confirmedBalance =
                walletInfo['wallet_balance']['confirmed_wallet_balance'] ?? 0;

            final int unconfirmedBalance =
                walletInfo['wallet_balance']['unconfirmed_wallet_balance'] ?? 0;

            RPCConfiguration rpcConfig3 = RPCConfiguration(
                blockchain: blockchain,
                service: RPCService.Wallet,
                endpoint: "get_sync_status",
                dataToSend: {"wallet_id": id});

            final walletSyncInfo = await RPCConnection.getEndpoint(rpcConfig3);

            if (walletSyncInfo != null &&
                (walletSyncInfo['success'] ?? false)) {
              synced = walletSyncInfo['synced'];
              syncing = walletSyncInfo['syncing'];
            }

            RPCConfiguration rpcConfig4 = RPCConfiguration(
                blockchain: blockchain,
                service: RPCService.Wallet,
                endpoint: "get_height_info",
                dataToSend: {"wallet_id": id});

            final walletHeightInfo =
                await RPCConnection.getEndpoint(rpcConfig4);

            if (walletHeightInfo != null &&
                (walletHeightInfo['success'] ?? false)) {
              walletHeight = walletHeightInfo['height'] ?? -1;
            }

            final LocalWallet wallet = LocalWallet(
                blockchain: blockchain,
                confirmedBalance:
                    blockchain.config.showWalletBalance ? confirmedBalance : -1,
                unconfirmedBalance: blockchain.config.showWalletBalance
                    ? unconfirmedBalance
                    : -1,
                walletHeight: walletHeight,
                syncedBlockHeight: syncedBlockHeight,
                name: name,
                status: (synced)
                    ? LocalWalletStatus.Synced
                    : (syncing)
                        ? LocalWalletStatus.Syncing
                        : LocalWalletStatus.NotSynced);

            RPCConfiguration rpcConfig5 = RPCConfiguration(
                blockchain: blockchain,
                service: RPCService.Wallet,
                endpoint: "get_farmed_amount",
                dataToSend: {"wallet_id": id});

            final walletFarmedInfo =
                await RPCConnection.getEndpoint(rpcConfig5);

            if (walletFarmedInfo != null &&
                (walletFarmedInfo['success'] ?? false)) {
              //adds wallet farmed balance
              if (blockchain.config.showBalance)
                farmedBalance += walletFarmedInfo['farmed_amount'] as int;
              //sets wallet last farmed height
              wallet.setLastBlockFarmed(walletFarmedInfo['last_height_farmed']);
            }

            wallets.add(wallet);
          }
        }
      } else //legacy wallet method
        _getLegacyLocalWallets();
    } else
      _getLegacyLocalWallets();
  }

  //legacy mode for getting local wallet
  //basically uses cli (chia wallet show)
  void _getLegacyLocalWallets() {
    LocalWallet localWallet = LocalWallet(
        blockchain: this.blockchain, syncedBlockHeight: syncedBlockHeight);
    localWallet.setLastBlockFarmed(lastBlockFarmed);

    //parses chia wallet show for wallet balance (legacy mode)
    if (blockchain.config.showWalletBalance)
      localWallet.parseWalletBalance(blockchain.config.cache!.binPath);

    wallets.add(localWallet);
  }

  void getNodeHeight() {
    try {
      var nodeOutput = io.Process.runSync(
              blockchain.config.cache!.binPath, const ["show", "-s"])
          .stdout
          .toString();

      RegExp regExp = RegExp(r"Height:[\s]+([0-9]+)");

      syncedBlockHeight =
          int.tryParse(regExp.firstMatch(nodeOutput)?.group(1) ?? "-1") ?? -1;
    } catch (error) {
      log.warning("Failed to get synced height");
    }
  }

  Future<void> getPeakHeight() async {
    //tries to get peak block height from chiaexplorer.com
    try {
      const String url = "https://api2.chiaexplorer.com/blocks";

      String contents = await http.read(Uri.parse(url));

      dynamic object = jsonDecode(contents);

      _peakBlockHeight =
          int.tryParse((object[0]['height'] ?? -1).toString()) ?? -1;
    } catch (error) {
      log.warning("Failed to get peak height");
    }
  }

  @override
  Future<void> init() async {
    if (type != ClientType.HPool) {
      await updateFarmerStatus(blockchain);

      await getLocalWallets();

      if (blockchain.currencySymbol == "xch") await getPeakHeight();
    }

    await super.init();
  }

  //Server side function to read farm from json file
  Farmer.fromJson(dynamic object) : super.fromJson(object) {
    type = ClientType.Farmer;

    statusFromJson(object, blockchain);

    int walletBalance = -1;
    double daysSinceLastBlock = -1.0;

    //initializes wallet with given balance and number of days since last block
    if (object['walletBalance'] != null)
      walletBalance =
          (double.parse(object['walletBalance'].toString()) * 1e12).round();
    if (object['daysSinceLastBlock'] != null)
      daysSinceLastBlock =
          double.parse(object['daysSinceLastBlock'].toString());

    if (object['syncedBlockHeight'] != null)
      syncedBlockHeight = object['syncedBlockHeight'];

    if (object['peakBlockHeight'] != null)
      _peakBlockHeight = object['peakBlockHeight'];

    int walletHeight = -1;
    if (object['walletHeight'] != null) walletHeight = object['walletHeight'];

    //pool wallet LEGACY
    if (object['pendingBalance'] != null && object['collateralBalance'] != null)
      wallets.add(GenericPoolWallet(
          pendingBalance: (double.parse(object['pendingBalance'].toString()) *
                  blockchain.majorToMinorMultiplier)
              .round(),
          collateralBalance:
              (double.parse(object['collateralBalance'].toString()) *
                      blockchain.majorToMinorMultiplier)
                  .round(),
          blockchain: blockchain));
    //local wallet LEGACY
    if (walletBalance >= 0 || daysSinceLastBlock > 0)
      wallets.add(LocalWallet(
          confirmedBalance: walletBalance,
          daysSinceLastBlock: daysSinceLastBlock,
          blockchain: Blockchain.fromSymbol(object['crypto'] ?? "xch"),
          syncedBlockHeight: syncedBlockHeight,
          walletHeight: walletHeight));

    if (object['completeSubSlots'] != null)
      _completeSubSlots = object['completeSubSlots'];
    if (object['looseSignagePoints'] != null)
      _looseSignagePoints = object['looseSignagePoints'];

    if (object['fullNodesConnected'] != null)
      _fullNodesConnected = object['fullNodesConnected'];

    if (object['shortSyncs'] != null) {
      for (var shortSync in object['shortSyncs'])
        shortSyncs.add(ShortSync.fromJson(shortSync));
    }

    if (object['poolErrors'] != null) _poolErrors = object['poolErrors'];

    if (object['coldWallet'] != null) {
      double netBalance =
          double.parse((object['coldWallet']['netBalance'] ?? "-1").toString());
      double grossBalance = double.parse(
          (object['coldWallet']['grossBalance'] ?? "-1").toString());
      double farmedBalance = double.parse(
          (object['coldWallet']['farmedBalance'] ?? "-1").toString());

      wallets.add(ColdWallet(
          blockchain: Blockchain.fromSymbol(object['crypto'] ?? "xch"),
          netBalance: (netBalance * 1e12).round(),
          farmedBalance: (farmedBalance * 1e12).round(),
          grossBalance: (grossBalance * 1e12).round()));
    }

    calculateFilterRatio(this);
  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Harvester harvester) {
    super.addHarvester(harvester);

    if (harvester is Farmer) {
      _completeSubSlots += harvester.completeSubSlots;
      _looseSignagePoints += harvester._looseSignagePoints;

      shortSyncs.addAll(harvester.shortSyncs);
    }
  }

  void calculateSubSlots(Debug.Log log) {
    _completeSubSlots = log.subSlots.where((point) => point.complete).length;

    var incomplete = log.subSlots.where((point) => !point.complete);
    _looseSignagePoints = 0;
    for (var i in incomplete) {
      _looseSignagePoints += i.signagePoints.length;
    }
  }
}
