import 'dart:core';
import 'dart:io' as io;

import 'package:logging/logging.dart';

import 'cache.dart';

import 'log/filter.dart';
import 'log/subslot.dart';
import 'log/logitem.dart';

final log = Logger('LOG');

class Log {
  String debugPath;
  io.File _debugFile;
  int _parseUntil;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SubSlot> signagePoints = [];

  Log(String chiaDebugPath, Cache cache, bool parseLogs) {
    _parseUntil = cache.parseUntil;
    _filters = cache.filters; //loads cached filters

    debugPath = chiaDebugPath + "debug.log";

    if (parseLogs) {
      loadFilters();
      cache.saveFilters(filters);
    }
  }

  loadFilters() {
    //parses debug.log, debug.log.1, debug.log.2, ...
    //
    bool keepParsing = true;

    for (int i = 0; i < 10; i++) {
      if (keepParsing) {
        String ext = (i == 0) ? '' : ('.' + i.toString());

        try {
          _debugFile = io.File(debugPath + ext);

          //stops parsing once it reaches parseUntil date limit
          if (_debugFile.existsSync())
            keepParsing = parseFilters(_debugFile.readAsStringSync(), _parseUntil);
        } catch (Exception) {
          print(
              "Warning: could not parse filters in debug.log${ext}, make sure chia log level is set to INFO");
        }
      }
    }

    filterDuplicates();

    filters.shuffle();
  }

  loadSubSlots() {
    for (int i = 9; i >= 0; i--) {
      String ext = (i == 0) ? '' : ('.' + i.toString());

      try {
        _debugFile = io.File(debugPath + ext);

        //stops parsing once it reaches parseUntil date limit
        if (_debugFile.existsSync()) parseSignagePoints(_debugFile.readAsStringSync(), _parseUntil);
      } catch (Exception) {
        print(
            "Warning: could not parse SubSlots in debug.log${ext}, make sure chia log level is set to INFO");
      }
    }
  }

  //Parses debug file and looks for filters
  bool parseFilters(String contents, int parseUntil) {
    RegExp filtersRegex = RegExp(
        "([0-9-]+)T([0-9:]+)\\.([0-9]+) harvester chia\\.harvester\\.harvester:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots\\s",
        multiLine: true);

    var matches = filtersRegex.allMatches(contents).toList();

    int timestamp = DateTime.now().millisecondsSinceEpoch;

    bool keepParsing = true;
    bool inCache = false;

    for (int i = matches.length - 1; i >= 0; i--) {
      try {
        if (keepParsing && !inCache) {
          RegExpMatch match = matches[i];

          //Parses date from debug.log
          timestamp = parseTimestamp(match.group(1), match.group(2), match.group(3));

          //if filter's timestamp is outside parsing date rang
          keepParsing = timestamp > parseUntil;

          //if filter is in cache
          inCache = filters.any((cachedFilter) => cachedFilter.timestamp == timestamp);

          if (!inCache && keepParsing) {
            //print(timestamp);

            int eligiblePlots = int.parse(match.group(4));
            int proofs = int.parse(match.group(5));
            double time = double.parse(match.group(6));
            int totalPlots = int.parse(match.group(7));
            Filter filter = Filter(timestamp, eligiblePlots, proofs, time, totalPlots);

            _filters.add(filter);
          }
        }
      } catch (Exception) {
        print("Error parsing filters!");
      }
    }

    return keepParsing && !inCache;
  }

  SubSlot parseSignagePoints(String contents, int parseUntil) {
    try {
      RegExp signagePointsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node chia\\.full\\_node\\.full\\_node:\\s+INFO\\W+Finished[\\S ]+ ([0-9]+)\\/64",
          multiLine: true);

      var matches = signagePointsRegex.allMatches(contents).toList();
      int timestamp = 0;

      for (int i = 0; i < matches.length; i++) {
        var match = matches[i];

        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1), match.group(2), match.group(3));

        if (timestamp > parseUntil) {
          int currentStep = int.parse(match.group(4));

          SubSlot signagePoint;

          if (currentStep != 1) {
            try {
              signagePoint = signagePoints
                  .where((point) => point.lastStep == currentStep - 1 && !point.complete)
                  .last;
            } catch (Exception) {
              //print(currentStep);
            }
          }

          if (signagePoints.length == 0 || signagePoint == null)
            signagePoints
                .add(new SubSlot(timestamp, [currentStep], signagePoints.length == 0));
          else
            signagePoint.addSignagePoint(currentStep);
        }
      }
    } catch (Exception) {
      print("Error parsing signage points.");
    }

    return signagePoints.last;
  }

  void filterDuplicates() {
//Removes filters with same timestamps!
    final ids = _filters.map((filter) => filter.timestamp).toSet();
    _filters.retainWhere((filter) => ids.remove(filter.timestamp));
  }
}
