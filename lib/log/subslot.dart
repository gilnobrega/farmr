import 'signagepoint.dart';

import 'package:logging/logging.dart';

final Logger log = Logger('Log.SubSlot');

class SubSlot {
  List<SignagePoint> signagePoints = [];

  bool _first = false;
  bool get complete => (_first || signagePoints.toSet().length == 64);

  int get lastStep => signagePoints.last.index;

  Map toJson() => {'signagePoints': signagePoints};

  SubSlot(this.signagePoints, [bool first = false]) {
    //log.info("New SubSlot with signage point ${signagePoints[0].index}/64");

    _first = first;
  }

  SubSlot.fromJson(dynamic json) {
    if (json['signagePoints'] != null) {
      for (var signagePoint in json['signagePoints'])
        signagePoints.add(SignagePoint.fromJson(signagePoint));
    }
  }

  addSignagePoint(SignagePoint signagepoint) {
    //log.info("Adding Signage Point $signagepoint/64 to SubSlot");
    signagePoints.add(signagepoint);
  }
}
