import 'dart:core';
import 'dart:io' as io;
import 'package:path/path.dart';

class Plot {
  String _plotSize;

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
  DateTime get end => _end;

  Duration _duration;
  Duration get duration => _duration;

  int _size;
  int get size => _size;

  Plot(io.File file) {
    List<String> list = basename(file.path).split('-');

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
  }

  //Generate plot from json string
  Plot.fromJson(dynamic json) {
    _begin = DateTime.fromMillisecondsSinceEpoch(json['begin']);
    _end = DateTime.fromMillisecondsSinceEpoch(json['end']);

    _size = json['size'];

    if (json['date'] != null)
      _date = json['date'];

    _duration = _end.difference(_begin);
  }

  //Convert plot into json
  Map toJson() => {
        'begin': begin.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'size': size,
        'date': date,
      };
}

String dateToString(DateTime date) {
  return date.year.toString() +
      "-" +
      date.month.toString() +
      "-" +
      date.day.toString();
}

DateTime stringToDate(String input) {
  var array = input.split('-');
  return new DateTime(
      int.parse(array[0]),
      int.parse(array[1]),
      int.parse(array[2]));
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

//Returns sum of size of plots in a given list
int plotSumSize(List<Plot> plots) {
  int totalSize = 0;

  for (int i = 0; i < plots.length; i++) totalSize += plots[i].size;

  return totalSize;
}
