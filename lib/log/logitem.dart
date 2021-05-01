import 'package:intl/intl.dart';

class LogItem {
  int _timestamp; //unix timestamp, id
  int get timestamp => _timestamp;

  LogItemType _type;
  LogItemType get type => _type;

  LogItem(int timestamp, LogItemType type) {
    _timestamp = timestamp;
    _type = type;
  }

  LogItem.fromJson(dynamic json, LogItemType type) {
    _type = type;
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
  }

  //Replaces long hash with timestamp id before sending to server
  void clearTimestamp() {
    _timestamp = null;
  }
}

//converts a chia log timestamp string to unix time 
int parseTimestamp(String yearMonthDay, String hourMinuteSecond, String milliseconds) {
  return DateFormat('y-M-d H:m:s').parse(yearMonthDay + " " + hourMinuteSecond).millisecondsSinceEpoch +
      int.parse(milliseconds);
}

enum LogItemType { Harvester, FullNode }
