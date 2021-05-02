import 'logitem.dart';

import 'package:logging/logging.dart';

final Logger log = Logger('Log.SubSlot');

class SubSlot extends LogItem {
  List<int> signagePoints = [];

  bool _first = false;
  bool get complete => (_first || signagePoints.toSet().length == 64);

  int get lastStep => signagePoints.last;

  SubSlot(int timestamp, [List<int> initialSPs = null, bool first = false])
      : super(timestamp, LogItemType.FullNode) {
    log.info("New SubSlot ${timestamp}");

    if (signagePoints != null) signagePoints = initialSPs;
    _first = first;
  }

  addSignagePoint(int signagepoint) {
    log.info("Adding Signage Point ${signagepoint}/64 to SubSlot ${timestamp}");
    signagePoints.add(signagepoint);
  }
}
