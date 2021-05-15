import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:chiabot/config.dart';
import 'package:chiabot/harvester.dart';
import 'package:chiabot/debug.dart' as Debug;
import 'package:chiabot/farmer/wallet.dart';

import 'packagE:chiabot/server/netspace.dart';

final log = Logger('Farmer');

class Farmer extends Harvester {
  String _status;
  String get status => _status;

  Wallet _wallet = Wallet(-1.0, 0);
  Wallet get wallet => _wallet;

  //Farmed balance
  double _balance = 0;
  double get balance => _balance; //hides balance if string

  ClientType _type = ClientType.Farmer;
  @override
  ClientType get type => _type;

  NetSpace _netSpace;
  NetSpace get netSpace => _netSpace;

  //SubSlots with 64 signage points
  int _completeSubSlots = 0;
  int get completeSubSlots => _completeSubSlots;

  //Signagepoints in an incomplete sub plot
  int _looseSignagePoints = 0;
  int get looseSignagePoints => _looseSignagePoints;

  @override
  Map toJson() => {
        'name': name,
        'currency': currency,
        'status': status,
        'balance': balance, //farmed balance
        'walletBalance': _wallet.balance, //wallet balance
        //rounds days since last blocks so its harder to track wallets
        //precision of 0.1 days means uncertainty of 140 minutes
        'daysSinceLastBlock': double.parse(_wallet.daysSinceLastBlock.toStringAsFixed(1)),
        'plots': allPlots, //important
        'totalDiskSpace': totalDiskSpace,
        'freeDiskSpace': freeDiskSpace,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'lastUpdatedString': lastUpdatedString,
        'type': type.index,
        'completeSubSlots': completeSubSlots,
        'looseSignagePoints': looseSignagePoints,
        'numberFilters': numberFilters,
        'eligiblePlots': eligiblePlots,
        'proofsFound': proofsFound,
        'totalPlots': totalPlots,
        'missedChallenges': missedChallenges,
        'maxTime': maxTime,
        'minTime': minTime,
        'avgTime': avgTime,
        'medianTime': medianTime,
        'stdDeviation': stdDeviation,
        'filterCategories': filterCategories,
        'version': version
      };

  Farmer(Config config, Debug.Log log, [String version = '']) : super(config, log, version) {
    //runs chia farm summary if it is a farmer
    var result = io.Process.runSync(config.cache.binPath, ["farm", "summary"]);
    List<String> lines = result.stdout.toString().replaceAll("\r", "").split('\n');

    //needs last farmed block to calculate effort, this is never stored
    int lastBlockFarmed = 0;
    try {
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];

        if (line.startsWith("Total chia farmed: "))
          _balance =
              (config.showBalance) ? double.parse(line.split('Total chia farmed: ')[1]) : -1.0;
        else if (line.startsWith("Farming status: "))
          _status = line.split("Farming status: ")[1];
        else if (line.startsWith("Last height farmed: "))
          lastBlockFarmed = int.tryParse(line.split("Last height farmed: ")[1]);
        else if (line.startsWith("Estimated network space: "))
          _netSpace = NetSpace(line.split("Estimated network space: ")[1]);
      }
    } catch (exception) {
      print("Error parsing Farm info.");
    }

    //If user enabled showWalletBalance then parses ``chia wallet show``
    if (config.showWalletBalance) {
      _wallet.parseWalletBalance(config.cache.binPath, lastBlockFarmed);
    }

    //Parses logs for sub slots info
    if (config.parseLogs) {
      log.loadSignagePoints();
      calculateSubSlots(log);
    }
  }

  //Server side function to read farm from json file
  Farmer.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    _status = object['status'];
    _balance = object['balance'];

    double walletBalance = -1.0;
    double daysSinceLastBlock = 0;

    //initializes wallet with given balance and number of days since last block
    if (object['walletBalance'] != null) walletBalance = object['walletBalance'];
    if (object['daysSinceLastBlock'] != null) daysSinceLastBlock = object['daysSinceLastBlock'];

    _wallet = Wallet(walletBalance, daysSinceLastBlock);

    if (object['completeSubSlots'] != null) _completeSubSlots = object['completeSubSlots'];
    if (object['looseSignagePoints'] != null) _looseSignagePoints = object['looseSignagePoints'];

    calculateFilterRatio(this);
  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Harvester harvester) {
    allPlots.addAll(harvester.allPlots);

    addHarversterFilters(harvester);

    if (harvester is Farmer) {
      _completeSubSlots += harvester.completeSubSlots;
      _looseSignagePoints += harvester._looseSignagePoints;
    }

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0) supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    totalDiskSpace += harvester.totalDiskSpace;
    freeDiskSpace += harvester.freeDiskSpace;

    //Disables avg, median, etc. in !chia full
    this.disableDetailedTimeStats();
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
