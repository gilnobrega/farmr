import 'package:intl/intl.dart';

class LogItem {
  late int _timestamp; //unix timestamp, id
  int get timestamp => _timestamp;

  LogItemType _type;
  LogItemType get type => _type;

  LogItem(this._timestamp, this._type);

  LogItem.fromJson(dynamic json, this._type) {
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
  }
}

//converts a chia log timestamp string to unix time
int parseTimestamp(
    String yearMonthDay, String hourMinuteSecond, String milliseconds) {
  return DateFormat('y-M-d H:m:s')
          .parse(yearMonthDay + " " + hourMinuteSecond)
          .millisecondsSinceEpoch +
      int.parse(milliseconds);
}

enum LogItemType { Harvester, FullNode, Farmer }
