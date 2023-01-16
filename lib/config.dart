import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/cache/cacheIO.dart'
    if (dart.library.js) "package:farmr_client/cache/cacheJS.dart";

import 'package:http/http.dart' as http;

final log = Logger('Config');

//Tells if client is harvester or not
enum ClientType { Farmer, Harvester, HPool }

class Config {
  Cache? cache;

  late Blockchain _blockchain;

  ClientType _type = ClientType.Harvester;
  ClientType get type => _type;

  //Optional, custom, user defined name
  String name = '';

  //Optional, custom 3 letter currency
  String currency = 'USD';

  //farmed balance
  bool showBalance = true;

  //wallet balance
  bool showWalletBalance = true;

  bool sendPlotNotifications = false; //plot notifications

  bool sendDriveNotifications = false; //drive notifications

  bool sendBalanceNotifications = true; //balance notifications

  bool sendColdWalletNotifications = true; //cold wallet notifications

  bool sendOfflineNotifications = true; //status notifications

  bool sendStatusNotifications = true; //status notifications

  bool parseLogs = true;

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

  List<String> coldWalletAddresses = [];
  List<String> foxyPoolPublicKeys = [];
  List<String> plottersClubPublicKeys = [];
  List<String> spacePoolPublicKeys = [];
  List<String> xchGardenPublicKeys = [];
  List<String> flexpoolAddresses = [];
  List<String> elysiumPoolLauncherIDs = [];

  //overrides foxypool mode
  bool foxyPoolOverride = true;

  // '/home/user/.farmr' for package installs, '' (project path) for the rest
  late String _rootPath;
  late io.File _config;

  Config(
    this._blockchain,
    this.cache,
    this._rootPath,
    this._type,
  ) {
    _config =
        io.File(_rootPath + "config/config${_blockchain.fileExtension}.json");

    //sets default name according to client type
    name = defaultNames[type] ?? "Harvester";
  }

  static const Map<ClientType, String> defaultNames = {
    ClientType.HPool: "HPool",
    ClientType.Harvester: "Harvester",
    ClientType.Farmer: "Farmer",
  };

  Future<void> init(bool onlineConfig, bool headless) async {
    if (onlineConfig)
      await loadOnlineConfig();
    else {
      //If file doesnt exist then create new config
      if (!_config.existsSync())
        await saveConfig(); //creates config file if doesnt exist
      //If file exists then loads config
      else
        _loadConfig(); //config.json
    }

    //and asks for bin path if path is not defined/not found and it is not in headless mode
    //(means user input works)
/*     if (!headless &&
        (cache!.binPath == '' || !io.File(cache!.binPath).existsSync()))
      await _askForBinPath(); */
    //DEPRECATED -> AUTOMATICALLY ASKS FOR BIN PATH IF RREQUESTED
  }

  Future<void> loadOnlineConfig() async {
    try {
      String url = "http://farmr2.net/login.php?action=readconfig&id=" +
          _blockchain.id.ids.first +
          _blockchain.fileExtension;

      final String contents = (await http.read(Uri.parse(url))).trim();

      try {
        loadfromJson(jsonDecode(contents));
      } catch (error) {
        log.warning("Failed to decode online config");
      }
    } catch (error) {
      log.info("Failed to read online config");
    }
  }

