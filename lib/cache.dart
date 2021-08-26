import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/log/logitem.dart';
import 'package:farmr_client/utils/sqlite.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';

import 'package:farmr_client/hardware.dart';

import 'package:sqlite3/sqlite3.dart';

final log = Logger('Cache');

class Cache {
  late Blockchain blockchain;

  String chiaPath = '';

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

  late final Database database;

  Cache(this.blockchain, this.rootPath) {
    cache = io.File(rootPath + "cache/cache${blockchain.fileExtension}.sqlite");

    //opens database file or creates it if it doesnt exist
    database = openSQLiteDB(cache.path, OpenMode.readWriteCreate);

    // Create a table and insert some data
    database.execute('''
    CREATE TABLE IF NOT EXISTS filters (
      timestamp INTEGER NOT NULL PRIMARY KEY,
      eligible INTEGER NOT NULL,
      proofs INTEGER NOT NULL,
      plotNumber INTEGER NOT NULL,
      lookupTime INTEGER NOT NULL
    );
  ''');
  }

  Future<void> init() async {
    //Tells log parser when it should stop parsing
    parseUntil =
        DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;
  }

  //saves cache file
  void save() {}

  void load() {
    try {
      var contents = jsonDecode(cache.readAsStringSync());
      //print(contents);

      //LOADS IDS FROM CACHE FILE (backwards compatible)
      //loads id from cache file
      if (contents[0]['id'] != null) {
        blockchain.id.ids = [];
        blockchain.id.ids.add(contents[0]['id']);
        blockchain.id.save();
      }

      chiaPath = contents[0]['${blockchain.binaryName}Path'] ?? "";

      //loads ids from cache file
      if (contents[0]['ids'] != null) {
        blockchain.id.ids = [];
        for (String id in contents[0]['ids']) blockchain.id.ids.add(id);
        blockchain.id.save();
      }

      //loads plot list from cache file
      if (contents[0]['plots'] != null) {
        plots = [];
        var plotsJson = contents[0]['plots'];

        for (var plotJson in plotsJson) plots.add(Plot.fromJson(plotJson));
      }

      //loads chia binary path from cache
      if (contents[0]['binPath'] != null && contents[0]['binPath'] != "")
        _binPath = contents[0]['binPath'];

      //loads filters list from cache file
      if (contents[0]['filters'] != null) {
        filters = [];
        var filtersJson = contents[0]['filters'];

        for (var filterJson in filtersJson) {
          Filter filter = Filter.fromJson(filterJson, plots.length);
          if (filter.timestamp > parseUntil) filters.add(filter);
        }
      }

      //loads subslots list from cache file
      if (contents[0]['signagePoints'] != null) {
        signagePoints = [];
        var signagePointsJson = contents[0]['signagePoints'];

        for (var signagePointJson in signagePointsJson) {
          SignagePoint signagePoint = SignagePoint.fromJson(signagePointJson);
          if (signagePoint.timestamp > parseUntil)
            signagePoints.add(signagePoint);
        }
      }

      //loads shortsyncs list from cache file
      if (contents[0]['shortSyncs'] != null) {
        shortSyncs = [];
        var shortSyncsJson = contents[0]['shortSyncs'];

        for (var shortSyncJson in shortSyncsJson) {
          ShortSync shortSync = ShortSync.fromJson(shortSyncJson);
          if (shortSync.timestamp > parseUntil) shortSyncs.add(shortSync);
        }
      }

      //loads pool errors list from cache file
      if (contents[0]['poolErrors'] != null) {
        poolErrors = [];
        var poolErrorsJson = contents[0]['poolErrors'];

        for (var poolErrorJson in poolErrorsJson) {
          LogItem poolError =
              LogItem.fromJson(poolErrorJson, LogItemType.Farmer);
          if (poolError.timestamp > parseUntil) poolErrors.add(poolError);
        }
      }

      //loads harvester errors list from cache file
      if (contents[0]['harvesterErrors'] != null) {
        harvesterErrors = [];
        var harvesterErrorsJson = contents[0]['harvesterErrors'];

        for (var harvesterErrorJson in harvesterErrorsJson) {
          LogItem harvesterError =
              LogItem.fromJson(harvesterErrorJson, LogItemType.Farmer);
          if (harvesterError.timestamp > parseUntil)
            harvesterErrors.add(harvesterError);
        }
      }

      //loads memories list from cache file
      if (contents[0]['memories'] != null) {
        memories = [];
        var memoriesJson = contents[0]['memories'];

        for (var memoryJson in memoriesJson) {
          Memory memory = Memory.fromJson(memoryJson);
          if (memory.timestamp > parseUntil) memories.add(memory);
        }
      }
    } catch (Exception) {
      log.severe(
          "ERROR: Failed to load .farmr_cache${blockchain.fileExtension}.json\nGenerating a new cache file.");
    }
  }

  void savePlots(List<Plot> newPlots) {
    plots = newPlots;
    save();
  }

  void saveFilters(List<Filter> newFilters) {
    filters = newFilters;
    save();
  }

  void saveSignagePoints(List<SignagePoint> newSignagePoints) {
    signagePoints = newSignagePoints;
    save();
  }

  void saveShortSyncs(List<ShortSync> newShortSyncs) {
    shortSyncs = newShortSyncs;
    save();
  }

  void savePoolErrors(List<LogItem> newPoolErrors) {
    poolErrors = newPoolErrors;
    save();
  }

  void saveHarvesterErrors(List<LogItem> newHarvesterErrors) {
    harvesterErrors = newHarvesterErrors;
    save();
  }

  void saveMemories(List<Memory> newMemories) {
    memories = newMemories;
    save();
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
          ? blockchain.cache.chiaPath + "/venv/bin/${blockchain.binaryName}"
          : blockchain.cache.chiaPath +
              "\\daemon\\${blockchain.binaryName}.exe";

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

    save(); //saves bin path to cache

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
            "/resources/app.asar.unpacked/daemon/${blockchain.binaryName}.exe";

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
            "/resources/app.asar.unpacked/daemon/${blockchain.binaryName}.exe";

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
        file = "/resources/app.asar.unpacked/daemon/${blockchain.binaryName}";
      } else if (io.Platform.isMacOS) {
        //capitalizes first letter of a string
        String capitalize(String input) {
          return "${input[0].toUpperCase()}${input.substring(1)}";
        }

        chiaRootDir = io.Directory(
            "/Applications/${capitalize(blockchain.binaryName)}.app/Contents");
        file = "/Resources/app.asar.unpacked/daemon/${blockchain.binaryName}";
      }

      possiblePaths = [
        // checks if binary exists in /package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia in linux or
        // checks if binary exists in /Applications/Chia.app/Contents/Resources/app.asar.unpacked/daemon/chia in macOS
        chiaRootDir.path + file,
        // Checks if binary exists in /usr/package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia
        "/usr" + chiaRootDir.path + file,
        //checks if binary exists in /home/user/.local/bin/chia
        io.Platform.environment['HOME']! +
            "/.local/bin/${blockchain.binaryName}",

        //checks for file in /home/user/chia-blockchain/venv/bin/chia
        io.Platform.environment['HOME']! +
            "/${blockchain.binaryName}-blockchain/venv/bin/${blockchain.binaryName}"
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
