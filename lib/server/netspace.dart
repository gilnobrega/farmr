import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:proper_filesize/proper_filesize.dart';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class NetSpace {
  var _cacheFile;

  double _size = 0;
  double get size => _size;

  String get humanReadableSize =>
      ProperFilesize.generateHumanReadableFilesize(size);
  String get dayDifference => _getDayDifference();

  int _timestamp = 0;
  int get timestamp => _timestamp;

  final int _untilTimeStamp =
      DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;

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

  NetSpace([String humanReadableSize = "0 B"]) {
    try {
      _timestamp = DateTime.now().millisecondsSinceEpoch;
      _size = ProperFilesize.parseHumanReadableFilesize(humanReadableSize)
          .toDouble();
    } catch (e) {}
  }

  NetSpace.fromBytes(double bytes) {
    _timestamp = DateTime.now().millisecondsSinceEpoch;
    _size = bytes;
  }

  //genCache=true forces generation of netspace.json file
  init([bool genCache = false, bool skipCache = false]) async {
    if (skipCache) {
      await _getNetSpace();
    } else {
      _cacheFile = io.File("netspace.json");

      if (_cacheFile.existsSync())
        await _load(genCache);
      else {
        await _getNetSpace();
        await _getPastSizes();
        _save();
      }
    }
  }

  _getNetSpace() async {
    try {
      String contents = await http.read(
          Uri.parse("https://chianetspace.azurewebsites.net/data/summary"));

      var content = jsonDecode(contents);

      var sizeString = content['netSpace']['largestWholeNumberBinaryValue'];
      var units = content['netSpace']['largestWholeNumberBinarySymbol'];
      //temporary override while chianetspace.com doesn't fix their website
      units = "EiB";

      _size = ProperFilesize.parseHumanReadableFilesize('$sizeString $units')
          .toDouble();
    } catch (e) {}

    try {
      //if chianetspaceapi.com fails then gets netspace from chiacalculator.com
      if (_size == 0) {
        //<dd class="chakra-stat__number css-mu2u4q">8.032<!-- --> <!-- -->EiB</dd>
        String contents =
            await http.read(Uri.parse("https://chiacalculator.com"));
        RegExp regex = new RegExp(">([0-9\\.]+)<!-- --> <!-- -->([A-Z])iB");
        var matches = regex.allMatches(contents);

        for (var match in matches)
          if (_size == 0)
            _size = ProperFilesize.parseHumanReadableFilesize(
                    '${match.group(1)} ${match.group(2)}iB')
                .toDouble();

        _source = "chiacalculator.com";
      }
    } catch (e) {}
  }

  _getPastSizes() async {
    try {
      String contents =
          await http.read(Uri.parse("http://alpha2.chianetspace.com/data.php"));

      var array = jsonDecode(contents);

      for (var pastSize in array) {
        //parses timestamp and accounts for ChiaNetSpace's timezone
        int timestamp = DateFormat('y-M-d')
                .parseUTC(pastSize['date'])
                .millisecondsSinceEpoch -
            Duration(hours: 3).inMilliseconds;
        double size = ProperFilesize.parseHumanReadableFilesize(
                "${pastSize['netspace']} PiB")
            .toDouble();
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
      [bool showAbsoluteSize = false, MapEntry? size3]) {
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

    double sizeRatio = (100 * ((size1.value / size2.value) - 1)).toDouble();

    double ratio = timeRatio * sizeRatio;
    double avgSizeDiff =
        (timeRatio * (size1.value - size2.value)).roundToDouble();

    var sign = (ratio > 0) ? "+" : "-";

    String absoluteSize = '';

    if (showAbsoluteSize)
      absoluteSize =
          "$sign${ProperFilesize.generateHumanReadableFilesize(avgSizeDiff.abs())}, ";

    growth = "$absoluteSize$sign${ratio.abs().toStringAsFixed(1)}%";

    return growth;
  }

  _save() {
    _timestamp = DateTime.now().millisecondsSinceEpoch;

    String serial = jsonEncode(this);
    _cacheFile.writeAsStringSync(serial);
  }

  _load([bool genCache = false]) async {
    var json = jsonDecode(_cacheFile.readAsStringSync());
    NetSpace previousNetSpace = NetSpace.fromJson(json);

    //loads old past sizes
    pastSizes = previousNetSpace.pastSizes;

    //if last time price was parsed from api was longer than 1 minute ago
    //then parses new price from api
    if (previousNetSpace.timestamp < _untilTimeStamp || genCache) {
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

  NetSpace.fromJson(dynamic json) {
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
    if (json['size'] != null) _size = json['size'];

    if (json['pastSizes'] != null)
      pastSizes = Map<String, double>.from(json['pastSizes']);

    if (json['source'] != null) _source = json['source'];
  }
}
