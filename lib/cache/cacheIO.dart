import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/cache/cacheStruct.dart';
import 'package:farmr_client/log/logitem.dart';
import 'package:farmr_client/utils/sqlite.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';

import 'package:farmr_client/hardware.dart';

import 'package:sqlite3/sqlite3.dart';

final log = Logger('Cache');

class Cache extends CacheStruct {
  String? _binPath;
  @override
  String get binPath {
    if (Blockchain.detectOS() != OS.GitHub) {
      if (_binPath != null && io.File(_binPath!).existsSync())
        return _binPath!;
      else
        return _askForBinPath();
    } else
      return "";
  }

  Cache(Blockchain blockchain, String rootPath) : super(blockchain, rootPath) {
    cache = io.File(rootPath + "cache/cache${blockchain.fileExtension}.sqlite");

    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    const List<String> commands = [
      //plots
      '''
    CREATE TABLE IF NOT EXISTS plots (
      id TEXT NOT NULL PRIMARY KEY,
      filename TEXT NOT NULL,
      plotSize TEXT NOT NULL,
      size INTEGER NOT NULL,
      begin INTEGER NOT NULL,
      end INTEGER NOT NULL,
      date TEXT NOT NULL,
      isNFT BOOL NOT NULL,
      loaded BOOL NOT NULL
    );
  ''',

      //filters
      '''
    CREATE TABLE IF NOT EXISTS filters (
      timestamp INTEGER NOT NULL PRIMARY KEY,
      eligible INTEGER NOT NULL,
      proofs INTEGER NOT NULL,
      plotNumber INTEGER NOT NULL,
      lookupTime INTEGER NOT NULL
    );
  ''',

      // pool errors and harvester errors
      '''
    CREATE TABLE IF NOT EXISTS errors (
      timestamp INTEGER NOT NULL PRIMARY KEY,
      type TEXT NOT NULL
    );
  ''',

      // signage points
      '''
    CREATE TABLE IF NOT EXISTS signagePoints (
      timestamp INTEGER NOT NULL PRIMARY KEY,
      spIndex INTEGER NOT NULL
    );
  ''',

      // short sync events
      '''
    CREATE TABLE IF NOT EXISTS shortSyncs (
      timestamp INTEGER NOT NULL PRIMARY KEY,
      start INTEGER NOT NULL,
      end INTEGER NOT NULL,
      localTime TEXT NOT NULL
    );
  ''',

      //memories
      '''
    CREATE TABLE IF NOT EXISTS memories (
      timestamp INTEGER NOT NULL PRIMARY KEY,
      total INTEGER NOT NULL,
      free INTEGER NOT NULL,
      totalVirtual INTEGER NOT NULL,
      freeVirtual INTEGER NOT NULL
    );
  ''',

      // settings
      // example entry: binpath, value: /home/user/chia-blockchain/venv/bin/chia
      '''
    CREATE TABLE IF NOT EXISTS settings (
      entry TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL
    );
  '''
    ];

    for (final command in commands) database.execute(command);

    database.dispose();
  }

  Future<void> init() async {
    //Tells log parser when it should stop parsing
    parseUntil =
        DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

    _load(); //loads variables from database
  }

  //saves cache file
  void _save() {
    saveSettings();
  }

  void saveLogs(List<SignagePoint> newSPs, List<ShortSync> newSS,
      List<Filter> newFilters, List<LogItem> newHEs, List<LogItem> newPEs) {
    filters = newFilters;
    signagePoints = newSPs;
    shortSyncs = newSS;
    harvesterErrors = newHEs;
    poolErrors = newPEs;

    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    _saveToDB(database, filters, "filters");
    _saveToDB(database, signagePoints, "signagePoints");
    _saveToDB(database, shortSyncs, "shortSyncs");
    _saveToDB(database, harvesterErrors, "errors", "harvester");
    _saveToDB(database, poolErrors, "errors", "pool");

    database.dispose();
  }

  void savePlots(List<Plot> newPlots) {
    plots = newPlots;

    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    _saveToDB(database, plots, "plots");

    database.dispose();
  }

  void saveMemories(List<Memory> newMemories) {
    memories = newMemories;

    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    _saveToDB(database, memories, "memories");

    database.dispose();
  }

