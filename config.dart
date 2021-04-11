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

  final String _configPath = env['HOME'] + "/.chia/mainnet/config/chiabot.json";
  String get configPath => _configPath;

  io.File _config;

  Config([isHarvester = false]) {
    _config = new io.File(configPath);

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

    print(
        "Specify your chia-blockchain directory below: (e.g.: /home/user/chia-blockchain)");

    bool validDirectory = false;

    while (!validDirectory) {
      _chiaPath = io.stdin.readLineSync();

      if (io.File(chiaPath + "/venv/bin/chia").existsSync())
        validDirectory = true;
      else if (io.Directory(chiaPath).existsSync())
        print("Could not locate chia binary in your directory. Please try again." +
            "\nMake sure this folder has the same structure as Chia's GitHub repo.");
      else
        print("Uh oh, that directory could not be found! Please try again.");
    }

    String contents = jsonEncode([
      {"id": id, "chiaPath": chiaPath, "type": type.index}
    ]);

    _config.writeAsStringSync(contents);

    info();
  }

  void loadConfig() {
    var contents = jsonDecode(_config.readAsStringSync());

    _id = contents[0]['id'];
    _chiaPath = contents[0]['chiaPath'];

    _type = ClientType.values[contents[0]['type']];

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
