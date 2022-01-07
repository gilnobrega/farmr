import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/utils/sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/cache/cacheIO.dart'
    if (dart.library.js) "package:farmr_client/cache/cacheJS.dart";

import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/subslot.dart';
import 'package:farmr_client/log/logitem.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';
import 'package:yaml/yaml.dart';

final log = Logger('LOG');

enum ErrorType { Pool, Harvester }

class Log {
  ClientType _type;
  Cache _cache;
  String _binaryName;

  late String debugPath;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SignagePoint> signagePoints = [];

  //Generate list of complete/incomplete subslots from _signagePoints
  List<SubSlot> subSlots = [];

  List<ShortSync> shortSyncs = [];

  List<LogItem> poolErrors = [];
  List<LogItem> harvesterErrors = [];

  late final String floraProxy;

  late final List<String> regexes;

  late final String dbPath;

  Log(String logPath, this._cache, bool parseLogs, this._binaryName, this._type,
      String configPath, bool firstInit) {
    _filters = _cache.filters; //loads cached filters
    signagePoints = _cache.signagePoints; //loads cached subslots
    shortSyncs = _cache.shortSyncs;
    poolErrors = _cache.poolErrors;
    harvesterErrors = _cache.harvesterErrors;
    dbPath = this._cache.cache.path;

    debugPath = logPath + "/debug.log";

    if (_binaryName == "flora")
      floraProxy = "flora_proxy: ";
    else
      floraProxy = "";

    if (parseLogs && firstInit) {
      //if nothing was found then it
      //assumes log level is not set to info
      if (filters.length == 0 &&
          signagePoints.length == 0 &&
          shortSyncs.length == 0 &&
          _type != ClientType.HPool) {
        setLogLevelToInfo(configPath);
      }
    }
  }

  void setLogLevelToInfo(String configPath) {
    try {
      String configFile =
          configPath + io.Platform.pathSeparator + "config.yaml";

      var configYaml = loadYaml(
          io.File(configFile).readAsStringSync().replaceAll("!!set", ""));

      String logLevel = configYaml['farmer']['logging']['log_level'];

      if (logLevel == "WARNING") {
        //TODO: RENAME ALL THESE PRINTS TO LOG.WARNING
        print(
            "Log Parsing is enabled but $_binaryName's log level is set to $logLevel");
        print("Attempting to set $_binaryName's log level to INFO");

        io.Process.runSync(
            _cache.binPath, const ["configure", "--set-log-level", "INFO"]);

        configYaml = loadYaml(
            io.File(configFile).readAsStringSync().replaceAll("!!set", ""));

        logLevel = configYaml['farmer']['logging']['log_level'];

        if (logLevel == "INFO") {
          print("$_binaryName's log level has been set to INFO");
          print("Restarting $_binaryName's services");
          if (_type == ClientType.Farmer)
            io.Process.runSync(_cache.binPath, const ["start", "-r", "farmer"]);
          else if (_type == ClientType.Harvester)
            io.Process.runSync(
                _cache.binPath, const ["start", "-r", "harvester"]);

          print("Waiting for services to restart...");
          io.sleep(Duration(seconds: 60));
        }
      }
    } catch (error) {}
  }

  Future<void> initLogParsing(
      bool parseLogs, bool firstInit, bool onetime) async {
    //starts logging if first time
    if (parseLogs && firstInit) {
      await logStreamer(onetime);
    }
  }

  Future<void> logStreamer(bool onetime) async {
    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(dbPath, OpenMode.readWriteCreate);

    var result = <int>[];
    var initial = 0;

    final newLine = '\n'.codeUnitAt(0);

    final io.File debugFile = io.File(debugPath);

    while (true) {
      final size = debugFile.statSync().size;
      initial = initial > size ? 0 : initial;

      List<String> linesToParse = <String>[];

      Stream<List<int>> stream = io.File(debugPath).openRead(initial);

      await for (final data in stream) {
        for (int i = 0; i < data.length; i++) {
          if (data[i] == newLine) {
            linesToParse.add(String.fromCharCodes(result));
            result = <int>[];
          } else
            result.add(data[i]);
        }

        if (result.isNotEmpty) {
          linesToParse.add(String.fromCharCodes(result));
          result = <int>[];
        }

        initial += data.length;
      }

      // print("Read! " + initial.toString());

      List<Filter?> newFilters = [];
      List<SignagePoint?> newSignagePoints = [];
      List<ShortSync?> newShortSyncs = [];
      List<LogItem?> newHarvesterErrors = [];
      List<LogItem?> newPoolErrors = [];

      for (final line in linesToParse) {
        newFilters.add(parseFilters(line));
        newSignagePoints.add(parseSignagePoints(line));
        newShortSyncs.add(parseShortSyncs(line));
        newPoolErrors.add(parseErrors(line, ErrorType.Pool));
        newHarvesterErrors.add(parseErrors(line, ErrorType.Harvester));
      }

      Cache.saveToDB(database, newFilters, "filters");
      Cache.saveToDB(database, newSignagePoints, "signagePoints");
      Cache.saveToDB(database, newShortSyncs, "shortSyncs");
      Cache.saveToDB(database, newPoolErrors, "errors");
      Cache.saveToDB(database, newHarvesterErrors, "errors");

      filters.addAll(newFilters.whereType());
      signagePoints.addAll(newSignagePoints.whereType());
      shortSyncs.addAll(newShortSyncs.whereType());
      poolErrors.addAll(newPoolErrors.whereType());
      harvesterErrors.addAll(newHarvesterErrors.whereType());

      await Future.delayed(Duration(seconds: 5));

      if (onetime) break;
    }
  }

