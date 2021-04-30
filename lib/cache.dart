import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'plot.dart';
import 'debug.dart';

class Cache {
  String id;

  String binPath;

  List<Plot> _plots = []; //cached plots
  List<Plot> get plots => _plots;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  final io.File _cache = io.File(".chiabot_cache.json");

  //Tells log parser when it should stop parsing
  final int parseUntil = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

  Cache(String chiaConfigPath) {
    try {
      io.File _oldCache = io.File(chiaConfigPath + "chiabot_cache.json");
      if (!_cache.existsSync() && _oldCache.existsSync()) _oldCache.copySync(_cache.absolute.path);
    } catch (Exception) {
      print("Failed to port old cache file");
    }

    id = Uuid().v4();
  }

  void init() {
    //Loads cache file
    if (!_cache.existsSync())
      save(); //creates cache file if doesnt exist
    else
      load(); //chiabot_cache.json
  }

  //saves cache file
  void save() {
    String contents = jsonEncode([
      {"id": id, "binPath": binPath, "plots": plots, "filters": filters}
    ]);
    _cache.writeAsStringSync(contents);
  }

  void load() {
    var contents = jsonDecode(_cache.readAsStringSync());

    //loads id from cache file
    if (contents[0]['id'] != null) id = contents[0]['id'];

    //loads chia binary path from cache
    if (contents[0]['binPath'] != null) binPath = contents[0]['binPath'];

    //loads plot list from cache file
    if (contents[0]['plots'] != null) {
      var plotsJson = contents[0]['plots'];

      for (var plotJson in plotsJson) _plots.add(Plot.fromJson(plotJson));
    }

    //loads filters list from cache file
    if (contents[0]['filters'] != null) {
      var filtersJson = contents[0]['filters'];

      for (var filterJson in filtersJson) {
        Filter filter = Filter.fromJson(filterJson);
        if (filter.timestamp != null && filter.timestamp > parseUntil) _filters.add(filter);
      }
    }
  }

  void savePlots(List<Plot> plots) {
    _plots = plots;
    save();
  }

  void saveFilters(List<Filter> filters) {
    _filters = filters;
    save();
  }
}