  Map<String, dynamic> genConfigMap() {
    Map<String, dynamic> configMap = {
      "Name": name,
      "Currency": currency,
      "Show Farmed ${_blockchain.currencySymbol.toUpperCase()}": showBalance,
      "Show Wallet Balance": showWalletBalance,
      "Show Hardware Info": showHardwareInfo,
      "Block Notifications": sendBalanceNotifications,
      "Cold Wallet Notifications": sendColdWalletNotifications,
      "Plot Notifications": sendPlotNotifications,
      "Hard Drive Notifications": sendDriveNotifications,
      "Offline Notifications": sendOfflineNotifications,
      "Farm Status Notifications": sendStatusNotifications,
      "Parse Logs": parseLogs,
      "Number of Discord Users": userNumber,
      "Public API": publicAPI,
      "Swar's Chia Plot Manager Path": swarPath,
      "Cold Wallet Addresses": coldWalletAddresses,
    };

    if (_blockchain.currencySymbol == "xch") {
      configMap.putIfAbsent(
          "Elysium Pool Launcher IDs", () => elysiumPoolLauncherIDs);
      configMap.putIfAbsent(
          "Plotters.Club Public Keys", () => plottersClubPublicKeys);
      configMap.putIfAbsent("SpacePool Public Keys", () => spacePoolPublicKeys);
      configMap.putIfAbsent(
          "XCH Garden Public Keys", () => xchGardenPublicKeys);
    }

    if (_blockchain.currencySymbol == "xch" ||
        _blockchain.currencySymbol == "xfx")
      configMap.putIfAbsent("FoxyPool Public Keys", () => foxyPoolPublicKeys);

    if (_blockchain.currencySymbol == "xch")
      configMap.putIfAbsent("Flexpool Addresses", () => flexpoolAddresses);

    //hides ignoreDiskSpace from config.json if false (default)
    if (ignoreDiskSpace)
      configMap.putIfAbsent("Ignore Disk Space", () => ignoreDiskSpace);

    //hpool's config.yaml
    if (type == ClientType.HPool || hpoolConfigPath != "")
      configMap.putIfAbsent("HPool Directory", () => hpoolConfigPath);

    //hpool's cookie
    if (type == ClientType.HPool || hpoolAuthToken != "")
      configMap.putIfAbsent("HPool Auth Token", () => hpoolAuthToken);

    return configMap;
  }

  //Creates config file
  Future<void> saveConfig() async {
    var encoder = new JsonEncoder.withIndent("    ");
    String contents = encoder.convert([genConfigMap()]);

    _config.writeAsStringSync(contents);
  }

  Config.fromJson(dynamic json, Blockchain blockchain, ClientType type) {
    _type = type;
    _blockchain = blockchain;

    loadfromJson(json);
  }

