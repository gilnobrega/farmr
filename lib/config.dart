import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:dart_console/dart_console.dart';
import 'package:qr/qr.dart';
import 'package:yaml/yaml.dart';

import 'plot.dart';

class Config {
  ClientType _type;
  ClientType get type => _type;

  String _id;
  String get id => _id;

  String _chiaPath;
  String get chiaPath => _chiaPath;

  //Sets config file path according to platform
  String _chiaConfigPath = (io.Platform.isLinux)
      ? io.Platform.environment['HOME'] + "/.chia/mainnet/config/"
      : (io.Platform.isWindows)
          ? io.Platform.environment['UserProfile'] + "\\.chia\\mainnet\\config\\"
          : "";

  String get chiaConfigPath => _chiaConfigPath;

  String _binPath;
  String get binPath => _binPath;

  bool _showBalance = true;
  bool get showBalance => _showBalance;

  bool _sendPlotNotifications = true; //plot notifications
  bool get sendPlotNotifications => _sendPlotNotifications;

  bool _sendBalanceNotifications = true; //balance notifications
  bool get sendBalanceNotifications => _sendBalanceNotifications;

  List<Plot> _plots = []; //cached plots
  List<Plot> get plots => _plots;

  final io.File _config = io.File("config.json");
  final io.File _cache = io.File(".chiabot_cache.json");

  Config([isHarvester = false]) {
    //Move old config/cache files to new locations
    io.File _oldConfig = io.File(this.chiaConfigPath + "chiabot.json");
    io.File _oldCache = io.File(this.chiaConfigPath + "chiabot_cache.json");

    try {
      //Copies old config file to new path and deletes old config file
      if (_oldConfig.existsSync()) {
        _oldConfig.copySync(_config.absolute.path);
        _oldConfig.deleteSync();
      }

      if (!_cache.existsSync() && _oldCache.existsSync()) _oldCache.copySync(_cache.absolute.path);
    } catch (e) {
      print("Failed to port old config files!");
    }

    _type = (!isHarvester) ? ClientType.Farmer : ClientType.Harvester;

    _id = Uuid().v4();
  }

  Future<void> init() async {
    //Loads cache file
    if (!_cache.existsSync())
      _saveCache(); //creates cache file if doesnt exist
    else
      _loadCache(); //chiabot_cache.json

    //If file doesnt exist then create new config
    if (!_config.existsSync())
      await saveConfig(); //creates config file if doesnt exist
    //If file exists then loads config
    else
      _loadConfig(); //chiabot.json

    //and asks for bin path if path is not defined/not found
    if (_binPath == null || !io.File(_binPath).existsSync()) await _askForBinPath();

    info(); //shows first screen info with qr code, id, !chia, etc.
  }

  //Creates config file
  Future<void> saveConfig() async {
    String contents = formatJson(jsonEncode([
      {
        "chiaPath": chiaPath,
        "showBalance": showBalance,
        "sendPlotNotifications": sendPlotNotifications,
        "sendBalanceNotifications": sendBalanceNotifications,
      }
    ]));

    _config.writeAsStringSync(contents);
  }

  Future<void> _askForBinPath() async {
    String exampleDir = (io.Platform.isLinux)
        ? "/home/user/chia-blockchain"
        : (io.Platform.isWindows)
            ? "C:\\Users\\user\\AppData\\Local\\chia-blockchain or C:\\Users\\user\\AppData\\Local\\chia-blockchain\\app-1.0.3\\resources\\app.asar.unpacked"
            : "";

    bool validDirectory = false;

    validDirectory = await _tryDirectories();

    while (!validDirectory) {
      print("Specify your chia-blockchain directory below: (e.g.: " + exampleDir + ")");

      _chiaPath = io.stdin.readLineSync();

      _binPath =
          (io.Platform.isLinux) ? _chiaPath + "/venv/bin/chia" : _chiaPath + "\\daemon\\chia.exe";

      if (io.File(_binPath).existsSync())
        validDirectory = true;
      else if (io.Directory(chiaPath).existsSync())
        print("Could not locate chia binary in your directory.\n(" +
            _binPath +
            " not found)\nPlease try again." +
            "\nMake sure this folder has the same structure as Chia's GitHub repo.");
      else
        print("Uh oh, that directory could not be found! Please try again.");
    }

    await saveConfig(); //saves path input by user to config
    _saveCache(); //saves bin path to cache
  }

