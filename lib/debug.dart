import 'dart:core';
import 'dart:io' as io;

class Log {
  //Sets config file path according to platform
  String _chiaDebugPath = (io.Platform.isLinux)
      ? io.Platform.environment['HOME'] + "/.chia/mainnet/log/"
      : (io.Platform.isWindows)
          ? io.Platform.environment['UserProfile'] + "\\.chia\\mainnet\\log\\"
          : "";

  String debugPath;
  io.File _debugFile;

  String currentDay = dateToString(DateTime.now());

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  Log() {
    debugPath = _chiaDebugPath + "debug.log";

    //parses debug.log, debug.log.1, debug.log.2, ...
    for (int i = 0; i < 10; i++) {
      String ext = (i == 0) ? '' : ('.' + i.toString());

      try {
        _debugFile = io.File(_chiaDebugPath + "debug.log" + ext);

        if (_debugFile.existsSync()) parseDebug(_debugFile.readAsStringSync());
      } catch (Exception) {
        print("Failed to parse debug.log");
      }
    }

    filters
        .shuffle(); //shuffles filters so that harvester can't be tracked by answered challenges time
  }

  //Parses debug file and looks for filters
  void parseDebug(String contents) {
    RegExp filtersRegex = RegExp(
        currentDay +
            "T(\\S+) harvester chia\\.harvester\\.harvester:\\s+INFO\\s+([0-9]+) plots were eligible for farming \\S+ Found ([0-9]+) proofs\\. Time: ([0-9\\.]+) s\\. Total ([0-9]+) plots\\s",
        multiLine: true);

    var matches = filtersRegex.allMatches(contents);

    for (var match in matches) {
      try {
        _filters.add(Filter(match));
      } catch (Exception) {
        print("Error parsing filters!");
      }
    }
  }
}

class Filter {
  String _timestamp; //debug purposes

  int _eligiblePlots = 0; //number of eligible plots
  int get eligiblePlots => _eligiblePlots;

  int _proofs = 0; //number of proofs
  int get proofs => _proofs;

  double _time = 0; //challenge reponse time
  double get time => _time;

  int _totalPlots = 0; //total number of plots
  int get totalPlots => _totalPlots;

  Map toJson() => {'eligible': eligiblePlots, 'proofs': proofs, 'time': time, 'total': totalPlots};

  Filter(RegExpMatch match) {
    _timestamp = match.group(1);
    _eligiblePlots = int.parse(match.group(2));
    _proofs = int.parse(match.group(3));
    _time = double.parse(match.group(4));
    _totalPlots = int.parse(match.group(5));
  }

  Filter.fromJson(dynamic json) {
    if (json['eligible'] != null) _eligiblePlots = json['eligible'];
    if (json['proofs'] != null) _proofs = json['proofs'];
    if (json['time'] != null) _time = json['time'];
    if (json['total'] != null) _totalPlots = json['total'];
  }
}

String dateToString(DateTime date) {
  String month = date.month.toString();
  String day = date.day.toString();

  if (month.length == 1) month = "0" + month;
  if (day.length == 1) day = "0" + day;

  return date.year.toString() + "-" + month + "-" + day;
}
