import 'dart:core';
import 'dart:io' as io;

import 'package:logging/logging.dart';

import 'package:chiabot/cache.dart';
import 'package:chiabot/log/filter.dart';
import 'package:chiabot/log/subslot.dart';
import 'package:chiabot/log/logitem.dart';
import 'package:chiabot/log/signagepoint.dart';

final log = Logger('LOG');

class Log {
  Cache _cache;

  String debugPath;
  io.File _debugFile;
  int _parseUntil;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SignagePoint> _signagePoints = [];

  //Generate list of complete/incomplete subslots from _signagePoints
  List<SubSlot> subSlots = [];

  Log(String chiaDebugPath, Cache cache, bool parseLogs) {
    _cache = cache;
    _parseUntil = _cache.parseUntil;
    _filters = _cache.filters; //loads cached filters
    _signagePoints = _cache.signagePoints; //loads cached subslots

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
          log.warning(
              "Warning: could not parse filters in debug.log${ext}, make sure chia log level is set to INFO");
        }
      }
    }

    filterDuplicateFilters();

    filters.shuffle();
  }

  loadSignagePoints() {
    for (int i = 9; i >= 0; i--) {
      String ext = (i == 0) ? '' : ('.' + i.toString());

      try {
        _debugFile = io.File(debugPath + ext);

        //stops parsing once it reaches parseUntil date limit
        if (_debugFile.existsSync()) parseSignagePoints(_debugFile.readAsStringSync(), _parseUntil);
      } catch (Exception) {
        log.info(
            "Warning: could not parse SubSlots in debug.log${ext}, make sure chia log level is set to INFO");
      }
    }

    filterDuplicateSignagePoints();
    _cache.saveSignagePoints(_signagePoints); //saves signagePoints to cache
    _genSubSlots();
  }

  //Parses debug file and looks for filters
  bool parseFilters(String contents, int parseUntil) {
    bool keepParsing = true;
    bool inCache = false;

    try {
      RegExp filtersRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) harvester chia\\.harvester\\.harvester:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots\\s",
          multiLine: true);

      var matches = filtersRegex.allMatches(contents).toList();

      int timestamp = DateTime.now().millisecondsSinceEpoch;

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
          log.warning("Error parsing filters!");
        }
      }
    } catch (e) {
      log.warning("Warning: could not parse filters, make sure chia log level is set to INFO");
    }

    return keepParsing && !inCache;
  }

  parseSignagePoints(String contents, int parseUntil) {
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

        bool inCache = _signagePoints.any((signagePoint) => signagePoint.timestamp == timestamp);

        //only adds subslot if its not already in cache
        if (timestamp > parseUntil && !inCache) {
          int index = int.parse(match.group(4));

          SignagePoint signagePoint = SignagePoint(timestamp, index);
          _signagePoints.add(signagePoint);
        }
      }
    } catch (Exception) {
      log.info("Error parsing signage points.");
    }
  }

  _genSubSlots() {
    subSlots = [];

    for (SignagePoint signagePoint in _signagePoints) {
      SubSlot subSlot;

      if (signagePoint.index != 1) {
        try {
          subSlot = subSlots
              .where((point) => point.lastStep == signagePoint.index - 1 && !point.complete)
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

    //Won't count with last SubSlot if it's incomplete
    if (!subSlots.last.complete) subSlots.removeLast();
  }

  void filterDuplicateFilters() {
//Removes filters with same timestamps!
    final ids = _filters.map((filter) => filter.timestamp).toSet();
    _filters.retainWhere((filter) => ids.remove(filter.timestamp));
  }

  void filterDuplicateSignagePoints() {
//Removes subslots with same timestamps!
    final ids = _signagePoints.map((signagePoint) => signagePoint.timestamp).toSet();
    _signagePoints.retainWhere((signagePoint) => ids.remove(signagePoint.timestamp));
  }
}