  Filter? parseFilters(String line) {
    try {
      RegExp filtersRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) harvester $floraProxy[a-z]+\\.harvester\\.harvester\\s*:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots",
          multiLine: false);

      var match = filtersRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
            match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

        //if filter is in cache
        bool inCache =
            filters.any((cachedFilter) => cachedFilter.timestamp == timestamp);

        if (!inCache) {
          //print(timestamp);

          int eligiblePlots = int.parse(match.group(4) ?? '0');
          int proofs = int.parse(match.group(5) ?? '0');
          double time = double.parse(match.group(6) ?? '0.0');
          int totalPlots = int.parse(match.group(7) ?? '0');

          final Filter filter =
              Filter(timestamp, eligiblePlots, proofs, time, totalPlots);

          return filter;
        }
      } catch (Exception) {
        log.warning("Error parsing filters!");
      }
    } catch (e) {}

    return null;
  }

  SignagePoint? parseSignagePoints(String line) {
    try {
      RegExp signagePointsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node $floraProxy[a-z]+\\.full\\_node\\.full\\_node\\s*:\\s+INFO\\W+Finished[\\S ]+ ([0-9]+)\\/64",
          multiLine: false);

      var match = signagePointsRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = 0;

      try {
        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
            match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

        bool inCache = signagePoints
            .any((signagePoint) => signagePoint.timestamp == timestamp);

        //only adds subslot if its not already in cache
        if (!inCache) {
          int index = int.parse(match.group(4) ?? '0');

          final SignagePoint signagePoint = SignagePoint(timestamp, index);
          return signagePoint;
        }
      } catch (Exception) {
        log.warning("Error parsing filters!");
      }
    } catch (e) {}

    return null;
  }

  ShortSync? parseShortSyncs(String line) {
    try {
      RegExp shortSyncsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node $floraProxy[a-z]+\\.full\\_node\\.full\\_node\\s*:\\s+INFO\\W+Starting batch short sync from ([0-9]+) to height ([0-9]+)",
          multiLine: false);

      var match = shortSyncsRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = 0;

      try {
        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
            match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

        bool inCache =
            shortSyncs.any((shortSync) => shortSync.timestamp == timestamp);

        //only adds subslot if its not already in cache
        if (!inCache) {
          int start = int.parse(match.group(4) ?? '1');
          int end = int.parse(match.group(5) ?? '2');

          final ShortSync shortSync = ShortSync(timestamp, start, end);

          return shortSync;
        }
      } catch (Exception) {
        log.warning("Error parsing filters!");
      }
    } catch (e) {}

    return null;
  }

  LogItem? parseErrors(String line, ErrorType type) {
    try {
      final errorText;

      switch (type) {
        case ErrorType.Pool:
          errorText = "Error sending partial to";
          break;
        case ErrorType.Harvester:
          errorText = "Harvester did not respond";
          break;
      }

      RegExp errorsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) farmer $floraProxy[a-z]+\\.farmer\\.farmer\\s*:\\s+ERROR\\s+$errorText",
          multiLine: false);

      var match = errorsRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = 0;

      try {
        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
            match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

        bool inCache = (type == ErrorType.Pool ? poolErrors : harvesterErrors)
            .any((cached) => cached.timestamp == timestamp);
        //only adds subslot if its not already in cache
        if (!inCache) {
          final LogItem error = LogItem(timestamp, LogItemType.Farmer);

          return error;
        }
      } catch (Exception) {
        log.warning("Error parsing filters!");
      }
    } catch (e) {}

    return null;
  }

  filterDuplicateLogs() {
    filterDuplicateFilters();
    filters.shuffle();

    filterDuplicateSignagePoints();
    _genSubSlots();

    filterDuplicateErrors();
  }

  _genSubSlots() {
    subSlots = [];
    //orders signage points by timestamps
    signagePoints.sort((s1, s2) => s1.timestamp.compareTo(s2.timestamp));

    for (SignagePoint signagePoint in signagePoints) {
      SubSlot? subSlot;

      if (signagePoint.index != 1) {
        try {
          subSlot = subSlots
              .where((point) =>
                  point.lastStep == signagePoint.index - 1 && !point.complete)
              .last;
        } catch (Exception) {
          //print(currentStep);
        }
      }

      if (subSlots.length == 0 || subSlot == null)
        subSlots.add(new SubSlot([signagePoint], subSlots.length == 0));
      else
        subSlot.addSignagePoint(signagePoint);
    }

    try {
      //Won't count with last SubSlot if it's incomplete
      if (!subSlots.last.complete) subSlots.removeLast();
    } catch (e) {}
  }

  void filterDuplicateFilters() {
//Removes filters with same timestamps!
    final ids = _filters.map((filter) => filter.timestamp).toSet();
    _filters.retainWhere((filter) => ids.remove(filter.timestamp));
  }

  void filterDuplicateSignagePoints() {
//Removes subslots with same timestamps!
    final ids =
        signagePoints.map((signagePoint) => signagePoint.timestamp).toSet();
    signagePoints
        .retainWhere((signagePoint) => ids.remove(signagePoint.timestamp));
  }

  void filterDuplicateErrors() {
    final List<ErrorType> types = ErrorType.values;

    for (var type in types) {
//Removes pool/harvester errors with same timestamps!
      final ids = (type == ErrorType.Pool ? poolErrors : harvesterErrors)
          .map((error) => error.timestamp)
          .toSet();
      (type == ErrorType.Pool ? poolErrors : harvesterErrors)
          .retainWhere((error) => ids.remove(error.timestamp));
    }
  }
}
