import 'logitem.dart';

class ShortSync extends LogItem {
  //start block of short sync
  int _start;
  int get start => _start;

  //end block of short sync
  int _end;
  int get end => _end;

  //length of short sync
  int get length => _start - _end;

  Map toJson() => {"timestamp": timestamp, "start": start, "end": end};

  ShortSync(int timestamp, this._end, this._start)
      : super(timestamp, LogItemType.FullNode);

  ShortSync.fromJson(dynamic json)
      : super.fromJson(json, LogItemType.FullNode) {
    if (json['start'] != null) _start = json['start'];
    if (json['end'] != null) _start = json['end'];
  }
}
