import 'dart:core';
import 'dart:convert';

import 'package:farmr_client/hardware.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/harvester/plots.dart';
import 'package:farmr_client/harvester/diskspace.dart';
import 'package:farmr_client/debug.dart' as Debug;
import 'package:farmr_client/harvester/filters.dart';

import 'package:farmr_client/extensions/swarpm.dart';

final log = Logger('Harvester');

class Harvester with HarvesterDiskSpace, HarvesterPlots, HarvesterFilters {
  late Config _config;

  String _name = "Harvester";
  String get name => _name;

  String _status = "Harvesting";
  String get status => _status;

  String _currency = 'USD';
  String get currency => _currency.toUpperCase();

  // pubspec.yaml version
  String _version = '';
  String get version => _version;

  List<String> _plotDests = []; //plot destination paths

  String id = Uuid().v4();

  //Timestamp to when the farm was last parsed
  DateTime _lastUpdated = DateTime.now();
  DateTime get lastUpdated => _lastUpdated;

  String _lastUpdatedString = "1971-01-01";
  String get lastUpdatedString => _lastUpdatedString;

  //Farmer or Harvester
  final type = ClientType.Harvester;

  SwarPM _swarPM = SwarPM(); //initializes empty SwarPM class (jobs = [])
  SwarPM get swarPM => _swarPM;

  Hardware? _hardware;
  Hardware? get hardware => _hardware;

  Map toJson() {
    var initialMap = {
      'name': _name,
      'status': status,
      'currency': currency,
      'drivesCount': drivesCount,
      'plots': allPlots, //important
      'totalDiskSpace': totalDiskSpace,
      'freeDiskSpace': freeDiskSpace,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'lastUpdatedString': lastUpdatedString,
      'type': type.index,
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
      "swarPM": swarPM,
      'version': version
    };

    if (_config.showHardwareInfo && hardware != null)
      initialMap.putIfAbsent("hardware", () => hardware!);

    return initialMap;
  }

  Harvester(this._config, Debug.Log log, [String version = '']) {
    _version = version;
    _name = _config.name; //loads name from config
    _currency = _config.currency; // loads currency from config

    allPlots = _config.cache.plots; //loads plots from cache

    _lastUpdated = DateTime.now();
    _lastUpdatedString = dateToString(_lastUpdated);

    loadFilters(log);

    _status = harvestingStatus(_config.parseLogs) ?? _status;

    //loads swar plot manager config if defined by user
    if (_config.swarPath != "") _swarPM = SwarPM(_config.swarPath);

    //gets memory/cpu info and loads past memory info
    if (_config.showHardwareInfo) {
      _hardware = Hardware(_config.cache.memories);
      _config.cache.saveMemories(_hardware?.memories ?? []);
    }
  }

  Harvester.fromJson(String json) {
    allPlots = [];

    var object = jsonDecode(json)[0];

    //loads harvester status
    if (object['status'] != null) _status = object['status'];

    //loads name from json file
    if (object['name'] != null) _name = object['name'];

    //loads currency from json file
    if (object['currency'] != null) _currency = object['currency'];

    //loads version from json
    if (object['version'] != null) _version = object['version'];

    //loads number of drives from json
    if (object['drivesCount'] != null) drivesCount = object['drivesCount'];

    for (int i = 0; i < object['plots'].length; i++) {
      allPlots.add(Plot.fromJson(object['plots'][i]));
    }

    //check harvester/filters.dart
    loadFiltersStatsJson(object, plots.length);

    if (object['totalDiskSpace'] != null && object['freeDiskSpace'] != null) {
      totalDiskSpace = object['totalDiskSpace'];
      freeDiskSpace = object['freeDiskSpace'];

      //if one of these values is 0 then it will assume that something went wrong in parsing disk space
      //or the client was outdated
      if (totalDiskSpace == 0 || freeDiskSpace == 0) supportDiskSpace = false;
    } else
      supportDiskSpace = false;

    _lastUpdated = DateTime.fromMillisecondsSinceEpoch(object['lastUpdated']);

    if (object['lastUpdatedString'] != null)
      _lastUpdatedString = object['lastUpdatedString'];

    if (object['swarPM'] != null) _swarPM = SwarPM.fromJson(object['swarPM']);

    if (object['hardware'] != null)
      _hardware = Hardware.fromJson(object['hardware']);
  }

  Future<void> init(String chiaConfigPath) async {
    //LOADS CHIA CONFIG FILE AND PARSES PLOT DIRECTORIES
    _plotDests = listPlotDest(chiaConfigPath);

    await listPlots(_plotDests, _config);

    filterDuplicates(); //removes plots with duplicate ids

    _lastUpdated = DateTime.now();

    if (!_config.ignoreDiskSpace)
      await getDiskSpace(_plotDests);
    else {
      totalDiskSpace = 1;
      freeDiskSpace = 1;
    }
  }

  //Merges another harvester with this harvester
  void addHarvester(Harvester harvester) {
    allPlots.addAll(harvester.allPlots);

    addHarversterFilters(harvester);

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0)
      supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    totalDiskSpace += harvester.totalDiskSpace;
    freeDiskSpace += harvester.freeDiskSpace;
    drivesCount += harvester.drivesCount;

    //Disables avg, median, etc. in !chia full
    this.disableDetailedTimeStats();

    //adds swar pm jobs
    swarPM.jobs.addAll(harvester.swarPM.jobs);

    //shows harvesters status if theyre not harvesting
    if (harvester.status != "Harvesting" && harvester.status != "Farming")
      _status = "$_status,\n${harvester.name} is ${harvester.status}";
  }

  //clears plots ids before sending info to server
  /*void clearIDs() {
    for (int i = 0; i < allPlots.length; i++) allPlots[i].clearID();
  }*/

}