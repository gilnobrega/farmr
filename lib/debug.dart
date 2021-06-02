import 'dart:core';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:chiabot/cache.dart';
import 'package:chiabot/log/filter.dart';
import 'package:chiabot/log/subslot.dart';
import 'package:chiabot/log/logitem.dart';
import 'package:chiabot/log/signagepoint.dart';
import 'package:chiabot/log/shortsync.dart';

final log = Logger('LOG');

class Log {
  Cache _cache;

  late String debugPath;
  late io.File _debugFile;
  late int _parseUntil;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SignagePoint> _signagePoints = [];

  //Generate list of complete/incomplete subslots from _signagePoints
  List<SubSlot> subSlots = [];

  List<ShortSync> shortSyncs = [];

  Log(String chiaDebugPath, this._cache, bool parseLogs) {
    _parseUntil = _cache.parseUntil;
    _filters = _cache.filters; //loads cached filters
    _signagePoints = _cache.signagePoints; //loads cached subslots
    shortSyncs = _cache.shortSyncs;

    debugPath = chiaDebugPath + "debug.log";
    _debugFile = io.File(debugPath);

    if (parseLogs) {
      loadLogItems();
      _cache.saveFilters(filters);
      _cache.saveSignagePoints(_signagePoints); //saves signagePoints to cache
      _cache.saveShortSyncs(shortSyncs);
    }
  }

  loadLogItems() {
    bool keepParsing = true;
    bool keepParsingFilters = true;
    bool keepParsingSignagePoints = true;
    bool keepParsingShortSyncs = true;
    //parses debug.log, debug.log.1, debug.log.2, ...
    for (int i = 0; i < 10; i++) {
      if (keepParsing) {
        String ext = (i == 0) ? '' : ('.' + i.toString());

        try {
          _debugFile = io.File(debugPath + ext);

          //stops parsing once it reaches parseUntil date limit
          if (_debugFile.existsSync()) {
            String content;

            try {
              content = _debugFile.readAsStringSync();
            } catch (e) {
              var bytes = _debugFile.readAsBytesSync();

              //reads files this way because of UTF 16 decoding??
              content = utf8.decode(bytes, allowMalformed: true);
            }

            //parses filters
            if (keepParsingFilters) {
              try {
                keepParsingFilters = parseFilters(content, _parseUntil);
              } catch (e) {
                log.warning(
                    "Warning: could not parse filters in debug.log$ext, make sure chia log level is set to INFO");
              }
            }

            //parses signage points
            if (keepParsingSignagePoints) {
              try {
                keepParsingSignagePoints =
                    parseSignagePoints(content, _parseUntil);
              } catch (e) {
                log.info(
                    "Warning: could not parse SubSlots in debug.log$ext, make sure chia log level is set to INFO");
              }
            }

            //parses signage points
            if (keepParsingShortSyncs) {
              try {
                keepParsingShortSyncs = parseShortSyncs(content, _parseUntil);
              } catch (e) {
                log.info(
                    "Warning: could not parse Short Sync events in debug.log$ext, make sure chia log level is set to INFO");
              }
            }
          }
        } catch (Exception) {
          log.warning(
              "Warning: could not parse debug.log$ext, make sure chia log level is set to INFO");
        }

        //stops loading more files when all of the logging items stop parsing
        keepParsing = keepParsingFilters ||
            keepParsingSignagePoints ||
            keepParsingShortSyncs;
      }
    }

    filterDuplicateFilters();
    filters.shuffle();

    filterDuplicateSignagePoints();
    _genSubSlots();
  }

  //Parses debug file and looks for filters
  bool parseFilters(String contents, int parseUntil) {
    bool keepParsing = true;
    bool inCache = false;

    try {
      RegExp filtersRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) harvester chia\\.harvester\\.harvester:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots",
          multiLine: true);

      var matches = filtersRegex.allMatches(contents).toList();