  static _saveToDB(Database database, List list, String table,
      [String? errorType]) {
    if (list.length > 0) {
      //excludes winner entry from cache as that's dynamically set according to RPC info
      final List<String> keysMap = (table != "plots")
          ? list.first.toJson().keys.toList()
          : list.first.toJsonPrivate().keys.toList();

      final List<String> questionMarksMap = keysMap.map((e) => "?").toList();

      final String query = (table == "errors")
          ? "INSERT or IGNORE INTO $table (${keysMap.join(',')}, type) VALUES (${questionMarksMap.join(',')}, '$errorType')"
          : "INSERT or IGNORE INTO $table (${keysMap.join(',')}) VALUES (${questionMarksMap.join(',')})";

      final statement = database.prepare(query);

      for (final object in list) {
        final List<dynamic> values = (table != "plots")
            ? object
                .toJson()
                .values
                //converts bools to 0 (false) or 1 (true)
                .map((e) => (e is bool) ? (e ? 1 : 0) : e)
                .toList()
            : object.toJsonPrivate().values;

        statement.execute(values);
      }

      statement.dispose();
    }
  }

  void saveSettings() {
    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    database.execute("""
        INSERT INTO settings (entry, value) VALUES ('binPath', ?) 
        ON CONFLICT (entry) DO
        UPDATE SET value = ?
        """, [binPath, binPath]);

    database.dispose();
  }

  void _load() {
    //opens database file or creates it if it doesnt exist
    final database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    //try {
    const String plotQuery = "SELECT * from plots";
    final plotResults = database.select(plotQuery);

    for (final plotResult in plotResults) plots.add(Plot.fromJson(plotResult));

    const String binPathQuery =
        "SELECT value from settings WHERE entry = 'binPath' LIMIT 1";
    final binPathResults = database.select(binPathQuery);
    for (final binPathResult in binPathResults)
      _binPath = binPathResult['value'];

    const String filterQuery = "SELECT * from filters WHERE timestamp > ?";
    final filterResults = database.select(filterQuery, [parseUntil]);
    for (var filterResult in filterResults)
      filters.add(Filter.fromJson(filterResult, plots.length));

    const String spQuery = "SELECT * from signagePoints WHERE timestamp > ?";
    final spResults = database.select(spQuery, [parseUntil]);
    for (final spResult in spResults)
      signagePoints.add(SignagePoint.fromJson(spResult));

    const String ssQuery = "SELECT * from shortSyncs WHERE timestamp > ?";
    final ssResults = database.select(ssQuery, [parseUntil]);
    for (final ssResult in ssResults)
      shortSyncs.add(ShortSync.fromJson(ssResult));

    const String peQuery =
        "SELECT * from errors WHERE type = 'pool' AND timestamp > ?";
    final peResults = database.select(peQuery, [parseUntil]);
    for (final peResult in peResults)
      poolErrors.add(LogItem.fromJson(peResult, LogItemType.Farmer));

    const String heQuery =
        "SELECT * from errors WHERE type = 'harvester' AND timestamp > ?";
    final heResults = database.select(heQuery, [parseUntil]);
    for (final heResult in heResults)
      harvesterErrors.add(LogItem.fromJson(heResult, LogItemType.Farmer));

    const String memoryQuery = "SELECT * from memories WHERE timestamp > ?";
    final memoryResults = database.select(memoryQuery, [parseUntil]);
    for (final memoryResult in memoryResults)
      memories.add(Memory.fromJson(memoryResult));
    // } catch (Exception) {
    //  log.severe(
    //       "ERROR: Failed to load ${cache.path}\nGenerating a new cache database.");
    // }

    database.dispose();
  }

