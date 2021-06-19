import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';

import 'package:farmr_client/hardware.dart';

final log = Logger('Cache');

class Cache {
  late Blockchain _blockchain;

  String binPath = '';

  List<Plot> _plots = []; //cached plots
  List<Plot> get plots => _plots;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SignagePoint> _signagePoints = [];
  List<SignagePoint> get signagePoints => _signagePoints;

  List<ShortSync> _shortSyncs = [];
  List<ShortSync> get shortSyncs => _shortSyncs;

  //past values for memory (24 hour)
  List<Memory> _memories = [];
  List<Memory> get memories => _memories;

  // '/home/user/.farmr' for package installs, '' (project path) for the rest
  late String _rootPath;
  late io.File _cache;

  int parseUntil =
      DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

  Cache(this._blockchain, this._rootPath) {
    _cache =
        io.File(_rootPath + "cache/cache${_blockchain.fileExtension}.json");
  }

  Map toJson() => {
        "binPath": binPath,
        "plots": plots,
        "filters": filters,
        "signagePoints": signagePoints,
        "shortSyncs": shortSyncs,
        "memories": memories,
      };

  Future<void> init() async {
    //Tells log parser when it should stop parsing
    parseUntil =
        DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

    //Loads cache file
    if (!_cache.existsSync())
      save(); //creates cache file if doesnt exist
    else {
      load(); //.farmr_cache.json

      save();
    }
  }

  //saves cache file
  void save() {
    String contents = jsonEncode([toJson()]);

    _cache.writeAsStringSync(contents);
  }

  void load() {
    try {
      var contents = jsonDecode(_cache.readAsStringSync());
      //print(contents);

      //LOADS IDS FROM CACHE FILE (backwards compatible)
      //loads id from cache file
      if (contents[0]['id'] != null) {
        _blockchain.id.ids = [];
        _blockchain.id.ids.add(contents[0]['id']);
        _blockchain.id.save();
      }
      //loads ids from cache file
      if (contents[0]['ids'] != null) {
        _blockchain.id.ids = [];
        for (String id in contents[0]['ids']) _blockchain.id.ids.add(id);
        _blockchain.id.save();
      }

      //loads plot list from cache file
      if (contents[0]['plots'] != null) {
        _plots = [];
        var plotsJson = contents[0]['plots'];

        for (var plotJson in plotsJson) _plots.add(Plot.fromJson(plotJson));
      }

      //loads chia binary path from cache
      if (contents[0]['binPath'] != null) binPath = contents[0]['binPath'];

      //loads filters list from cache file
      if (contents[0]['filters'] != null) {
        _filters = [];
        var filtersJson = contents[0]['filters'];

        for (var filterJson in filtersJson) {
          Filter filter = Filter.fromJson(filterJson, plots.length);
          if (filter.timestamp > parseUntil) _filters.add(filter);
        }
      }

      //loads subslots list from cache file
      if (contents[0]['signagePoints'] != null) {
        _signagePoints = [];
        var signagePointsJson = contents[0]['signagePoints'];

        for (var signagePointJson in signagePointsJson) {
          SignagePoint signagePoint = SignagePoint.fromJson(signagePointJson);
          if (signagePoint.timestamp > parseUntil)
            _signagePoints.add(signagePoint);
        }
      }

      //loads shortsyncs list from cache file
      if (contents[0]['shortSyncs'] != null) {
        _shortSyncs = [];
        var shortSyncsJson = contents[0]['shortSyncs'];

        for (var shortSyncJson in shortSyncsJson) {
          ShortSync shortSync = ShortSync.fromJson(shortSyncJson);
          if (shortSync.timestamp > parseUntil) _shortSyncs.add(shortSync);
        }
      }

      //loads memories list from cache file
      if (contents[0]['memories'] != null) {
        _memories = [];
        var memoriesJson = contents[0]['memories'];

        for (var memoryJson in memoriesJson) {
          Memory memory = Memory.fromJson(memoryJson);
          if (memory.timestamp > parseUntil) _memories.add(memory);
        }
      }
    } catch (Exception) {
      log.severe(
          "ERROR: Failed to load .farmr_cache${_blockchain.fileExtension}.json\nGenerating a new cache file.");
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

  void saveSignagePoints(List<SignagePoint> signagePoints) {
    _signagePoints = signagePoints;
    save();
  }

  void saveShortSyncs(List<ShortSync> shortSyncs) {
    _shortSyncs = shortSyncs;
    save();
  }

  void saveMemories(List<Memory> memories) {
    _memories = memories;
    save();
  }
}