  //If in windows, tries a bunch of directories
  Future<bool> _tryDirectories() async {
    bool valid = false;

    io.Directory chiaRootDir;
    String file;

    if (io.Platform.isWindows) {
      //Checks if binary exist in C:\User\AppData\Local\chia-blockchain\resources\app.asar.unpacked\daemon\chia.exe
      chiaRootDir =
          io.Directory(io.Platform.environment['UserProfile'] + "/AppData/Local/chia-blockchain");

      file = "/resources/app.asar.unpacked/daemon/chia.exe";

      if (chiaRootDir.existsSync()) {
        await chiaRootDir.list(recursive: false).forEach((dir) {
          io.File trypath = io.File(dir.path + file);
          if (trypath.existsSync()) {
            _binPath = trypath.path;
            valid = true;
          }
        });
      }
    } else if (io.Platform.isLinux) {
      chiaRootDir = io.Directory("/lib/chia-blockchain");
      file = "/resources/app.asar.unpacked/daemon/chia";

      List<String> possiblePaths = [
        // checks if binary exists in /lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia
        chiaRootDir.path + file,
        // Checks if binary exists in /usr/lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia
        "/usr" + chiaRootDir.path + file,
        //checks if binary exists in /home/user/.local/bin/chia
        io.Platform.environment['HOME'] + "/.local/bin/chia"
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

  Future<void> _loadConfig() async {
    var contents = jsonDecode(_config.readAsStringSync());

    //leave this here for compatibility with old versions,
    //old versions stored id in config file
    if (contents[0]['id'] != null) _id = contents[0]['id'];

    _chiaPath = contents[0]['chiaPath'];

    //this used to be in the config file in earlier versions
    //do not remove this
    if (contents[0]['binPath'] != null) _binPath = contents[0]['binPath'];

    if (contents[0]['showBalance'] != null) _showBalance = contents[0]['showBalance'];

    if (contents[0]['sendPlotNotifications'] != null)
      _sendPlotNotifications = contents[0]['sendPlotNotifications'];

    if (contents[0]['sendBalanceNotifications'] != null)
      _sendBalanceNotifications = contents[0]['sendBalanceNotifications'];
  }

  //saves cache file
  void _saveCache() {
    String contents = jsonEncode([
      {"id": id, "binPath": binPath, "plots": plots}
    ]);
    _cache.writeAsStringSync(contents);
  }

  void _loadCache() {
    var contents = jsonDecode(_cache.readAsStringSync());

    //loads id from cache file
    if (contents[0]['id'] != null) _id = contents[0]['id'];

    //loads chia binary path from cache
    if (contents[0]['binPath'] != null) _binPath = contents[0]['binPath'];

    //loads plot list from cache file
    if (contents[0]['plots'] != null) {
      var plotsJson = contents[0]['plots'];

      for (var plotJson in plotsJson) plots.add(Plot.fromJson(plotJson));
    }
  }

  void savePlotsCache(List<Plot> plots) {
    _plots = plots;
    _saveCache();
  }

  void info() {
    final console = Console();
    console.clearScreen();

    showQR(console);

    String line = "";

    for (int i = 0; i < console.windowWidth; i++) line += "=";

    print(line);
    print("Your id is " + id + ", run");
    print("");
    print("!chia link " + id);
    print("");
    print("to link this client to your discord user");
    print("You can interact with ChiaBot in its discord server.");
    print("Open the following link to join the server: https://discord.gg/pxgh8tBzGU ");
    print(line);
    print("");
  }

  void showQR(Console console) {
    final qrCode = new QrCode(3, QrErrorCorrectLevel.L);
    qrCode.addData(id);
    qrCode.make();

    //If terminal is long enough to show a qr code
    if (console.windowHeight > 2 * qrCode.moduleCount &&
        console.windowWidth > 2 * qrCode.moduleCount) {
      for (int x = 0; x < qrCode.moduleCount; x++) {
        for (int y = 0; y < qrCode.moduleCount; y++) {
          if (qrCode.isDark(y, x)) {
            console.setBackgroundColor(ConsoleColor.black);
            console.setForegroundColor(ConsoleColor.white);
            console.write("  ");
          } else {
            console.setBackgroundColor(ConsoleColor.white);
            console.setForegroundColor(ConsoleColor.black);
            console.write("  ");
          }
        }
        console.resetColorAttributes();
        console.write("\n");
      }
    }
  }
}

//Tells if client is harvester or not
enum ClientType { Farmer, Harvester }

//Converts a YAML List to a String list
//Used to parse chia's config.yaml
List<String> ylistToStringlist(YamlList input) {
  List<String> output = [];
  for (int i = 0; i < input.length; i++) {
    output.add(input[i].toString());
  }
  return output;
}

String formatJson(String input) {
  return input
      .replaceAll(",", ",\n")
      .replaceAll("{", "{\n")
      .replaceAll("}", "\n}\n")
      .replaceAll("[", "[\n")
      .replaceAll("]", "]\n")
      .replaceAll(":", ": ");
}
