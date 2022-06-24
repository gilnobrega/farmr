import 'dart:core';
import 'dart:isolate';
import 'package:farmr_client/config.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

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
  String _binaryName;

  late String debugPath;

  List<Filter> filters = [];

  List<SignagePoint> signagePoints = [];

  //Generate list of complete/incomplete subslots from _signagePoints
  List<SubSlot> subSlots = [];

  List<ShortSync> shortSyncs = [];

  List<LogItem> poolErrors = [];
  List<LogItem> harvesterErrors = [];

  late final String floraProxy;

  late final List<String> regexes;

  late final Duration logParseIntervalDuration;

  Log(
      String logPath,
      bool parseLogs,
      this._binaryName,
      this._type,
      String configPath,
      String binPath,
      bool firstInit,
      Duration this.logParseIntervalDuration) {
    debugPath = logPath + "/debug.log";

    if (_binaryName == "flora")
      floraProxy = "flora_proxy: ";
    else
      floraProxy = "";

    if (parseLogs) {
      //if nothing was found then it
      //assumes log level is not set to info
      if (firstInit &&
          filters.length == 0 &&
          signagePoints.length == 0 &&
          shortSyncs.length == 0 &&
          _type != ClientType.HPool) {
        setLogLevelToInfo(configPath, binPath);
      }
    }
  }

  Future<void> setLogLevelToInfo(String configPath, String binPath) async {
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
            binPath, const ["configure", "--set-log-level", "INFO"]);

        configYaml = loadYaml(
            io.File(configFile).readAsStringSync().replaceAll("!!set", ""));

        logLevel = configYaml['farmer']['logging']['log_level'];

        if (logLevel == "INFO") {
          print("$_binaryName's log level has been set to INFO");
          print("Restarting $_binaryName's services");
          if (_type == ClientType.Farmer)
            io.Process.run(binPath, const ["start", "-r", "farmer"]);
          else if (_type == ClientType.Harvester)
            io.Process.run(binPath, const ["start", "-r", "harvester"]);
        }
      }
    } catch (error) {}
  }

  Future<void> initLogParsing(bool parseLogs, bool onetime,
      String currencySymbol, int index, SendPort sendPort) async {
    if (!parseLogs) return;

    var result = <int>[];
    var initial = 0;

    final newLine = '\n'.codeUnitAt(0);

    final io.File debugFile = io.File(debugPath);

    if (!debugFile.existsSync()) {
      sendPort.send([
        index,
        "${debugFile.path} not found. Disabling Log Parser for ${currencySymbol}"
      ]);
      return;
    }

    while (true) {
      final size = debugFile.statSync().size;

      if (initial > size) initial = 0;

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

      for (final line in linesToParse) {
        SignagePoint? sp = _parseSignagePoint(line);
        if (sp != null) {
          signagePoints.add(sp);
          continue;
        }

        Filter? filter = _parseFilter(line);
        if (filter != null) {
          filters.add(filter);
          continue;
        }

        ShortSync? shortSync = _parseShortSync(line);
        if (shortSync != null) {
          shortSyncs.add(shortSync);
          continue;
        }

        LogItem? error = _parseError(line, ErrorType.Pool) ??
            _parseError(line, ErrorType.Harvester);
        if (error != null) {
          if (error.type == ErrorType.Pool)
            poolErrors.add(error);
          else if (error.type == ErrorType.Harvester)
            harvesterErrors.add(error);

          continue;
        }
      }

      final parseUntil =
          DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

      filters.removeWhere((element) => element.timestamp < parseUntil);
      signagePoints.removeWhere((element) => element.timestamp < parseUntil);
      shortSyncs.removeWhere((element) => element.timestamp < parseUntil);
      poolErrors.removeWhere((element) => element.timestamp < parseUntil);
      harvesterErrors.removeWhere((element) => element.timestamp < parseUntil);

      sendPort.send([
        index,
        <Object>[
          filters,
          signagePoints,
          shortSyncs,
          poolErrors,
          harvesterErrors
        ]
      ]);

      await Future.delayed(logParseIntervalDuration);

      if (onetime) break;
    }

    sendPort
        .send([index, "${currencySymbol.toUpperCase()}: stopped log parser"]);
  }

  Filter? _parseFilter(String line) {
    try {
      RegExp filtersRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) harvester $floraProxy[a-z]+\\.harvester\\.harvester\\s*:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots",
          multiLine: false);

      var match = filtersRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = DateTime.now().millisecondsSinceEpoch;

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
    } catch (e) {
      log.warning("Error parsing filter! " + e.toString());
      log.warning(line);
    }

    return null;
  }

  SignagePoint? _parseSignagePoint(String line) {
    try {
      RegExp signagePointsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node $floraProxy[a-z]+\\.full\\_node\\.full\\_node\\s*:\\s+INFO\\W+Finished[\\S ]+ ([0-9]+)\\/64",
          multiLine: false);

      var match = signagePointsRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = 0;

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
    } catch (e) {
      log.warning("Error parsing signage point! " + e.toString());
      log.warning(line);
    }
    return null;
  }

  ShortSync? _parseShortSync(String line) {
    try {
      RegExp shortSyncsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node $floraProxy[a-z]+\\.full\\_node\\.full\\_node\\s*:\\s+INFO\\W+Starting batch short sync from ([0-9]+) to height ([0-9]+)",
          multiLine: false);

      var match = shortSyncsRegex.firstMatch(line);

      if (match == null) return null;

      int timestamp = 0;

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
    } catch (e) {
      log.warning("Error parsing short sync event! " + e.toString());
      log.warning(line);
    }
    return null;
  }

  LogItem? _parseError(String line, ErrorType type) {
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
    } catch (e) {
      log.warning("Error parsing ${type} error! " + e.toString());
      log.warning(line);
    }
    return null;
  }

  genSubSlots() {
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
}
