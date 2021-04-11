import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:dotenv/dotenv.dart';

class Config {
  ClientType _type;
  ClientType get type => _type;

  String _id;
  String get id => _id;

  String _chiaPath;
  String get chiaPath => _chiaPath;

  //Sets config file path according to platform
  final String _configPath = (io.Platform.isLinux)
      ? env['HOME'] + "/.chia/mainnet/config/"
      : (io.Platform.isWindows)
          ? env['UserProfile'] + "\.chia\mainnet\config\\"
          : "";
  String get configPath => _configPath;

  String _binPath;
  String get binPath => _binPath;

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

  void createConfig(bool isHarvester) {
    _type = (!isHarvester) ? ClientType.Farmer : ClientType.Harvester;

    _id = Uuid().v4();

    String exampleDir = (io.Platform.isLinux)
        ? "/home/user/chia-blockchain"
        : (io.Platform.isWindows)
            ? "C:\Users\\user\%AppData%\Local\chia-blockchain"
            : "";

    print("Specify your chia-blockchain directory below: (e.g.: " +
        exampleDir +
        ")");

    bool validDirectory = false;

    while (!validDirectory) {
      _chiaPath = io.stdin.readLineSync();

      _binPath = (io.Platform.isLinux)
          ? _chiaPath + "/venv/bin/chia"
          : _chiaPath + "\chia.exe";

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
      {"id": id, "chiaPath": chiaPath, "type": type.index, "binPath" : binPath}
    ]);

    _config.writeAsStringSync(contents);

    info();
  }

  void loadConfig() {
    var contents = jsonDecode(_config.readAsStringSync());

    _id = contents[0]['id'];
    _chiaPath = contents[0]['chiaPath'];

    _type = ClientType.values[contents[0]['type']];
    _binPath = contents[0]['binPath'];

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
