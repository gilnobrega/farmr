import 'dart:io' as io;
import 'dart:math' as Math;
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class NetSpace {
  int _size = 0;
  int get size => _size;

  String get humanReadableSize => generateHumanReadableSize(size);
  String get dayDifference => _getDayDifference();

  int _timestamp = 0;
  int get timestamp => _timestamp;

  final int _untilTimeStamp = DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;
  final io.File _cacheFile = io.File("netspace.json");

  static final Map<String, int> units = {"K": 1, "M": 2, "G": 3, 'T': 4, 'P': 5, 'E': 6};
  static final Map<String, int> bases = {'B': 1000, 'iB': 1024};

  //timestamp, size
  Map<String, int> pastSizes = {};

  Map toJson() => {"timestamp": timestamp, "size": size, "pastSizes": pastSizes};

  NetSpace([String humanReadableSize = null]) {
    if (humanReadableSize != null) {
      try {
        _timestamp = DateTime.now().millisecondsSinceEpoch;
        _size = sizeStringToInt(humanReadableSize);
      } catch (e) {}
    }
  }

  init() async {
    if (_cacheFile.existsSync())
      await _load();
    else {
      await _getNetSpace();
      await _getPastSizes();
      _save();
    }
  }

  _getNetSpace() async {
    try {
      String contents = await http.read("https://chianetspace.azurewebsites.net/data/summary");

      var content = jsonDecode(contents);

      var sizeString = content['netSpace']['largestWholeNumberBinaryValue'];
      var units = content['netSpace']['largestWholeNumberBinarySymbol'];

      _size = sizeStringToInt('${sizeString} ${units}');
    } catch (e) {}
  }

  _getPastSizes() async {
    try {
      String contents = await http.read("http://alpha2.chianetspace.com/data.php");

      var array = jsonDecode(contents);

      for (var pastSize in array) {
        int timestamp = DateFormat('y-M-d').parse(pastSize['date']).millisecondsSinceEpoch;
        int size = sizeStringToInt("${pastSize['netspace']} PiB");
        pastSizes.putIfAbsent(timestamp.toString(), () => size);
      }
    } catch (e) {}
  }

  String _getDayDifference() {
    var entries = pastSizes.entries.toList();
    if (entries.length > 0) entries.removeLast();
    entries.sort((entry1, entry2) => int.parse(entry2.key).compareTo(int.parse(entry1.key)));

    String percentage = '';
    if (entries.length > 0) percentage = percentageDiff(size, entries.first.value, true);

    return percentage;
  }

  static String percentageDiff(int size1, int size2, [bool showAbsoluteSize = false]) {
    double ratio = 100 * ((size1 / size2) - 1);

    var sign = (ratio > 0) ? "+" : "-";

    String absoluteSize = '';

    if (showAbsoluteSize) absoluteSize = "${sign}${generateHumanReadableSize(size1 - size2)}, ";

    String percentage = "(${absoluteSize}${sign}${ratio.abs().toStringAsFixed(1)}%)";

    return percentage;
  }

  _save() {
    _timestamp = DateTime.now().millisecondsSinceEpoch;

    String serial = jsonEncode(this);
    _cacheFile.writeAsStringSync(serial);
  }

  _load() async {
    var json = jsonDecode(_cacheFile.readAsStringSync());
    NetSpace previousNetSpace = NetSpace.fromJson(json);

    //if last time price was parsed from api was longer than 1 minute ago
    //then parses new price from api
    if (previousNetSpace.timestamp < _untilTimeStamp) {
      await _getNetSpace();
      await _getPastSizes();

      _save();
    } else {
      _timestamp = previousNetSpace.timestamp;
      _size = previousNetSpace.size;
      pastSizes = previousNetSpace.pastSizes;
    }
  }

  //generates a human readable string in xiB from an int size in bytes
  static String generateHumanReadableSize(int size) {
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

  static int sizeStringToInt(String netspace) {
    int size = 0;

    //converts xiB or xB to bytes
    for (var base in bases.entries) {
      for (var unit in units.entries) {
        if (netspace.contains("${unit.key}${base.key}")) {
          double value = double.parse(netspace.replaceAll("${unit.key}${base.key}", "").trim());
          size = (value * (Math.pow(base.value, unit.value))).round();

          return size;
        }
      }
    }

    return size;
  }

  NetSpace.fromJson(dynamic json) {
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
    if (json['size'] != null) _size = json['size'];

    if (json['pastSizes'] != null) pastSizes = Map<String, int>.from(json['pastSizes']);
  }
}
