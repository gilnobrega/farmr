import 'logitem.dart';
import 'package:intl/intl.dart';

class ShortSync extends LogItem {
  //start block of short sync
  late int _start;
  int get start => _start;

  //end block of short sync
  late int _end;
  int get end => _end;

  //length of short sync
  int get length => _end - _start;

  late String _localTime = "";
  String get localTime => _localTime;

  Map<String, dynamic> toJson() => {
        "timestamp": timestamp,
        "localTime": localTime,
        "start": start,
        "end": end
      };

  ShortSync(int timestamp, this._start, this._end)
      : super(timestamp, LogItemType.FullNode) {
    _localTime = DateFormat("HH:mm")
        .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  ShortSync.fromJson(dynamic json)
      : super.fromJson(json, LogItemType.FullNode) {
    if (json['start'] != null) _start = json['start'];
    if (json['end'] != null) _end = json['end'];
    if (json['localTime'] != null) _localTime = json['localTime'];
  }

  static int skippedBlocks(List<ShortSync> shortSyncs) {
    List<int> blocks = [];

    //adds each skipped block to list of blocks
    for (ShortSync shortSync in shortSyncs)
      blocks.addAll(Iterable<int>.generate(shortSync.length)
          .map((b) => shortSync.start + b));

    //set function filters duplicate blocks
    return blocks.toSet().length;
  }
}