      int timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int i = matches.length - 1; i >= 0; i--) {
        try {
          if (keepParsing && !inCache) {
            RegExpMatch match = matches[i];

            //Parses date from debug.log
            timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
                match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

            //if filter's timestamp is outside parsing date rang
            keepParsing = timestamp > parseUntil;

            //if filter is in cache
            inCache = filters
                .any((cachedFilter) => cachedFilter.timestamp == timestamp);

            if (!inCache && keepParsing) {
              //print(timestamp);

              int eligiblePlots = int.parse(match.group(4) ?? '0');
              int proofs = int.parse(match.group(5) ?? '0');
              double time = double.parse(match.group(6) ?? '0.0');
              int totalPlots = int.parse(match.group(7) ?? '0');
              Filter filter =
                  Filter(timestamp, eligiblePlots, proofs, time, totalPlots);

              _filters.add(filter);
            }
          }
        } catch (Exception) {
          log.warning("Error parsing filters!");
        }
      }
    } catch (e) {
      log.warning(
          "Warning: could not parse filters, make sure chia log level is set to INFO");
    }

    return keepParsing && !inCache;
  }

  parseSignagePoints(String contents, int parseUntil) {
    bool keepParsing = true;
    bool inCache = false;

    try {
      RegExp signagePointsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node chia\\.full\\_node\\.full\\_node:\\s+INFO\\W+Finished[\\S ]+ ([0-9]+)\\/64",
          multiLine: true);

      var matches = signagePointsRegex.allMatches(contents).toList();
      int timestamp = 0;

      for (int i = 0; i < matches.length; i++) {
        var match = matches[i];

        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
            match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

        //if filter's timestamp is outside parsing date rang
        keepParsing = timestamp > parseUntil;

        inCache = _signagePoints
            .any((signagePoint) => signagePoint.timestamp == timestamp);

        //only adds subslot if its not already in cache
        if (keepParsing && !inCache) {
          int index = int.parse(match.group(4) ?? '0');

          SignagePoint signagePoint = SignagePoint(timestamp, index);
          _signagePoints.add(signagePoint);
        }
      }
    } catch (Exception) {
      log.info("Error parsing signage points.");
    }

    return keepParsing && !inCache;
  }

  _genSubSlots() {
    subSlots = [];

    for (SignagePoint signagePoint in _signagePoints) {
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

  parseShortSyncs(String contents, int parseUntil) {
    bool keepParsing = true;
    bool inCache = false;

    try {
      RegExp shortSyncsRegex = RegExp(
          "([0-9-]+)T([0-9:]+)\\.([0-9]+) full_node chia\\.full\\_node\\.full\\_node:\\s+INFO\\W+Starting batch short sync from ([0-9]+) to height ([0-9]+)",
          multiLine: true);

      var matches = shortSyncsRegex.allMatches(contents).toList();
      int timestamp = 0;

      for (int i = 0; i < matches.length; i++) {
        var match = matches[i];

        //Parses date from debug.log
        timestamp = parseTimestamp(match.group(1) ?? '1971-01-01',
            match.group(2) ?? '00:00:00', match.group(3) ?? '0000');

        keepParsing = timestamp > parseUntil;

        inCache =
            shortSyncs.any((shortSync) => shortSync.timestamp == timestamp);

        //only adds subslot if its not already in cache
        if (keepParsing && !inCache) {
          int start = int.parse(match.group(4) ?? '1');
          int end = int.parse(match.group(5) ?? '2');

          ShortSync shortSync = ShortSync(timestamp, start, end);
          shortSyncs.add(shortSync);
        }
      }
    } catch (Exception) {
      log.info("Error parsing short sync events.");
    }
    return keepParsing && !inCache;
  }

  void filterDuplicateFilters() {
//Removes filters with same timestamps!
    final ids = _filters.map((filter) => filter.timestamp).toSet();
    _filters.retainWhere((filter) => ids.remove(filter.timestamp));
  }

  void filterDuplicateSignagePoints() {
//Removes subslots with same timestamps!
    final ids =
        _signagePoints.map((signagePoint) => signagePoint.timestamp).toSet();
    _signagePoints
        .retainWhere((signagePoint) => ids.remove(signagePoint.timestamp));
  }
}