  loadfromJson(dynamic json) {
    //sets default name according to client type
    name = defaultNames[type] ?? "Harvester";

    //leave this here for compatibility with old versions,
    //old versions stored id in config file
    if (json['id'] != null) _blockchain.id.ids.add(json['id']);

    //loads custom client name
    if (json['name'] != null) name = json['name']; //old
    if (json['Name'] != null && !defaultNames.values.contains(json['Name']))
      name = json['Name']; //new

    //loads custom currency
    if (json['currency'] != null) currency = json['currency']; //old
    if (json['Currency'] != null) currency = json['Currency']; //new

    if (json['showBalance'] != null) showBalance = json['showBalance']; //old
    if (json['Show Farmed ${_blockchain.currencySymbol.toUpperCase()}'] != null)
      showBalance =
          json['Show Farmed ${_blockchain.currencySymbol.toUpperCase()}']; //new

    if (json['showWalletBalance'] != null)
      showWalletBalance = json['showWalletBalance']; //old
    if (json['Show Wallet Balance'] != null)
      showWalletBalance = json['Show Wallet Balance']; //new

    if (json['sendPlotNotifications'] != null)
      sendPlotNotifications = json['sendPlotNotifications']; //old
    if (json['Plot Notifications'] != null)
      sendPlotNotifications = json['Plot Notifications']; //new

    if (json['sendBalanceNotifications'] != null)
      sendBalanceNotifications = json['sendBalanceNotifications']; //old
    if (json['Block Notifications'] != null)
      sendBalanceNotifications = json['Block Notifications']; //new

    if (json['Cold Wallet Notifications'] != null)
      sendColdWalletNotifications = json['Cold Wallet Notifications'];

    if (json['sendOfflineNotifications'] != null)
      sendOfflineNotifications = json['sendOfflineNotifications']; //old
    if (json['Offline Notifications'] != null)
      sendOfflineNotifications = json['Offline Notifications']; //new

    if (json['sendStatusNotifications'] != null)
      sendStatusNotifications = json['sendStatusNotifications']; //old
    if (json['Farm Status Notifications'] != null)
      sendStatusNotifications = json['Farm Status Notifications']; //new

    if (json['parseLogs'] != null) parseLogs = json['parseLogs']; //old
    if (json['Parse Logs'] != null) parseLogs = json['Parse Logs']; //new

    if (json['Number of Discord Users'] != null)
      userNumber = json['Number of Discord Users'];

    if (json["Swar's Chia Plot Manager Path"] != null)
      swarPath = json["Swar's Chia Plot Manager Path"];

    if (json["Public API"] != null) publicAPI = json["Public API"];

    if (json["Ignore Disk Space"] != null)
      ignoreDiskSpace = json["Ignore Disk Space"];

    if (json['Hard Drive Notifications'] != null)
      sendDriveNotifications = json['Hard Drive Notifications']; //new

    if (json['HPool Directory'] != null)
      hpoolConfigPath = json['HPool Directory']; //new

    if (json['HPool Auth Token'] != null)
      hpoolAuthToken = json['HPool Auth Token']; //new

    //loads pool public key used by foxypool mode LEGACY
    if (json['Pool Public Key'] != null) {
      String poolPublicKey = json['Pool Public Key'];

      //appends 0x to pool public key if it doesnt start with 0x
      if (poolPublicKey.length == 96 && !poolPublicKey.startsWith("0x"))
        poolPublicKey = "0x" + poolPublicKey;

      foxyPoolPublicKeys.add(poolPublicKey);
    }

    if (json['Use FoxyPool API'] != null)
      foxyPoolOverride = json['Use FoxyPool API'];

    //loads flexpool address used by flexpool mode LEGACY
    if (json['Flexpool Address'] != null)
      flexpoolAddresses.add(json['Flexpool Address']);

    if (json["Show Hardware Info"] != null)
      showHardwareInfo = json["Show Hardware Info"];

    if (json['Cold Wallet Address'] != null) {
      var addresses = (json['Cold Wallet Address'] as String);
      if (addresses.contains(','))
        coldWalletAddresses.addAll(addresses.split(','));
      else
        coldWalletAddresses.add(addresses);
    }

    if (json['Cold Wallet Addresses'] != null) {
      for (var address in json['Cold Wallet Addresses'])
        coldWalletAddresses.add(address);
      //clears duplicate entries
      coldWalletAddresses = coldWalletAddresses.toSet().toList();
    }

    if (json['Flexpool Addresses'] != null) {
      for (var address in json['Flexpool Addresses'])
        flexpoolAddresses.add(address);
      //clears duplicate entries
      flexpoolAddresses = flexpoolAddresses.toSet().toList();
    }

    if (json['FoxyPool Public Keys'] != null) {
      for (var address in json['FoxyPool Public Keys'])
        foxyPoolPublicKeys.add(address);
//clears duplicate entries
      foxyPoolPublicKeys = foxyPoolPublicKeys.toSet().toList();
    }

    if (json['Plotters.Club Public Keys'] != null) {
      for (var address in json['Plotters.Club Public Keys'])
        plottersClubPublicKeys.add(address);
//clears duplicate entries
      plottersClubPublicKeys = plottersClubPublicKeys.toSet().toList();
    }

    if (json['SpacePool Public Keys'] != null) {
      for (var address in json['SpacePool Public Keys'])
        spacePoolPublicKeys.add(address);
//clears duplicate entries
      spacePoolPublicKeys = spacePoolPublicKeys.toSet().toList();
    }

    if (json["XCH Garden Public Keys"] != null) {
      for (var address in json["XCH Garden Public Keys"])
        xchGardenPublicKeys.add(address);
//clears duplicate entries
      xchGardenPublicKeys = xchGardenPublicKeys.toSet().toList();
    }

    if (json["Elysium Pool Launcher IDs"] != null) {
      for (var launcherID in json["Elysium Pool Launcher IDs"]) {
        elysiumPoolLauncherIDs.add(launcherID);
        //clears duplicate launcher ids
        elysiumPoolLauncherIDs = elysiumPoolLauncherIDs.toSet().toList();
      }
    }
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

    loadfromJson(contents[0]);
    _blockchain.cache.chiaPath =
        contents[0]['${_blockchain.binaryName}Path'] ?? "";

    await saveConfig();
  }
}
