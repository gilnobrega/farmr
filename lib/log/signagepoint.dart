import 'logitem.dart';

import 'package:logging/logging.dart';

Logger log = Logger("Signage Point");

class SignagePoint extends LogItem {
  int _index = 0;
  int get index => _index;

  Map toJson() => {'timestamp': timestamp, 'spIndex': index};

  SignagePoint(int timestamp, this._index)
      : super(timestamp, LogItemType.FullNode) {
    log.info("Added signage point $_index/64");
  }

  SignagePoint.fromJson(dynamic json)
      : super.fromJson(json, LogItemType.FullNode) {
    if (json['spIndex'] != null) _index = json['spIndex'];
  }
}
