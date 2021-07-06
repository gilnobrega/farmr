import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/cache.dart';

final log = Logger('Config');

class Config {
  Cache cache;

  late Blockchain _blockchain;

  ClientType _type = ClientType.Harvester;
  ClientType get type => _type;

  //Optional, custom, user defined name
  late String name;

  //Optional, custom 3 letter currency
  String currency = 'USD';

  String _chiaPath = '';
  String get chiaPath => _chiaPath;

  //farmed balance
  bool showBalance = true;

  //wallet balance
  bool showWalletBalance = false;

  bool sendPlotNotifications = false; //plot notifications

  bool sendDriveNotifications = true; //drive notifications

  bool sendBalanceNotifications = true; //balance notifications

  bool sendOfflineNotifications = false; //status notifications

  bool sendStatusNotifications = true; //status notifications

  bool parseLogs = false;

  //number of users that can link this machine
  int userNumber = 1;

  String swarPath = "";

  //if this is set to true then client's data will be available on public api
  bool publicAPI = false;

  //allows parsing RAM content and CPU
  bool showHardwareInfo = true;

  //Nahvan requested for a disk space override for computers in shared networks
  bool ignoreDiskSpace = false;

  //HPOOL MODE
  String hpoolConfigPath = "";
  String hpoolAuthToken = "";

  //FOXYPOOL MODE
  String poolPublicKey = "";

  //chiaexplorer cold wallet
  String coldWalletAddress = "";
  bool sendColdWalletBalanceNotifications = true;

  //overrides foxypool mode
  bool foxyPoolOverride = true;

  // '/home/user/.farmr' for package installs, '' (project path) for the rest
  late String _rootPath;
  late io.File _config;

  Config(this._blockchain, this.cache, this._rootPath,
      [isHarvester = false, isHPool = false, isFoxyPoolOG = false]) {
    _config =
        io.File(_rootPath + "config/config${_blockchain.fileExtension}.json");
    //sets default name according to client type
    if (isHPool && _blockchain.currencySymbol == "xch") {
      _type = ClientType.HPool;
      name = "HPool";
    } else if (isFoxyPoolOG &&
        (_blockchain.currencySymbol == "xch" ||
            _blockchain.currencySymbol == "xfx")) {
      _type = ClientType.FoxyPoolOG;
      name = "FoxyPool";
    } else if (isHarvester) {
      _type = ClientType.Harvester;
      name = "Harvester";
    } else {
      _type = ClientType.Farmer;
      name = "Farmer";
    }
  }

  Future<void> init() async {
    //If file doesnt exist then create new config
    if (!_config.existsSync())
      await saveConfig(); //creates config file if doesnt exist
    //If file exists then loads config
    else
      _loadConfig(); //config.json

    //and asks for bin path if path is not defined/not found and is Farmer
    if ((type == ClientType.Farmer || type == ClientType.FoxyPoolOG) &&
        (cache.binPath == '' || !io.File(cache.binPath).existsSync()))
      await _askForBinPath();
  }

  //Creates config file
  Future<void> saveConfig() async {
    Map<String, dynamic> configMap = {
      "Name": name,
      "Currency": currency,
      "Show Farmed ${_blockchain.currencySymbol.toUpperCase()}": showBalance,
      "Show Wallet Balance": showWalletBalance,
      "Show Hardware Info": showHardwareInfo,
      "Block Notifications": sendBalanceNotifications,
      "Plot Notifications": sendPlotNotifications,
      "Hard Drive Notifications": sendDriveNotifications,
      "Offline Notifications": sendOfflineNotifications,
      "Farm Status Notifications": sendStatusNotifications,
      "Parse Logs": parseLogs,
      "Number of Discord Users": userNumber,
      "Public API": publicAPI,
      "Swar's Chia Plot Manager Path": swarPath
    };

    if (type != ClientType.Harvester) {
      configMap.putIfAbsent("Cold Wallet Address", () => coldWalletAddress);
      configMap.putIfAbsent("Send Cold Wallet Balance Notifications",
          () => sendColdWalletBalanceNotifications);
    }

    //hides chiaPath from config.json if not defined (null)
    if (chiaPath != '')
      configMap.putIfAbsent("${_blockchain.binaryName}Path", () => chiaPath);

    //hides ignoreDiskSpace from config.json if false (default)
    if (ignoreDiskSpace)
      configMap.putIfAbsent("Ignore Disk Space", () => ignoreDiskSpace);

    //hpool's config.yaml
    if (type == ClientType.HPool || hpoolConfigPath != "")
      configMap.putIfAbsent("HPool Directory", () => hpoolConfigPath);

    //hpool's cookie
    if (type == ClientType.HPool || hpoolAuthToken != "")
      configMap.putIfAbsent("HPool Auth Token", () => hpoolAuthToken);

    //poolPublicKey used in FoxyPool's chia-og
    if (type == ClientType.FoxyPoolOG || poolPublicKey != "") {
      configMap.putIfAbsent("Pool Public Key", () => poolPublicKey);
      configMap.putIfAbsent("Use FoxyPool API", () => foxyPoolOverride);
    }

    var encoder = new JsonEncoder.withIndent("    ");
    String contents = encoder.convert([configMap]);

    _config.writeAsStringSync(contents);
  }

