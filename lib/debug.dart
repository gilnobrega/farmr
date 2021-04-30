import 'dart:core';
import 'dart:io' as io;

import 'package:intl/intl.dart';

import 'cache.dart';

class Log {
  String debugPath;
  io.File _debugFile;

  String currentDay = dateToString(DateTime.now());

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  Log(String chiaDebugPath, Cache cache) {
    _filters = cache.filters; //loads cached filters

    debugPath = chiaDebugPath + "debug.log";

    //parses debug.log, debug.log.1, debug.log.2, ...
    //
    bool keepParsing = true;

    for (int i = 0; i < 10; i++) {
      if (keepParsing) {
        String ext = (i == 0) ? '' : ('.' + i.toString());

        try {
          _debugFile = io.File(chiaDebugPath + "debug.log" + ext);

          //stops parsing once it reaches parseUntil date limit
          if (_debugFile.existsSync())
            keepParsing = parseFilters(_debugFile.readAsStringSync(), cache.parseUntil);
        } catch (Exception) {
          print("Failed to parse debug.log" + ext);
        }
      }
    }

    filterDuplicates();

    cache.saveFilters(filters);
  }

  //Parses debug file and looks for filters
  bool parseFilters(String contents, int parseUntil) {
    RegExp filtersRegex = RegExp(
        "(\\S+)T(\\S+)\\.([0-9]+) harvester chia\\.harvester\\.harvester:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots\\s",
        multiLine: true);

    var matches = filtersRegex.allMatches(contents).toList();

    int timestamp = DateTime.now().millisecondsSinceEpoch;

    bool keepParsing = true;
    bool inCache = false;

    for (int i = matches.length - 1; i >= 0; i--) {
      try {
        if (keepParsing && !inCache) {
          RegExpMatch match = matches[i];

          String timeString = match.group(1) + " " + match.group(2);

          int milliseconds = int.parse(match.group(3));
          //Parses date from debug.log
          timestamp =
              DateFormat('y-M-d H:m:s').parse(timeString).millisecondsSinceEpoch + milliseconds;

          //if filter's timestamp is outside parsing date rang
          keepParsing = timestamp > parseUntil;

          //if filter is in cache
          inCache = filters.any((cachedFilter) => cachedFilter._timestamp == timestamp);

          if (!inCache && keepParsing) {
            //print(timeString);

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

  void filterDuplicates() {
//Removes filters with same timestamps!
    final ids = _filters.map((filter) => filter.timestamp).toSet();
    _filters.retainWhere((filter) => ids.remove(filter.timestamp));
  }
}

class Filter {
  int _timestamp; //unix timestamp, id
  int get timestamp => _timestamp;

  int _eligiblePlots = 0; //number of eligible plots
  int get eligiblePlots => _eligiblePlots;

  int _proofs = 0; //number of proofs
  int get proofs => _proofs;

  double _time = 0; //challenge reponse time
  double get time => _time;

  int _totalPlots = 0; //total number of plots
  int get totalPlots => _totalPlots;

  Map toJson() => {
        'timestamp': timestamp,
        'eligible': eligiblePlots,
        'time': time /*'total': totalPlots, 'proofs': proofs*/
      };

  Filter(int timestamp, int eligiblePlots, int proofs, double time, int totalPlots) {
    _timestamp = timestamp;
    _eligiblePlots = eligiblePlots;
    _proofs = proofs;
    _time = time;
    _totalPlots = totalPlots;
  }

  Filter.fromJson(dynamic json) {
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
    if (json['eligible'] != null) _eligiblePlots = json['eligible'];
    //if (json['proofs'] != null) _proofs = json['proofs'];
    if (json['time'] != null) _time = json['time'];
    //if (json['total'] != null) _totalPlots = json['total'];
  }

  //Replaces long hash with timestamp id before sending to server
  void clearTimestamp() {
    _timestamp = null;
  }
}

String dateToString(DateTime date) {
  String month = date.month.toString();
  String day = date.day.toString();

  if (month.length == 1) month = "0" + month;
  if (day.length == 1) day = "0" + day;

  return date.year.toString() + "-" + month + "-" + day;
}