  String _askForBinPath() {
    String exampleDir = (io.Platform.isLinux || io.Platform.isMacOS)
        ? "/home/user/${blockchain.binaryName}-blockchain"
        : (io.Platform.isWindows)
            ? "C:\\Users\\user\\AppData\\Local\\${blockchain.binaryName}-blockchain or C:\\Users\\user\\AppData\\Local\\${blockchain.binaryName}-blockchain\\app-1.0.3\\resources\\app.asar.unpacked"
            : "";

    bool validDirectory = false;

    validDirectory = _tryDirectories();

    if (validDirectory)
      log.info(
          "Automatically found ${blockchain.binaryName} binary at: '$_binPath'");
    else
      log.info("Could not automatically locate chia binary.");

    while (!validDirectory) {
      log.warning(
          "Specify your ${blockchain.binaryName}-blockchain directory below: (e.g.: " +
              exampleDir +
              ")");

      blockchain.cache.chiaPath = io.stdin.readLineSync() ?? '';
      log.info("Input chia path: '${blockchain.cache.chiaPath}'");

      _binPath = (io.Platform.isLinux || io.Platform.isMacOS)
          ? blockchain.cache.chiaPath + "/venv/bin/${blockchain.binaryFilename}"
          : blockchain.cache.chiaPath +
              "\\daemon\\${blockchain.binaryFilename}.exe";

      if (io.File(_binPath!).existsSync())
        validDirectory = true;
      else if (io.Directory(blockchain.cache.chiaPath).existsSync())
        log.warning("""Could not locate chia binary in your directory.
($_binPath not found)
Please try again.
Make sure this folder has the same structure as Chia's GitHub repo.""");
      else
        log.warning(
            "Uh oh, that directory could not be found! Please try again.");
    }

    _save(); //saves bin path to cache

    return _binPath!;
  }

  //If in windows, tries a bunch of directories
  bool _tryDirectories() {
    bool valid = false;

    late io.Directory chiaRootDir;
    late String file;

    if (io.Platform.isWindows) {
      //Checks if binary exist in C:\User\AppData\Local\chia-blockchain\resources\app.asar.unpacked\daemon\chia.exe
      if (blockchain.binaryName != "spare") {
        chiaRootDir = io.Directory(io.Platform.environment['UserProfile']! +
            "/AppData/Local/${blockchain.binaryName}-blockchain");

        file =
            "/resources/app.asar.unpacked/daemon/${blockchain.binaryFilename}.exe";

        if (chiaRootDir.existsSync()) {
          chiaRootDir.listSync(recursive: false).forEach((dir) {
            io.File trypath = io.File(dir.path + file);
            if (trypath.existsSync()) {
              _binPath = trypath.path;
              valid = true;
            }
          });
        }
      }
      //hard codes spare path
      else {
        chiaRootDir = io.Directory(io.Platform.environment['UserProfile']! +
            "/AppData/Local/Spare-blockchain");

        file =
            "/resources/app.asar.unpacked/daemon/${blockchain.binaryFilename}.exe";

        if (chiaRootDir.existsSync()) {
          io.File trypath = io.File(chiaRootDir.path + file);
          if (trypath.existsSync()) {
            _binPath = trypath.path;
            valid = true;
          }
        }
      }
    } else if (io.Platform.isLinux || io.Platform.isMacOS) {
      List<String> possiblePaths = [];

      if (io.Platform.isLinux) {
        chiaRootDir =
            io.Directory("/usr/lib/${blockchain.binaryName}-blockchain");
        file =
            "/resources/app.asar.unpacked/daemon/${blockchain.binaryFilename}";
      } else if (io.Platform.isMacOS) {
        //capitalizes first letter of a string
        String capitalize(String input) {
          return "${input[0].toUpperCase()}${input.substring(1)}";
        }

        chiaRootDir = io.Directory(
            "/Applications/${capitalize(blockchain.binaryName)}.app/Contents");
        file =
            "/Resources/app.asar.unpacked/daemon/${blockchain.binaryFilename}";
      }

      possiblePaths = [
        // checks if binary exists in /package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia in linux or
        // checks if binary exists in /Applications/Chia.app/Contents/Resources/app.asar.unpacked/daemon/chia in macOS
        chiaRootDir.path + file,
        // Checks if binary exists in /usr/package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia
        "/usr" + chiaRootDir.path + file,
        //checks if binary exists in /home/user/.local/bin/chia
        io.Platform.environment['HOME']! +
            "/.local/bin/${blockchain.binaryFilename}",

        //checks for file in /home/user/chia-blockchain/venv/bin/chia
        io.Platform.environment['HOME']! +
            "/${blockchain.binaryName}-blockchain/venv/bin/${blockchain.binaryFilename}"
      ];

      for (int i = 0; i < possiblePaths.length; i++) {
        io.File possibleFile = io.File(possiblePaths[i]);

        if (possibleFile.existsSync()) {
          _binPath = possibleFile.path;
          valid = true;
        }
      }
    }

    return valid;
  }
}