  Future<void> _askForBinPath() async {
    String exampleDir = (io.Platform.isLinux || io.Platform.isMacOS)
        ? "/home/user/${_blockchain.binaryName}-blockchain"
        : (io.Platform.isWindows)
            ? "C:\\Users\\user\\AppData\\Local\\${_blockchain.binaryName}-blockchain or C:\\Users\\user\\AppData\\Local\\${_blockchain.binaryName}-blockchain\\app-1.0.3\\resources\\app.asar.unpacked"
            : "";

    bool validDirectory = false;

    validDirectory = await _tryDirectories();

    if (validDirectory)
      log.info(
          "Automatically found ${_blockchain.binaryName} binary at: '${cache.binPath}'");
    else
      log.info("Could not automatically locate chia binary.");

    while (!validDirectory) {
      log.warning(
          "Specify your ${_blockchain.binaryName}-blockchain directory below: (e.g.: " +
              exampleDir +
              ")");

      _chiaPath = io.stdin.readLineSync() ?? '';
      log.info("Input chia path: '$_chiaPath'");

      cache.binPath = (io.Platform.isLinux || io.Platform.isMacOS)
          ? _chiaPath + "/venv/bin/${_blockchain.binaryName}"
          : _chiaPath + "\\daemon\\${_blockchain.binaryName}.exe";

      if (io.File(cache.binPath).existsSync())
        validDirectory = true;
      else if (io.Directory(chiaPath).existsSync())
        log.warning("""Could not locate chia binary in your directory.
(${cache.binPath} not found)
Please try again.
Make sure this folder has the same structure as Chia's GitHub repo.""");
      else
        log.warning(
            "Uh oh, that directory could not be found! Please try again.");
    }

    await saveConfig(); //saves path input by user to config
    cache.save(); //saves bin path to cache
  }

  //If in windows, tries a bunch of directories
  Future<bool> _tryDirectories() async {
    bool valid = false;

    late io.Directory chiaRootDir;
    late String file;

    if (io.Platform.isWindows) {
      //Checks if binary exist in C:\User\AppData\Local\chia-blockchain\resources\app.asar.unpacked\daemon\chia.exe
      chiaRootDir = io.Directory(io.Platform.environment['UserProfile']! +
          "/AppData/Local/${_blockchain.binaryName}-blockchain");

      file =
          "/resources/app.asar.unpacked/daemon/${_blockchain.binaryName}.exe";

      if (chiaRootDir.existsSync()) {
        await chiaRootDir.list(recursive: false).forEach((dir) {
          io.File trypath = io.File(dir.path + file);
          if (trypath.existsSync()) {
            cache.binPath = trypath.path;
            valid = true;
          }
        });
      }
    } else if (io.Platform.isLinux || io.Platform.isMacOS) {
      List<String> possiblePaths = [];

      if (io.Platform.isLinux) {
        chiaRootDir =
            io.Directory("/usr/lib/${_blockchain.binaryName}-blockchain");
        file = "/resources/app.asar.unpacked/daemon/${_blockchain.binaryName}";
      } else if (io.Platform.isMacOS) {
        chiaRootDir = io.Directory("/Applications/Chia.app/Contents");
        file = "/Resources/app.asar.unpacked/daemon/${_blockchain.binaryName}";
      }

      possiblePaths = [
        // checks if binary exists in /package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia in linux or
        // checks if binary exists in /Applications/Chia.app/Contents/Resources/app.asar.unpacked/daemon/chia in macOS
        chiaRootDir.path + file,
        // Checks if binary exists in /usr/package:farmr_client/chia-blockchain/resources/app.asar.unpacked/daemon/chia
        "/usr" + chiaRootDir.path + file,
        //checks if binary exists in /home/user/.local/bin/chia
        io.Platform.environment['HOME']! +
            "/.local/bin/${_blockchain.binaryName}"
      ];

      for (int i = 0; i < possiblePaths.length; i++) {
        io.File possibleFile = io.File(possiblePaths[i]);

        if (possibleFile.existsSync()) {
          cache.binPath = possibleFile.path;
          valid = true;
        }
      }
    }

    return valid;
  }

