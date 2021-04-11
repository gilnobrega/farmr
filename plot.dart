import 'dart:convert';
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

    _duration = _end.difference(_begin);

    _size = stat.size;
  }

  //Generate plot from json string
  Plot.fromJson(dynamic json) {
    _begin = DateTime.fromMillisecondsSinceEpoch(json['begin']);
    _end = DateTime.fromMillisecondsSinceEpoch(json['end']);

    _size = json['size'];

    _duration = _end.difference(_begin);
  }

  //Convert plot into json
  Map toJson() => {
        'begin': begin.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'size': size
      };
}
