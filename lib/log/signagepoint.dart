import 'logitem.dart';

class SignagePoint extends LogItem {
  int _index = 0;
  int get index => _index;

  Map toJson() => {'timestamp': timestamp, 'index': index};

  SignagePoint(int timestamp, this._index)
      : super(timestamp, LogItemType.FullNode);

  SignagePoint.fromJson(dynamic json)
      : super.fromJson(json, LogItemType.FullNode) {
    if (json['index'] != null) _index = json['index'];
  }
}
