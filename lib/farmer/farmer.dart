import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/farmer/coldwallet.dart';
import 'package:farmr_client/poolWallets/flexPoolWallet.dart';
import 'package:farmr_client/poolWallets/foxyPoolWallet.dart';
import 'package:farmr_client/poolWallets/genericPoolWallet.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/config.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/debug.dart' as Debug;
import 'package:farmr_client/farmer/wallet.dart';
import 'package:farmr_client/farmer/connections.dart';
import 'package:farmr_client/log/shortsync.dart';
import 'package:http/http.dart' as http;

import 'package:farmr_client/server/netspace.dart';

final log = Logger('Farmer');

class Farmer extends Harvester {
  String _status = "N/A";
  //shows not harvesting status if harvester class is not harvesting
  @override
  String get status => _status;

  //default empty wallet
  static Wallet _emptyWallet =
      Wallet(-1.0, -1.0, Blockchain.fromSymbol("xch"), -1, -1);
  Wallet _wallet = _emptyWallet;
  Wallet get wallet => _wallet;
  ColdWallet _coldWallet = ColdWallet();
  ColdWallet get coldWallet => _coldWallet;

  Connections? _connections;

  //number of full nodes connected to farmer
  int _fullNodesConnected = 0;
  int get fullNodesConnected => _fullNodesConnected;

  //Farmed balance
  double _balance = -1.0;
  double get balance => _balance; //hides balance if string

  @override
  late ClientType type;

  NetSpace _netSpace = NetSpace("1 B");
  NetSpace get netSpace => _netSpace;

  //SubSlots with 64 signage points
  int _completeSubSlots = 0;
  int get completeSubSlots => _completeSubSlots;

  //Signagepoints in an incomplete sub plot
  int _looseSignagePoints = 0;
  int get looseSignagePoints => _looseSignagePoints;

  List<ShortSync> shortSyncs = [];

  //final DateTime currentTime = DateTime.now();
  int _syncedBlockHeight = -1;
  int get syncedBlockHeight => _syncedBlockHeight;

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
      'walletBalance': _wallet.balance, //wallet balance
      //rounds days since last blocks so its harder to track wallets
      //precision of 0.1 days means uncertainty of 140 minutes
      'daysSinceLastBlock':
          double.parse(_wallet.daysSinceLastBlock.toStringAsFixed(1)),
      'completeSubSlots': completeSubSlots,
      'looseSignagePoints': looseSignagePoints,

