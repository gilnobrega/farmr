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

class Cache {
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

  Cache(this.blockchain, this.rootPath);

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
  void save(dynamic object) {}
  void savePlots(dynamic object) {}
  void saveHarvesterErrors(dynamic object) {}
  void saveShortSyncs(dynamic object) {}
  void saveFilters(dynamic object) {}
  void savePoolErrors(dynamic object) {}
  void saveSignagePoints(dynamic object) {}
  void saveMemories(dynamic object) {}
}
