import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/log/logitem.dart';
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

  String chiaPath = '';

  String? _binPath;
  String get binPath {
    if (Blockchain.detectOS() != OS.GitHub) {
      if (_binPath != null && io.File(_binPath!).existsSync())
        return _binPath!;
      else
        return _askForBinPath();
    } else
      return "";
  }

  List<Plot> _plots = []; //cached plots
  List<Plot> get plots => _plots;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SignagePoint> _signagePoints = [];
  List<SignagePoint> get signagePoints => _signagePoints;

  List<ShortSync> _shortSyncs = [];
  List<ShortSync> get shortSyncs => _shortSyncs;

  List<LogItem> _poolErrors = [];
  List<LogItem> get poolErrors => _poolErrors;

  List<LogItem> _harvesterErrors = [];
  List<LogItem> get harvesterErrors => _harvesterErrors;

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
        "poolErrors": poolErrors,
        "harvesterErrors": harvesterErrors,
        "${_blockchain.binaryName}Path": chiaPath
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

      chiaPath = contents[0]['${_blockchain.binaryName}Path'] ?? "";

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
      if (contents[0]['binPath'] != null && contents[0]['binPath'] != "")
        _binPath = contents[0]['binPath'];

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

      //loads pool errors list from cache file
      if (contents[0]['poolErrors'] != null) {
        _poolErrors = [];
        var poolErrorsJson = contents[0]['poolErrors'];

        for (var poolErrorJson in poolErrorsJson) {
          LogItem poolError =
              LogItem.fromJson(poolErrorJson, LogItemType.Farmer);
          if (poolError.timestamp > parseUntil) _poolErrors.add(poolError);
        }
      }

      //loads harvester errors list from cache file
      if (contents[0]['harvesterErrors'] != null) {
        _harvesterErrors = [];
        var harvesterErrorsJson = contents[0]['harvesterErrors'];

        for (var harvesterErrorJson in harvesterErrorsJson) {
          LogItem harvesterError =
              LogItem.fromJson(harvesterErrorJson, LogItemType.Farmer);
          if (harvesterError.timestamp > parseUntil)
            _harvesterErrors.add(harvesterError);
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

  void savePoolErrors(List<LogItem> poolErrors) {
    _poolErrors = poolErrors;
    save();
  }

  void saveHarvesterErrors(List<LogItem> harvesterErrors) {
    _harvesterErrors = harvesterErrors;
    save();
  }

  void saveMemories(List<Memory> memories) {
    _memories = memories;
    save();
  }

  String _askForBinPath() {
    String exampleDir = (io.Platform.isLinux || io.Platform.isMacOS)
        ? "/home/user/${_blockchain.binaryName}-blockchain"
        : (io.Platform.isWindows)
            ? "C:\\Users\\user\\AppData\\Local\\${_blockchain.binaryName}-blockchain or C:\\Users\\user\\AppData\\Local\\${_blockchain.binaryName}-blockchain\\app-1.0.3\\resources\\app.asar.unpacked"
            : "";

    bool validDirectory = false;

    validDirectory = _tryDirectories();

    if (validDirectory)
      log.info(
          "Automatically found ${_blockchain.binaryName} binary at: '$_binPath'");
    else
      log.info("Could not automatically locate chia binary.");

    while (!validDirectory) {
      log.warning(
          "Specify your ${_blockchain.binaryName}-blockchain directory below: (e.g.: " +
              exampleDir +
              ")");

      _blockchain.cache.chiaPath = io.stdin.readLineSync() ?? '';
      log.info("Input chia path: '${_blockchain.cache.chiaPath}'");

      _binPath = (io.Platform.isLinux || io.Platform.isMacOS)
          ? _blockchain.cache.chiaPath + "/venv/bin/${_blockchain.binaryName}"
          : _blockchain.cache.chiaPath +
              "\\daemon\\${_blockchain.binaryName}.exe";

      if (io.File(_binPath!).existsSync())
        validDirectory = true;
      else if (io.Directory(_blockchain.cache.chiaPath).existsSync())
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
      if (_blockchain.binaryName != "spare") {
        chiaRootDir = io.Directory(io.Platform.environment['UserProfile']! +
            "/AppData/Local/${_blockchain.binaryName}-blockchain");

        file =
            "/resources/app.asar.unpacked/daemon/${_blockchain.binaryName}.exe";

        //cryptodoge only
        if (_blockchain.binaryName == "cryptodoge")
          file = file.replaceAll("/daemon", "");

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
            "/resources/app.asar.unpacked/daemon/${_blockchain.binaryName}.exe";

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
            io.Directory("/usr/lib/${_blockchain.binaryName}-blockchain");
        file = "/resources/app.asar.unpacked/daemon/${_blockchain.binaryName}";
      } else if (io.Platform.isMacOS) {
        //capitalizes first letter of a string
        String capitalize(String input) {
          return "${input[0].toUpperCase()}${input.substring(1)}";
        }

        chiaRootDir = io.Directory(
            "/Applications/${capitalize(_blockchain.binaryName)}.app/Contents");
        file = "/Resources/app.asar.unpacked/daemon/${_blockchain.binaryName}";
      }

      possiblePaths = [
        // checks if binary exists in /package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia in linux or
        // checks if binary exists in /Applications/Chia.app/Contents/Resources/app.asar.unpacked/daemon/chia in macOS
        chiaRootDir.path + file,
        //cryptodoge only
        chiaRootDir.path.replaceAll("/daemon", "") + file,

        // Checks if binary exists in /usr/package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia
        "/usr" + chiaRootDir.path + file,
        //cryptodoge only
        "/usr" + chiaRootDir.path.replaceAll("/daemon", "") + file,

        //checks if binary exists in /home/user/.local/bin/chia
        io.Platform.environment['HOME']! +
            "/.local/bin/${_blockchain.binaryName}",

        //checks for file in /home/user/chia-blockchain/venv/bin/chia
        io.Platform.environment['HOME']! +
            "/${_blockchain.binaryName}-blockchain/venv/bin/${_blockchain.binaryName}"
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
