import 'dart:core';
import 'dart:io' as io;
import 'dart:math' as Math;

import 'package:logging/logging.dart';

import 'package:path/path.dart';
import 'package:filesize/filesize.dart';

final log = Logger('Plot');

class Plot {
  String _id;
  String get id => _id;

  String _plotSize = "k32"; //defaults to plot size k32
  String get plotSize => _plotSize;
  int get plotSizeInt => int.parse(_plotSize.substring(1));

  int _year;
  int _month;
  int _day;
  int _hour;
  int _minute;

  String _date = "1971-01-01"; //plots finished date
  String get date => _date; //plots finished date

  DateTime _begin;
  DateTime get begin => _begin;

  DateTime _end;
  //if plot were created after completion (timestamp bug)
  //then assumes end time stamp is beginning time stamp
  DateTime get end => (_end.millisecondsSinceEpoch > _begin.millisecondsSinceEpoch) ? _end : _begin;

  Duration _duration;
  Duration get duration => _duration;

  int _size;
  int get size => _size;
  //expected size of at least 1e11 bytes (100gb), rough approximation
  int get _expectedSize => (Math.pow(2, (plotSizeInt - 32)) * 1e11).toInt();
  //assumes plot is complete (and not incomplete) if the size is over (minimum) expected size
  bool get complete => _size > _expectedSize;

  Plot(io.File file) {
    log.info("Added plot: " + file.path);

    List<String> list = basenameWithoutExtension(file.path).split('-');

    _plotSize = list[1];

    _year = int.parse(list[2]);
    _month = int.parse(list[3]);
    _day = int.parse(list[4]);
    _hour = int.parse(list[5]);
    _minute = int.parse(list[6]);

    _begin = new DateTime(_year, _month, _day, _hour, _minute);

    io.FileStat stat = io.FileStat.statSync(file.path);
    _end = stat.modified; // CHANGED OR MODIFIED??

    _date = dateToString(end);

    _duration = _end.difference(_begin);

    _size = stat.size;

    _id = list[7];
    //in the client plotid is that long hash, while in the server its based on timestamps
    //this solves problems with copying plots
  }

  //Generate plot from json string
  Plot.fromJson(dynamic json) {
    if (json['plotSize'] != null) _plotSize = json['plotSize'];

    _begin = DateTime.fromMillisecondsSinceEpoch(json['begin']);
    _end = DateTime.fromMillisecondsSinceEpoch(json['end']);
    _size = json['size'];

    if (json['id'] != null)
      _id = json['id'];
    else
      //in the client plotid is a long hash, while in the server its based on timestamps
      _id = begin.millisecondsSinceEpoch.toString() +
          end.millisecondsSinceEpoch.toString() +
          size.toString();

    if (json['date'] != null) _date = json['date'];

    _duration = _end.difference(_begin);
  }

  //Convert plot into json
  Map toJson() => {
        'id': id,
        'plotSize': plotSize,
        'begin': begin.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'size': size,
        'date': date,
      };

  //Replaces long hash with timestamp id before sending to server
  void clearID() {
    _id = null;
  }

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
  return new DateTime(int.parse(array[0]), int.parse(array[1]), int.parse(array[2]));
}

//finds the last plot in a list of plots
Plot lastPlot(List<Plot> plots) {
  return plots.reduce((plot1, plot2) =>
      (plot1.end.millisecondsSinceEpoch > plot2.end.millisecondsSinceEpoch) ? plot1 : plot2);
}

//finds the first plot in a list of plots
Plot firstPlot(List<Plot> plots) {
  return plots.reduce((plot1, plot2) =>
      (plot1.begin.millisecondsSinceEpoch < plot2.begin.millisecondsSinceEpoch) ? plot1 : plot2);
}

//Returns sum of size of plots in a given list
int plotSumSize(List<Plot> plots) {
  int totalSize = 0;

  for (int i = 0; i < plots.length; i++) totalSize += plots[i].size;

  return totalSize;
}

String fileSize(int input, [int decimals = 2]) {
  return filesize(input, decimals)
      .replaceAll("TB", "TiB")
      .replaceAll("GB", "GiB")
      .replaceAll("PB", "PiB");
}
