import 'dart:io' as io;
import 'dart:math' as Math;
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class NetSpace {
  double _size = 0;
  double get size => _size;

  String get humanReadableSize => generateHumanReadableSize(size);
  String get dayDifference => _getDayDifference();

  int _timestamp = 0;
  int get timestamp => _timestamp;

  final int _untilTimeStamp =
      DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;
  final io.File _cacheFile = io.File("netspace.json");

  String _source = "chianetspace.com";
  String get source => _source;

  //timestamp, size
  Map<String, double> pastSizes = {};

  Map toJson() => {
        "timestamp": timestamp,
        "size": size,
        "pastSizes": pastSizes,
        "source": source
      };

  NetSpace([String humanReadableSize = null]) {
    if (humanReadableSize != null) {
      try {
        _timestamp = DateTime.now().millisecondsSinceEpoch;
        _size = sizeStringToInt(humanReadableSize);
      } catch (e) {}
    }
  }

  //genCache=true forces generation of netspace.json file
  init([bool genCache = false]) async {
    if (_cacheFile.existsSync() && !genCache)
      await _load();
    else {
      await _getNetSpace();
      await _getPastSizes();
      _save();
    }
  }

  _getNetSpace() async {
    try {
      String contents = await http
          .read("https://chianetspace.azurewebsites.net/data/summary");

      var content = jsonDecode(contents);

      var sizeString = content['netSpace']['largestWholeNumberBinaryValue'];
      var units = content['netSpace']['largestWholeNumberBinarySymbol'];
      //temporary override while chianetspace.com doesn't fix their website
      units = "EiB";

      _size = sizeStringToInt('${sizeString} ${units}');
    } catch (e) {}

    try {
      //if chianetspaceapi.com fails then gets netspace from chiacalculator.com
      if (_size == 0) {
        //<dd class="chakra-stat__number css-mu2u4q">8.032<!-- --> <!-- -->EiB</dd>
        String contents = await http.read("https://chiacalculator.com");
        RegExp regex = new RegExp(">([0-9\\.]+)<!-- --> <!-- -->([A-Z])iB");
        var matches = regex.allMatches(contents);

        for (var match in matches)
          if (_size == 0)
            _size = sizeStringToInt('${match.group(1)} ${match.group(2)}iB');

        _source = "chiacalculator.com";
      }
    } catch (e) {}
  }

  _getPastSizes() async {
    try {
      String contents =
          await http.read("http://alpha2.chianetspace.com/data.php");

      var array = jsonDecode(contents);

      for (var pastSize in array) {
        //parses timestamp and accounts for ChiaNetSpace's timezone
        int timestamp = DateFormat('y-M-d')
                .parseUTC(pastSize['date'])
                .millisecondsSinceEpoch -
            Duration(hours: 3).inMilliseconds;
        double size = sizeStringToInt("${pastSize['netspace']} PiB");
        pastSizes.putIfAbsent(timestamp.toString(), () => size);
      }
    } catch (e) {}
  }

  String _getDayDifference() {
    var entries = pastSizes.entries.toList();
    entries.sort((entry1, entry2) =>
        int.parse(entry2.key).compareTo(int.parse(entry1.key)));

    String percentage = '';
    if (entries.length > 1)
      percentage = percentageDiff(
          {"${this.timestamp}": this.size}.entries.first,
          entries[0],
          true,
          entries[1]);

    return percentage;
  }

  //Always shows 24 hour average increase
  static String percentageDiff(MapEntry size1, MapEntry size2,
      [bool showAbsoluteSize = false, MapEntry size3]) {
    String growth = '';
    int millisecondsInDay = Duration(days: 1).inMilliseconds;

    int timeDiff = int.parse(size1.key) - int.parse(size2.key);
    double timeRatio = millisecondsInDay / timeDiff;

    //if timestamps between size1 and size2 netspaces are shorter than a day
    //then it will use a third timestamp called size3
    if (timeRatio > 1 && size3 != null) {
      timeDiff = int.parse(size1.key) - int.parse(size3.key);
      timeRatio = millisecondsInDay / timeDiff;
      size2 = size3; //this looks so bad i need to fix this
    }

    double sizeRatio = 100 * ((size1.value / size2.value) - 1);

    double ratio = timeRatio * sizeRatio;
    int avgSizeDiff = (timeRatio * (size1.value - size2.value)).round();

    var sign = (ratio > 0) ? "+" : "-";

    String absoluteSize = '';

    if (showAbsoluteSize)
      absoluteSize = "${sign}${generateHumanReadableSize(avgSizeDiff / 1.0)}, ";

    growth = "${absoluteSize}${sign}${ratio.abs().toStringAsFixed(1)}%";

    return growth;
  }

  _save() {
    _timestamp = DateTime.now().millisecondsSinceEpoch;

    String serial = jsonEncode(this);
    _cacheFile.writeAsStringSync(serial);
  }

  _load() async {
    var json = jsonDecode(_cacheFile.readAsStringSync());
    NetSpace previousNetSpace = NetSpace.fromJson(json);

    //loads old past sizes
    pastSizes = previousNetSpace.pastSizes;

    //if last time price was parsed from api was longer than 1 minute ago
    //then parses new price from api
    if (previousNetSpace.timestamp < _untilTimeStamp) {
      await _getNetSpace();

      //adds new past sizes while keeping old ones
      await _getPastSizes();

      _save();
    } else {
      _timestamp = previousNetSpace.timestamp;
      _size = previousNetSpace.size;
      _source = previousNetSpace.source;
    }
  }

  static final Map<String, int> units = {
    "K": 1,
    "M": 2,
    "G": 3,
    'T': 4,
    'P': 5,
    'E': 6
  };
  static final Map<String, int> bases = {'B': 1000, 'iB': 1024};

  //generates a human readable string in xiB from an int size in bytes
  static String generateHumanReadableSize(double size) {
    try {
      var unit;
      for (var entry in units.entries) {
        if (size >= Math.pow(bases['iB'], entry.value)) unit = entry;
      }

      double value = size / (Math.pow(bases['iB'], unit.value) * 1.0);

      return "${value.toStringAsFixed(3)} ${unit.key}iB";
    } catch (e) {
      return "0 B"; //when api fails
    }
  }

  static double sizeStringToInt(String netspace) {
    double size = 0;

    //converts xiB or xB to bytes
    for (var base in bases.entries) {
      for (var unit in units.entries) {
        if (netspace.contains("${unit.key}${base.key}")) {
          double value = double.parse(
              netspace.replaceAll("${unit.key}${base.key}", "").trim());
          size = (value * (Math.pow(base.value, unit.value)));

          return size;
        }
      }
    }

    return size;
  }

  NetSpace.fromJson(dynamic json) {
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
    if (json['size'] != null) _size = json['size'];

    if (json['pastSizes'] != null)
      pastSizes = Map<String, double>.from(json['pastSizes']);

    if (json['source'] != null) _source = json['source'];
  }
}
