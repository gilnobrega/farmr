import 'dart:core';
import 'package:intl/intl.dart';
import 'package:proper_filesize/proper_filesize.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:math' as Math;

import 'package:logging/logging.dart';
import 'package:path/path.dart';

final log = Logger('Plot');

class Plot {
  String _id = "N/A";
  String get id => _id;

  String _plotSize = "k32"; //defaults to plot size k32
  String get plotSize => _plotSize;
  int get plotSizeInt => int.parse(_plotSize.substring(1));

  String _date = "1971-01-01"; //plots finished date
  String get date => _date; //plots finished date

  DateTime _begin = DateTime.now();
  DateTime get begin => _begin;

  DateTime _end = DateTime.now();
  //if plot were created after completion (timestamp bug)
  //then assumes end time stamp is beginning time stamp
  DateTime get end =>
      (_end.millisecondsSinceEpoch > _begin.millisecondsSinceEpoch)
          ? _end
          : _begin;

  Duration _duration = Duration(hours: 0);
  Duration get duration => _duration;
  String get humanReadableDuration => durationToTime(_duration);
  Duration get finishedAgo => DateTime.now().difference(end);
  String get humanReadableFinishedAgo =>
      (finishedAgo.inMilliseconds > Duration(days: 1).inMilliseconds)
          ? DateFormat('y/MM/dd HH:mm:ss').format(end)
          : durationToTime(finishedAgo) + " ago";

  int _size = 0;
  int get size => _size;
  String get humanReadableSize => fileSize(_size);

  //expected size of at least 1e11 bytes (100gb), rough approximation
  int get _expectedSize => (Math.pow(2, (plotSizeInt - 32)) * 1e11).toInt();
  //assumes plot is complete (and not incomplete) if the size is over (minimum) expected size
  bool get complete => _size > _expectedSize;

  //Plot properties from RPC server
  bool loaded = true;
  bool get failed => !loaded;
  bool isNFT = false;
  bool get isOG => !isNFT;

  Plot(io.File file) {
    log.info("Added plot: " + file.path);

    try {
      int _year;
      int _month;
      int _day;
      int _hour;
      int _minute;

      List<String> list = basenameWithoutExtension(file.path).split('-');

      _plotSize = list[1];

      _year = int.parse(list[2]);
      _month = int.parse(list[3]);
      _day = int.parse(list[4]);
      _hour = int.parse(list[5]);
      _minute = int.parse(list[6]);

      _id = list[7];

      _begin = new DateTime(_year, _month, _day, _hour, _minute);

      //in the client plotid is that long hash, while in the server its based on timestamps
      //this solves problems with copying plots
    } catch (e) {
      _plotSize = "k32";
      //if plot has been renamed then the id will be its name
      _id = basenameWithoutExtension(file.path);
      //if failed to parse timestamp, set begin date to current date
      _begin = DateTime.now();
      log.info("Failed to parse timestamp about plot in ${file.path}");
    }

    io.FileStat stat = io.FileStat.statSync(file.path);
    _end = stat.modified; // CHANGED OR MODIFIED??

    _date = dateToString(end);

    _duration = _end.difference(_begin);

    _size = stat.size;

  }

  //Generate plot from json string
  Plot.fromJson(dynamic json) {
    if (json['plotSize'] != null) _plotSize = json['plotSize'];

    _begin = DateTime.fromMillisecondsSinceEpoch(json['begin']);
    _end = DateTime.fromMillisecondsSinceEpoch(json['end']);
    _size = json['size'];

    if (json['id'] != null) {
      _id = json['id'];

      if (!complete) log.info("Plot " + _id + " is incomplete");
    } else
      //in the client plotid is a long hash, while in the server its based on timestamps
      _id = begin.millisecondsSinceEpoch.toString() +
          end.millisecondsSinceEpoch.toString() +
          size.toString();

    if (json['date'] != null) _date = json['date'];

    _duration = _end.difference(_begin);

    //RPC properties
    if (json['isNFT'] != null) isNFT = json['isNFT'];
    if (json['loaded'] != null) loaded = json['loaded'];
  }

  //Convert plot into json
  Map toJson() => {
        'id': id,
        'plotSize': plotSize,
        'begin': begin.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'size': size,
        'date': date,
        'isNFT': isNFT,
        'loaded': loaded
      };

  //Replaces long hash with timestamp id before sending to server
  /*void clearID() {
    _id = null;
  }*/

  void updateSize(int size) {
    _size = size;
  }
}

String dateToString(DateTime date) {
  String month = date.month.toString();
  String day = date.day.toString();

  return date.year.toString() + "-" + month + "-" + day;
}

DateTime stringToDate(String input) {
  var array = input.split('-');
  return new DateTime(
      int.parse(array[0]), int.parse(array[1]), int.parse(array[2]));
}

//finds the last plot in a list of plots
Plot lastPlot(List<Plot> plots) {
  return plots.reduce((plot1, plot2) =>
      (plot1.end.millisecondsSinceEpoch > plot2.end.millisecondsSinceEpoch)
          ? plot1
          : plot2);
}

//finds the first plot in a list of plots
Plot firstPlot(List<Plot> plots) {
  return plots.reduce((plot1, plot2) =>
      (plot1.begin.millisecondsSinceEpoch < plot2.begin.millisecondsSinceEpoch)
          ? plot1
          : plot2);
}

//Converts a dart duration to something human-readable
String durationToTime(Duration duration) {
  String day = (duration.inDays == 0) ? "" : duration.inDays.toString();
  String hour = (duration.inHours == 0)
      ? ""
      : (duration.inHours - 24 * duration.inDays).toString();
  String minute = (duration.inMinutes - duration.inHours * 60).toString();

  day = twoDigits(day) + ((day == "") ? "" : "d ");
  hour = twoDigits(hour) + ((hour == "") ? "" : "h ");
  minute = (minute == "0") ? '' : twoDigits(minute) + "m ";

  return day + hour + minute;
}

//Used by durationToTime to always show 2 digits example 09m
String twoDigits(String input) {
  return (input.length == 1) ? "0" + input : input;
}

String fileSize(int size, [int decimals = 1]) {
  return ProperFilesize.generateHumanReadableFilesize(size.abs().toDouble(),
      decimals: decimals);
}
