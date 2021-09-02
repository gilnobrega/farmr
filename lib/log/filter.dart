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

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'eligible': eligiblePlots,
        'lookupTime': time,
        'plotNumber': totalPlots,
        'proofs': proofs
      };

  Filter(int timestamp, this._eligiblePlots, this._proofs, this._time,
      this._totalPlots)
      : super(timestamp, LogItemType.Harvester);

  Filter.fromJson(dynamic json, int plotCount)
      : super.fromJson(json, LogItemType.Harvester) {
    if (json['eligible'] != null) _eligiblePlots = json['eligible'];
    if (json['proofs'] != null) _proofs = json['proofs'];
    if (json['lookupTime'] != null) _time = json['lookupTime'];

    //if totalPlots does not exist in cache then it will use cache's plots.length
    if (json['plotNumber'] != null)
      _totalPlots = json['plotNumber'];
    else
      _totalPlots = plotCount;
  }
}
