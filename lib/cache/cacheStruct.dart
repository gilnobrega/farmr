import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/log/logitem.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';

import 'package:farmr_client/hardware.dart';

final log = Logger('Cache');

class CacheStruct {
  late Blockchain blockchain;

  String chiaPath = '';

  String binPath = '';

  List<Plot> plots = []; //cached plots

  List<Filter> filters = [];

  List<SignagePoint> signagePoints = [];

  List<ShortSync> shortSyncs = [];

  List<LogItem> poolErrors = [];

  List<LogItem> harvesterErrors = [];

  //past values for memory (24 hour)
  List<Memory> memories = [];

  // '/home/user/.farmr' for package installs, '' (project path) for the rest
  late String rootPath;
  late io.File cache;

  int parseUntil =
      DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

  CacheStruct(this.blockchain, this.rootPath);

  Map toJson() => {
        "binPath": binPath,
        "plots": plots,
        "filters": filters,
        "signagePoints": signagePoints,
        "shortSyncs": shortSyncs,
        "memories": memories,
        "poolErrors": poolErrors,
        "harvesterErrors": harvesterErrors,
        "${blockchain.binaryName}Path": chiaPath
      };

  Future<void> init() async {}
  void save() {}
  void savePlots(List<Plot> newPlots) {}
  void saveHarvesterErrors(List<LogItem> newPlots) {}
  void saveShortSyncs(List<ShortSync> newPlots) {}
  void saveFilters(List<Filter> newPlots) {}
  void savePoolErrors(List<LogItem> newPlots) {}
  void saveSignagePoints(List<SignagePoint> newPlots) {}
  void saveMemories(List<Memory> newPlots) {}
}
