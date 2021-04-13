import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';

class Config {
  ClientType _type;
  ClientType get type => _type;

  String _id;
  String get id => _id;

  String _chiaPath;
  String get chiaPath => _chiaPath;

  //Sets config file path according to platform
  final String _configPath = (io.Platform.isLinux)
      ? io.Platform.environment['HOME'] + "/.chia/mainnet/config/"
      : (io.Platform.isWindows)
          ? io.Platform.environment['UserProfile'] +
              "\\.chia\\mainnet\\config\\"
          : "";
  String get configPath => _configPath;

  String _binPath;
  String get binPath => _binPath;

  bool _showBalance = true;
  bool get showBalance => _showBalance;

  io.File _config;

  Config([isHarvester = false]) {
    _config = new io.File(configPath + "chiabot.json");

    _id = Uuid().v4();
  }

  Future<void> init(bool isHarvester) async {
    //If file doesnt exist then create new config
    if (!_config.existsSync())
      await createConfig(isHarvester);
    //If file exists then loads config
    else
      loadConfig();
  }

  Future<void> createConfig(bool isHarvester) async {
    _type = (!isHarvester) ? ClientType.Farmer : ClientType.Harvester;

    if (_binPath == null || !io.File(_binPath).existsSync())
      await askForBinPath();

    String contents = jsonEncode([
      {
        "id": id,
        "chiaPath": chiaPath,
        "type": type.index,
        "binPath": binPath,
        "showBalance": showBalance
      }
    ]);

    _config.writeAsStringSync(contents);

    info();
  }

  Future<void> askForBinPath() async {
    String exampleDir = (io.Platform.isLinux)
        ? "/home/user/chia-blockchain"
        : (io.Platform.isWindows)
            ? "C:\\Users\\user\\AppData\\Local\\chia-blockchain or C:\\Users\\user\\AppData\\Local\\chia-blockchain\\app-1.0.3\\resources\\app.asar.unpacked"
            : "";

    bool validDirectory = false;

    validDirectory = await tryDirectories();

    while (!validDirectory) {
      print("Specify your chia-blockchain directory below: (e.g.: " +
          exampleDir +
          ")");

      _chiaPath = io.stdin.readLineSync();

      _binPath = (io.Platform.isLinux)
          ? _chiaPath + "/venv/bin/chia"
          : _chiaPath + "\\daemon\\chia.exe";

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
  }

  //If in windows, tries a bunch of directories
  Future<bool> tryDirectories() async {
    bool valid = false;

    io.Directory chiaRootDir;
    String file;

    if (io.Platform.isWindows) {
      chiaRootDir = io.Directory(io.Platform.environment['UserProfile'] +
          "/AppData/Local/chia-blockchain");

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
      io.File tryPath = io.File(chiaRootDir.path + file); // checks if binary exists in /lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia
      io.File tryPath2 = io.File("/usr" + chiaRootDir.path + file);   // Checks if binary exists in /usr/lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia

      if (tryPath.existsSync()) {
        _binPath = tryPath.path;
        valid = true;
      } else if (tryPath2.existsSync()) {
        _binPath = tryPath2.path;
        valid = true;
      }
    }

    return valid;
  }

  Future<void> loadConfig() async {
    var contents = jsonDecode(_config.readAsStringSync());

    _id = contents[0]['id'];
    _chiaPath = contents[0]['chiaPath'];

    _type = ClientType.values[contents[0]['type']];
    _binPath = contents[0]['binPath'];

    if (contents[0]['showBalance'] != null)
      _showBalance = contents[0]['showBalance'];

    await createConfig((_type == ClientType.Harvester));
  }

  void info() {
    print("Your id is " + id + ", run");
    print("!chia link " + id);
    print("to link this client to your discord user");
  }
}

//Tells if client is harvester or not
enum ClientType { Farmer, Harvester }
