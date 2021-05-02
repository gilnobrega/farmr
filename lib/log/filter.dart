import 'logitem.dart';

import 'package:logging/logging.dart';

final Logger log = Logger('Log.Filter');

class Filter extends LogItem {
  int _eligiblePlots = 0; //number of eligible plots
  int get eligiblePlots => _eligiblePlots;

  int _proofs = 0; //number of proofs
  int get proofs => _proofs;

  double _time = 0; //challenge reponse time
  double get time => _time;

  int _totalPlots = 0; //total number of plots
  int get totalPlots => _totalPlots;

  Map toJson() => {
        'timestamp': timestamp,
        'eligible': eligiblePlots,
        'time': time /*'total': totalPlots, 'proofs': proofs*/
      };

  Filter(int timestamp, int eligiblePlots, int proofs, double time, int totalPlots)
      : super(timestamp, LogItemType.Harvester) {
    _eligiblePlots = eligiblePlots;
    _proofs = proofs;
    _time = time;
    _totalPlots = totalPlots;
  }

  Filter.fromJson(dynamic json) : super.fromJson(json, LogItemType.Harvester) {
    if (json['eligible'] != null) _eligiblePlots = json['eligible'];
    //if (json['proofs'] != null) _proofs = json['proofs'];
    if (json['time'] != null) _time = json['time'];
    //if (json['total'] != null) _totalPlots = json['total'];
  }

}
