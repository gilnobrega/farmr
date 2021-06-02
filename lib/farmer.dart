import 'dart:core';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:chiabot/config.dart';
import 'package:chiabot/harvester.dart';
import 'package:chiabot/debug.dart' as Debug;
import 'package:chiabot/farmer/wallet.dart';
import 'package:chiabot/farmer/connections.dart';
import 'package:chiabot/log/shortsync.dart';

import 'package:chiabot/server/netspace.dart';

final log = Logger('Farmer');

class Farmer extends Harvester {
  String _status = "N/A";
  //shows not harvesting status if harvester class is not harvesting
  @override
  String get status =>
      (super.status == "Harvesting") ? _status : "$_status, ${super.status}";

  Wallet _wallet = Wallet(-1.0, 0);
  Wallet get wallet => _wallet;

  Connections? _connections;

  //number of full nodes connected to farmer
  int _fullNodesConnected = 0;
  int get fullNodesConnected => _fullNodesConnected;

  //Farmed balance
  double _balance = 0;
  double get balance => _balance; //hides balance if string

  @override
  final ClientType type = ClientType.Farmer;

  NetSpace _netSpace = NetSpace("1 B");
  NetSpace get netSpace => _netSpace;

  //SubSlots with 64 signage points
  int _completeSubSlots = 0;
  int get completeSubSlots => _completeSubSlots;

  //Signagepoints in an incomplete sub plot
  int _looseSignagePoints = 0;
  int get looseSignagePoints => _looseSignagePoints;

  List<ShortSync> shortSyncs = [];

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
    }.entries);

    //returns complete map with both farmer's + harvester's entries
    return harvesterMap;
  }

  Farmer(Config config, Debug.Log log, [String version = ''])
      : super(config, log, version) {
    //runs chia farm summary if it is a farmer
    var result = io.Process.runSync(config.cache.binPath, ["farm", "summary"]);
    List<String> lines =
        result.stdout.toString().replaceAll("\r", "").split('\n');

    //needs last farmed block to calculate effort, this is never stored
    int lastBlockFarmed = 0;
    try {
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];

        if (line.startsWith("Total chia farmed: "))
          _balance = (config.showBalance)
              ? double.parse(line.split('Total chia farmed: ')[1])
              : -1.0;
        else if (line.startsWith("Farming status: "))
          _status = line.split("Farming status: ")[1];
        else if (line.startsWith("Last height farmed: "))
          lastBlockFarmed =
              int.tryParse(line.split("Last height farmed: ")[1]) ?? 0;
        else if (line.startsWith("Estimated network space: "))
          _netSpace = NetSpace(line.split("Estimated network space: ")[1]);
      }
    } catch (exception) {
      print("Error parsing Farm info.");
    }

    //parses chia wallet show for block height
    _wallet.parseWalletBalance(
        config.cache.binPath, lastBlockFarmed, config.showWalletBalance);

    //initializes connections and counts peers
    _connections = Connections(config.cache.binPath);

    _fullNodesConnected = _connections?.connections
            .where((connection) => connection.type == ConnectionType.FullNode)
            .length ??
        0; //whats wrong with this vs code formatting lmao

    //Parses logs for sub slots info
    if (config.parseLogs) {
      calculateSubSlots(log);
    }

    shortSyncs = log.shortSyncs; //loads short sync events
  }

  //Server side function to read farm from json file
  Farmer.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    _status = object['status'];
    _balance = double.parse(object['balance'].toString());

    double walletBalance = -1.0;
    double daysSinceLastBlock = 0;

    //initializes wallet with given balance and number of days since last block
    if (object['walletBalance'] != null)
      walletBalance = double.parse(object['walletBalance'].toString());
    if (object['daysSinceLastBlock'] != null)
      daysSinceLastBlock = object['daysSinceLastBlock'];

    _wallet = Wallet(walletBalance, daysSinceLastBlock);

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

    calculateFilterRatio(this);
  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Harvester harvester) {
    allPlots.addAll(harvester.allPlots);

    addHarversterFilters(harvester);

    if (harvester is Farmer) {
      _completeSubSlots += harvester.completeSubSlots;
      _looseSignagePoints += harvester._looseSignagePoints;

      shortSyncs.addAll(harvester.shortSyncs);
    }

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0)
      supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    totalDiskSpace += harvester.totalDiskSpace;
    freeDiskSpace += harvester.freeDiskSpace;
    drivesCount += harvester.drivesCount;

    //Disables avg, median, etc. in !chia full
    this.disableDetailedTimeStats();

    //adds swar pm jobs
    swarPM?.jobs.addAll(harvester.swarPM?.jobs ?? []);
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