      'fullNodesConnected': fullNodesConnected,
      "shortSyncs": shortSyncs,
      "netSpace": netSpace.size,
      "syncedBlockHeight": syncedBlockHeight,
      "peakBlockHeight": peakBlockHeight,
      "walletHeight": _wallet.walletHeight,
      "poolErrors": poolErrors
    }.entries);

    if (_wallet is GenericPoolWallet)
      harvesterMap.addEntries({
        'pendingBalance':
            (_wallet as GenericPoolWallet).pendingBalance, //pending balance
        'collateralBalance': (_wallet as GenericPoolWallet)
            .collateralBalance //collateral balance
      }.entries);

    if (coldWallet.grossBalance != -1.0 || coldWallet.netBalance != -1.0)
      harvesterMap.putIfAbsent("coldWallet", () => coldWallet);

    //returns complete map with both farmer's + harvester's entries
    return harvesterMap;
  }

  Farmer(
      {required Blockchain blockchain,
      String version = '',
      bool hpool = false,
      required this.type})
      : super(blockchain, version) {
    if (!hpool) {
      //runs chia farm summary if it is a farmer
      var result = io.Process.runSync(
          blockchain.config.cache!.binPath, const ["farm", "summary"]);
      List<String> lines =
          result.stdout.toString().replaceAll("\r", "").split('\n');

      //needs last farmed block to calculate effort, this is never stored
      int lastBlockFarmed = 0;
      try {
        for (int i = 0; i < lines.length; i++) {
          String line = lines[i];

          if (line.startsWith("Farming status: "))
            _status = line.split("Farming status: ")[1];

          try {
            if (line.startsWith("Total ${this.blockchain.binaryName} farmed: "))
              _balance = (blockchain.config.showBalance)
                  ? double.parse(line
                      .split('Total ${this.blockchain.binaryName} farmed: ')[1])
                  : -1.0;
          } catch (error) {
            log.warning(
                "Unable to parse farmed ${this.blockchain.currencySymbol.toUpperCase()}. Is wallet service running?");
          }

          try {
            if (line.startsWith("Last height farmed: "))
              lastBlockFarmed =
                  int.parse(line.split("Last height farmed: ")[1]);
          } catch (error) {
            log.warning(
                "Unable to parse last height farmed for ${this.blockchain.currencySymbol.toUpperCase()}. Is wallet service running?");
          }
          try {
            if (line.startsWith("Estimated network space: "))
              _netSpace = NetSpace(line.split("Estimated network space: ")[1]);
          } catch (error) {
            log.warning("Unable to parse Netspace.");
          }
        }
      } catch (exception) {
        print("Error parsing Farm info.");
      }

      getNodeHeight(); //sets _syncedBlockHeight

      if (type == ClientType.Farmer)
        _wallet = Wallet(-1.0, -1.0, this.blockchain, _syncedBlockHeight, -1);
      else if (type == ClientType.FoxyPoolOG)
        _wallet = FoxyPoolWallet(
            -1.0, -1.0, -1.0, -1.0, this.blockchain, _syncedBlockHeight, -1);
      else if (type == ClientType.Flexpool)
        _wallet = FlexpoolWallet(
            -1.0, -1.0, -1.0, this.blockchain, _syncedBlockHeight, -1);

      //parses chia wallet show for block height
      _wallet.parseWalletBalance(blockchain.config.cache!.binPath,
          lastBlockFarmed, blockchain.config.showWalletBalance);

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

      //harvesting status
      String harvestingStatusString =
          harvestingStatus(blockchain.config.parseLogs) ?? "Harvesting";

      if (harvestingStatusString != "Harvesting")
        _status = "$_status, $harvestingStatusString";

      _poolErrors = blockchain.cache.poolErrors.length;
    }
  }

  void getNodeHeight() {
    try {
      var nodeOutput = io.Process.runSync(
              blockchain.config.cache!.binPath, const ["show", "-s"])
          .stdout
          .toString();

      RegExp regExp = RegExp(r"Height:[\s]+([0-9]+)");

      _syncedBlockHeight =
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
    if (blockchain.config.coldWalletAddress != "")
      await _coldWallet.init(blockchain.config.coldWalletAddress, _wallet);

    if (blockchain.currencySymbol == "xch") await getPeakHeight();

    if (_wallet is FoxyPoolWallet) {
      //parses foxypool api if that option is enabled
      if (blockchain.config.foxyPoolOverride)
        //tries to parse foxypool api
        //normal wallet + foxypool pending income + foxypool collateral balance
        await (_wallet as FoxyPoolWallet).init();
    } else if (_wallet is FlexpoolWallet) {
      //normal wallet + flexpool pending income
      //tries to parse flexpool api
      await (_wallet as FlexpoolWallet).init();
    }

    await super.init();
  }

  //Server side function to read farm from json file
  Farmer.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    type = ClientType.Farmer;

    if (object['type'] != null && object['type'] is int)
      type = ClientType.values[object['type']];

    _status = object['status'];
    _balance = double.parse(object['balance'].toString());

    double walletBalance = -1.0;
    double daysSinceLastBlock = 0;

    //initializes wallet with given balance and number of days since last block
    if (object['walletBalance'] != null)
      walletBalance = double.parse(object['walletBalance'].toString());
    if (object['daysSinceLastBlock'] != null)
      daysSinceLastBlock =
          double.parse(object['daysSinceLastBlock'].toString());

    if (object['syncedBlockHeight'] != null)
      _syncedBlockHeight = object['syncedBlockHeight'];

    if (object['peakBlockHeight'] != null)
      _peakBlockHeight = object['peakBlockHeight'];

    int walletHeight = -1;
    if (object['walletHeight'] != null) walletHeight = object['walletHeight'];

    //pool wallet
    if (object['pendingBalance'] != null && object['collateralBalance'] != null)
      _wallet = GenericPoolWallet(
          walletBalance,
          daysSinceLastBlock,
          double.parse(object['pendingBalance'].toString()),
          double.parse(object['collateralBalance'].toString()),
          this.blockchain,
          _syncedBlockHeight,
          walletHeight);
    else
      _wallet = Wallet(walletBalance, daysSinceLastBlock, this.blockchain,
          _syncedBlockHeight, walletHeight);

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

    //reads netspace from json
    if (object['netSpace'] != null) {
      _netSpace =
          NetSpace.fromBytes(double.parse(object['netSpace'].toString()));
    }

    if (object['coldWallet'] != null)
      _coldWallet = ColdWallet.fromJson(object['coldWallet']);

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
