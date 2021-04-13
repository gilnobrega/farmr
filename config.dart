import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:dart_console/dart_console.dart';
import 'package:qr/qr.dart';

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

  bool _sendPlotNotifications = true; //plot notifications
  bool get sendPlotNotifications => _sendPlotNotifications;

  bool _sendBalanceNotifications = true; //balance notifications
  bool get sendBalanceNotifications => _sendBalanceNotifications;

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
        "showBalance": showBalance,
        "sendPlotNotifications": sendPlotNotifications,
        "sendBalanceNotifications": sendBalanceNotifications
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
      io.File tryPath = io.File(chiaRootDir.path +
          file); // checks if binary exists in /lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia
      io.File tryPath2 = io.File("/usr" +
          chiaRootDir.path +
          file); // Checks if binary exists in /usr/lib/chia-blockchain/resources/app.asar.unpacked/daemon/chia

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

    if (contents[0]['sendPlotNotifications'] != null)
      _sendPlotNotifications = contents[0]['sendPlotNotifications'];

    if (contents[0]['sendBalanceNotifications'] != null)
      _sendBalanceNotifications = contents[0]['sendBalanceNotifications'];

    await createConfig((_type == ClientType.Harvester));
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
    print(
        "Open the following link to join the server: https://discord.gg/pxgh8tBzGU ");
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
