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

    //If file doesnt exist then create new config
    if (!_config.existsSync())
      createConfig(isHarvester);
    //If file exists then loads config
    else
      loadConfig();
  }

  Future<void> createConfig(bool isHarvester) async {
    _type = (!isHarvester) ? ClientType.Farmer : ClientType.Harvester;

    _id = Uuid().v4();

    String exampleDir = (io.Platform.isLinux)
        ? "/home/user/chia-blockchain"
        : (io.Platform.isWindows)
            ? "C:\\Users\\user\\AppData\\Local\\chia-blockchain or C:\\Users\\user\\AppData\\Local\\chia-blockchain\\app-1.0.3\\resources\\app.asar.unpacked"
            : "";

    print("Specify your chia-blockchain directory below: (e.g.: " +
        exampleDir +
        ")");

    bool validDirectory = false;

    if (io.Platform.isWindows) validDirectory = await tryDirectories();

    while (!validDirectory) {
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

  //If in windows, tries a bunch of directories
  Future<bool> tryDirectories() async {
    bool valid = false;

    io.Directory chiaRootDir = io.Directory(
        io.Platform.environment['UserProfile'] +
            "\\AppData\\Local\\chia-blockchain");

    if (chiaRootDir.existsSync()) {
      chiaRootDir.list(recursive: true).forEach((dir) {
        String trypath = dir.path + "\\daemon\\chia.exe";
        if (io.File(trypath).existsSync()) {
          _binPath = trypath;
          valid = true;
        }
      });
    }

    return valid;
  }

  void loadConfig() {
    var contents = jsonDecode(_config.readAsStringSync());

    _id = contents[0]['id'];
    _chiaPath = contents[0]['chiaPath'];

    _type = ClientType.values[contents[0]['type']];
    _binPath = contents[0]['binPath'];

    if (contents[0]['showBalance'] != null)
      _showBalance = contents[0]['showBalance'];

    info();
  }

  void info() {
    print("Your id is " + id + ", run");
    print("!chia link " + id);
    print("to link this client to your discord user");
  }
}

//Tells if client is harvester or not
enum ClientType { Farmer, Harvester }
