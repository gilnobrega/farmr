import 'logitem.dart';

import 'package:logging/logging.dart';

final Logger log = Logger('Log.SubSlot');

class SubSlot extends LogItem {
  List<int> signagePoints = [];

  bool _first = false;
  bool get complete => (_first || signagePoints.toSet().length == 64);

  int get lastStep => signagePoints.last;

  Map toJson() => {'timestamp': timestamp, 'signagePoints': signagePoints};

  SubSlot(int timestamp, [List<int> initialSPs = null, bool first = false])
      : super(timestamp, LogItemType.FullNode) {
    log.info("New SubSlot ${timestamp} with signage point ${initialSPs[0]}/64");

    if (signagePoints != null) signagePoints = initialSPs;
    _first = first;
  }

  SubSlot.fromJson(dynamic json) : super.fromJson(json, LogItemType.FullNode) {
    if (json['signagePoints'] != null) {
      for (var signagePoint in json['signagePoints']) signagePoints.add(signagePoint);
    }
  }

  addSignagePoint(int signagepoint) {
    log.info("Adding Signage Point ${signagepoint}/64 to SubSlot ${timestamp}");
    signagePoints.add(signagepoint);
  }
}
