import 'dart:math' as Math;

import '../log/filter.dart';
import '../debug.dart';
import '../harvester.dart';

import 'package:stats/stats.dart';

class HarvesterFilters {
  //Deprecated
  List<Filter> filters = [];

  int _numberFilters = 0;
  int get numberFilters => _numberFilters;

  int _eligiblePlots = 0;
  int get eligiblePlots => _eligiblePlots;

  double _maxTime = 0;
  double _minTime = 0;
  double _avgTime = 0;
  double _medianTime = 0;
  double _stdDeviation = 0;

  double get maxTime => _maxTime;
  double get minTime => _minTime;
  double get avgTime => _avgTime;
  double get medianTime => _medianTime;
  double get stdDeviation => _stdDeviation;

  double filterRatio = 0;
  int totalPlots = 0;

  loadFilters([Log log]) {
    if (log != null) filters = log.filters;

    List<double> _times = filters.map((filter) => filter.time).toList();

    Stats timeStats = Stats.fromData(_times);
    _maxTime = timeStats.max;
    _minTime = timeStats.min;
    _avgTime = timeStats.average;
    _medianTime = timeStats.median;
    _stdDeviation = timeStats.standardDeviation;

    _numberFilters = filters.length;
    _eligiblePlots = _getEligiblePlots();
  }

  loadFiltersStatsJson(dynamic json) {
    //Old clients
    if (json['filters'] != null) {
      for (int i = 0; i < json['filters'].length; i++) {
        filters.add(Filter.fromJson(json['filters'][i]));
      }
      loadFilters(); //calculates stats
    }
    //New client
    else {
      if (json['numberFilters'] != null) _numberFilters = json['numberFilters'];
      if (json['eligiblePlots'] != null) _eligiblePlots = json['eligiblePlots'];

      if (json['maxTime'] != null) _maxTime = json['maxTime'];
      if (json['minTime'] != null) _minTime = json['minTime'];
      if (json['avgTime'] != null) _avgTime = json['avgTime'];
      if (json['medianTime'] != null) _medianTime = json['medianTime'];
      if (json['stdDeviation'] != null) _stdDeviation = json['stdDeviation'];
    }
  }

  int _getEligiblePlots() {
    int count = 0;
    for (Filter filter in filters) count += filter.eligiblePlots;
    return count;
  }

  void addHarversterFilters(Harvester harvester) {
    calculateFilterRatio(harvester);

    filters.addAll(harvester.filters);

    _numberFilters += harvester.numberFilters;
    _eligiblePlots += eligiblePlots;

    _maxTime = Math.max(_maxTime, harvester.maxTime);
    _minTime = Math.min(_minTime, harvester.minTime);

    //Can't load standard deviation, average time or median time without a list of filters
    _stdDeviation = 0;
    _avgTime = 0;
    _medianTime = 0;
  }

  void calculateFilterRatio(Harvester harvester) {
    if (harvester.numberFilters > 0) {
      int totalFilters = harvester.numberFilters;

      filterRatio += (harvester.eligiblePlots / totalFilters) * 512;
      totalPlots += harvester.plots.length;
    }
  }
}
