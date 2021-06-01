import 'dart:math' as Math;

import 'package:chiabot/log/filter.dart';
import 'package:chiabot/debug.dart';
import 'package:chiabot/harvester.dart';

import 'package:stats/stats.dart';

class HarvesterFilters {
  //Deprecated
  List<Filter> filters = [];
  final List<double> _timeCategories = [0, 0.25, 0.5, 1, 5, 10, 15, 20, 25, 30];

  int _numberFilters = 0;
  int get numberFilters => _numberFilters;

  //plots which passed filter
  int _eligiblePlots = 0;
  int get eligiblePlots =>
      (_eligiblePlots == 0) ? _getEligiblePlots() : _eligiblePlots;

  //number of challenges which response time is above 30s
  int _missedChallenges = 0;
  int get missedChallenges => _missedChallenges;

  //average of all Total Plots in filter's log which
  double _totalPlots = 0;
  double get totalPlots => (_totalPlots == 0) ? _getTotalPlots() : _totalPlots;

  //displays number of proofs found
  int _proofsFound = 0;
  int get proofsFound => (_proofsFound == 0) ? _getProofsFound() : _proofsFound;

  //displays number of challenges response times split in categories
  Map<String, int> _filterCategories = {};
  Map<String, int> get filterCategories =>
      (_filterCategories.isEmpty) ? _getFilterCategories() : _filterCategories;

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

  loadFilters([Log? log]) {
    if (log != null) filters = log.filters;

    List<double> _times = filters.map((filter) => filter.time).toList();
    //number of challenges which response time is above 30s
    _missedChallenges = _times.where((time) => time >= 30).length;

    if (_times.length > 0) {
      Stats timeStats = Stats.fromData(_times);
      _maxTime = timeStats.max.toDouble();
      _minTime = timeStats.min.toDouble();
      _avgTime = timeStats.average.toDouble();
      _medianTime = timeStats.median.toDouble();
      _stdDeviation = timeStats.standardDeviation.toDouble();
    }

    _numberFilters = filters.length;
  }

  loadFiltersStatsJson(dynamic json, int numPlots) {
    //Old clients
    if (json['filters'] != null) {
      for (int i = 0; i < json['filters'].length; i++) {
        filters.add(Filter.fromJson(json['filters'][i], numPlots));
      }
      _totalPlots = (numPlots / 1.0);

      loadFilters(); //calculates stats
    }
    //New client
    else {
      if (json['numberFilters'] != null) _numberFilters = json['numberFilters'];
      if (json['eligiblePlots'] != null) _eligiblePlots = json['eligiblePlots'];
      if (json['proofsFound'] != null) _proofsFound = json['proofsFound'];
      if (json['missedChallenges'] != null)
        _missedChallenges = json['missedChallenges'];
      if (json['totalPlots'] != null)
        _totalPlots = double.parse(json['totalPlots'].toString());
      else
        _totalPlots = (numPlots / 1.0);

      //loads stats about filters
      if (json['maxTime'] != null) _maxTime = json['maxTime'];
      if (json['minTime'] != null) _minTime = json['minTime'];
      if (json['avgTime'] != null) _avgTime = json['avgTime'];
      if (json['medianTime'] != null) _medianTime = json['medianTime'];
      if (json['stdDeviation'] != null) _stdDeviation = json['stdDeviation'];

      //loads filterCategories map
      if (json['filterCategories'] != null)
        _filterCategories = Map<String, int>.from(json['filterCategories']);
    }
  }

  int _getEligiblePlots() {
    int count = 0;
    for (Filter filter in filters) count += filter.eligiblePlots;

    _eligiblePlots = count;
    return count;
  }

  int _getProofsFound() {
    int count = 0;
    for (Filter filter in filters) count += filter.proofs;

    _proofsFound = count;
    return count;
  }

  Map<String, int> _getFilterCategories() {
    Map<String, int> filterCategories = {};

    List<List<double>> boundaries = [];

    for (int i = 0; i < _timeCategories.length; i++) {
      double step = _timeCategories[i];

      if (i != _timeCategories.length - 1) {
        double nextStep = _timeCategories[i + 1];
        boundaries.add([step, nextStep]);
        filterCategories.putIfAbsent('$step-$nextStep', () => 0);
      }
    }

    for (Filter filter in filters) {
      for (List<double> boundary in boundaries) {
        //if filter is in between category boundaries
        if (filter.time >= boundary[0] && filter.time < boundary[1]) {
          String key = '${boundary[0]}-${boundary[1]}';
          filterCategories.putIfAbsent(key, () => 0);
          //adds +1 to the count of that key
          filterCategories.update(key, (value) => value + 1);
        }
      }
    }

    _filterCategories = filterCategories;
    return filterCategories;
  }

  double _getTotalPlots() {
    if (filters.length > 0) {
      int count = 0;
      for (Filter filter in filters) count += filter.totalPlots;
      _totalPlots = count / filters.length;
    }

    return _totalPlots;
  }

  void addHarversterFilters(Harvester harvester) {
    _totalPlots += harvester.totalPlots;

    calculateFilterRatio(harvester);
    filters.addAll(harvester.filters);

    if (harvester.numberFilters > 0) {
      //adds harvesters filter stats to farmers
      _numberFilters += harvester.numberFilters;
      _eligiblePlots += harvester.eligiblePlots;
      _missedChallenges += harvester.missedChallenges;
      _proofsFound += harvester.proofsFound;

      _maxTime = Math.max(_maxTime, harvester.maxTime);
      _minTime = Math.min(_minTime, harvester.minTime);

      //merges harvester's filter categories with farmer
      if (harvester.filterCategories.isNotEmpty) {
        for (var entry in harvester.filterCategories.entries) {
          this._filterCategories.putIfAbsent(entry.key, () => 0);
          this
              ._filterCategories
              .update(entry.key, (value) => value + entry.value);
        }
      }
    }

    //Can't load standard deviation, average time or median time without a list of filters
    _stdDeviation = 0;
    _avgTime = 0;
    _medianTime = 0;
  }

  void calculateFilterRatio(Harvester harvester) {
    if (harvester.numberFilters > 0) {
      filterRatio += (harvester.eligiblePlots / harvester.numberFilters) * 512;
    }
  }

  void disableDetailedTimeStats() {
    _avgTime = 0;
    _medianTime = 0;
    _stdDeviation = 0;
  }
}