  Future<void> _loadConfig() async {
    var contents;

    try {
      contents = jsonDecode(_config.readAsStringSync());
    } catch (e) {
      //in json you need to use \\ for windows paths and this will ensure every \ is replaced with \\
      contents =
          jsonDecode(_config.readAsStringSync().replaceAll("\\", "\\\\"));
    }

    //leave this here for compatibility with old versions,
    //old versions stored id in config file
    if (contents[0]['id'] != null) _blockchain.id.ids.add(contents[0]['id']);

    //loads custom client name
    if (contents[0]['name'] != null) name = contents[0]['name']; //old
    if (contents[0]['Name'] != null &&
        contents[0]['Name'] != "Farmer" &&
        contents[0]['Name'] != "Harvester" &&
        contents[0]['Name'] != "HPool" &&
        contents[0]['Name'] != "FoxyPool") name = contents[0]['Name']; //new

    //loads custom currency
    if (contents[0]['currency'] != null)
      currency = contents[0]['currency']; //old
    if (contents[0]['Currency'] != null)
      currency = contents[0]['Currency']; //new

    _chiaPath = contents[0]['${_blockchain.binaryName}Path'] ?? "";

    //this used to be in the config file in earlier versions
    //do not remove this
    if (contents[0]['binPath'] != null) cache.binPath = contents[0]['binPath'];

    if (contents[0]['showBalance'] != null)
      showBalance = contents[0]['showBalance']; //old
    if (contents[0]
            ['Show Farmed ${_blockchain.currencySymbol.toUpperCase()}'] !=
        null)
      showBalance = contents[0]
          ['Show Farmed ${_blockchain.currencySymbol.toUpperCase()}']; //new

    if (contents[0]['showWalletBalance'] != null)
      showWalletBalance = contents[0]['showWalletBalance']; //old
    if (contents[0]['Show Wallet Balance'] != null)
      showWalletBalance = contents[0]['Show Wallet Balance']; //new

    if (contents[0]['sendPlotNotifications'] != null)
      sendPlotNotifications = contents[0]['sendPlotNotifications']; //old
    if (contents[0]['Plot Notifications'] != null)
      sendPlotNotifications = contents[0]['Plot Notifications']; //new

    if (contents[0]['sendBalanceNotifications'] != null)
      sendBalanceNotifications = contents[0]['sendBalanceNotifications']; //old
    if (contents[0]['Block Notifications'] != null)
      sendBalanceNotifications = contents[0]['Block Notifications']; //new

    if (contents[0]['sendOfflineNotifications'] != null)
      sendOfflineNotifications = contents[0]['sendOfflineNotifications']; //old
    if (contents[0]['Offline Notifications'] != null)
      sendOfflineNotifications = contents[0]['Offline Notifications']; //new

    if (contents[0]['sendStatusNotifications'] != null)
      sendStatusNotifications = contents[0]['sendStatusNotifications']; //old
    if (contents[0]['Farm Status Notifications'] != null)
      sendStatusNotifications = contents[0]['Farm Status Notifications']; //new

    if (contents[0]['parseLogs'] != null)
      parseLogs = contents[0]['parseLogs']; //old
    if (contents[0]['Parse Logs'] != null)
      parseLogs = contents[0]['Parse Logs']; //new

    if (contents[0]['Number of Discord Users'] != null)
      userNumber = contents[0]['Number of Discord Users'];

    if (contents[0]["Swar's Chia Plot Manager Path"] != null)
      swarPath = contents[0]["Swar's Chia Plot Manager Path"];

    if (contents[0]["Public API"] != null)
      publicAPI = contents[0]["Public API"];

    if (contents[0]["Ignore Disk Space"] != null)
      ignoreDiskSpace = contents[0]["Ignore Disk Space"];

    if (contents[0]['Hard Drive Notifications'] != null)
      sendDriveNotifications = contents[0]['Hard Drive Notifications']; //new

    if (contents[0]['HPool Directory'] != null)
      hpoolConfigPath = contents[0]['HPool Directory']; //new

    if (contents[0]['HPool Auth Token'] != null)
      hpoolAuthToken = contents[0]['HPool Auth Token']; //new

    //loads pool public key used by foxypool mode
    if (contents[0]['Pool Public Key'] != null) {
      poolPublicKey = contents[0]['Pool Public Key'];

      //appends 0x to pool public key if it doesnt start with 0x
      if (poolPublicKey.length == 96 && !poolPublicKey.startsWith("0x"))
        poolPublicKey = "0x" + poolPublicKey;
    }

    if (contents[0]['Use FoxyPool API'] != null)
      foxyPoolOverride = contents[0]['Use FoxyPool API'];

    if (contents[0]["Show Hardware Info"] != null)
      showHardwareInfo = contents[0]["Show Hardware Info"];

    if (contents[0]['Cold Wallet Address'] != null)
      coldWalletAddress = contents[0]['Cold Wallet Address'];

    if (contents[0]['Send Cold Wallet Balance Notifications'] != null)
      sendColdWalletBalanceNotifications =
          contents[0]['Send Cold Wallet Balance Notifications'];

    await saveConfig();
  }
}

//Tells if client is harvester or not
enum ClientType { Farmer, Harvester, HPool, FoxyPoolOG }
