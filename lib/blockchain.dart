import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/debug.dart';
import 'package:farmr_client/utils/rpc.dart';
import 'package:universal_io/io.dart' as io;
import 'package:farmr_client/id.dart';

import 'package:farmr_client/cache/cacheIO.dart'
    if (dart.library.js) "package:farmr_client/cache/cacheJS.dart";

class Blockchain {
  List<String> _args = [];
  late ID id;

  OS? _os;

  String _binaryName = '';
  String get binaryName => _binaryName.toLowerCase();

  //nchain uses a different name for some reason
  String get binaryFilename => binaryName != "ext9" ? binaryName : "chia";

  String get allTheBlocksName => (currencySymbol == "vag")
      ? "c_nt"
      : binaryName; //this is how "c*nt" blockchain is named in alltheblocks api

  String _folderName = '';
  String get folderName => _folderName;

  String _currencySymbol = '';
  String get currencySymbol => _currencySymbol.toLowerCase();
  String _minorCurrencySymbol = '';
  String get minorCurrencySymbol => _minorCurrencySymbol.toLowerCase();

  String get fileExtension => "-$currencySymbol";

  String _configPath = '';
  String get configPath => (config != null && config.type == ClientType.HPool)
      ? this.config.hpoolConfigPath
      : (_configPath == '')
          ? this._getPath(this.binaryName, "config")
          : _configPath;
  //if _configath is undefined then it reads log path from _getPath (which depends on platform),
  //if it is defined then _configPath overrides _getPath

  String _logPath = '';
  String get logPath =>
      (_logPath == '') ? this._getPath(this.binaryName, "log") : _logPath;
  //if _logPath is undefined then it reads log path from _getPath,
  //if it is defined then _logPath overrides _getPath

  //wallet path where wallet dbs are stored
  String _walletPath = '';
  String get walletPath => (_walletPath == '')
      ? this._getPath(this.binaryName, "wallet")
      : _walletPath;

  //db path where dbs are stored
  String _dbPath = '';
  String get dbPath =>
      (_dbPath == '') ? this._getPath(this.binaryName, "db") : _dbPath;

  //tsit uses a different net for databases for some reason
  //only affects their .sqlite filename
  String get dbNet => currencySymbol != "tsit" ? net : "testnet";

  String _net = '';
  String get net => _net;

  double _blockRewards = 2.0;
  double get blockRewards => _blockRewards;

  double _blocksPer10Mins = 32.0;
  double get blocksPer10Mins => _blocksPer10Mins;

  bool _onlineConfig = true;
  bool get onlineConfig => _onlineConfig;

  double _majorToMinorMultiplier = 1e12;
  double get majorToMinorMultiplier => _majorToMinorMultiplier;

  bool _checkPlotSize = true; //checks if k32 or smaller
  bool get checkPlotSize => _checkPlotSize;

  late Cache cache;
  late Config config;
  late Log log;

  late final String _rootPath;

  RPCPorts? rpcPorts;
  late final Map<RPCService, bool?> _initialServiceStatus;

  late final ClientType type;
  String get typeName => type.toString().split('.')[1];

  int _reportInterval = 600;
  int get reportInterval => reportInterval;
  Duration get reportIntervalDuration => Duration(seconds: _reportInterval);

  int _logParseInterval = 5;
  int get logParseInterval => reportInterval;
  Duration get logParsingIntervalDuration =>
      Duration(seconds: _logParseInterval);

  Blockchain(this.id, this._rootPath, this._args, [dynamic json]) {
    _fromJson(json); //loads properties from serialized blokchain

    //doesnt load online config if standalone argument is provided
    if (_args.contains("standalone") ||
        //online configuration is incompatible with hpool mode
        (_args.contains("hpool") && currencySymbol == "xch"))
      _onlineConfig = false;

    _os = detectOS();
  }

  //this is used on server side
  //since blockchain objects cant be initialized as null
  Blockchain.fromSymbol(String currencySymbol,
      {String binaryName = '', double majorToMinorMultiplier = 1e12}) {
    _currencySymbol = currencySymbol;
    _binaryName = binaryName;
    _majorToMinorMultiplier = majorToMinorMultiplier;

    _fromJson(null);
  }

  Blockchain.fromJson(dynamic json) {
    _fromJson(json);
  }

  _fromJson(dynamic json) {
    if (json != null) {
      //loads blockchain file from json file if that object is defined
      //defaults to chia config
      _binaryName = json['Binary Name'] ?? 'chia';
      _folderName = json['Folder Name'] ?? '.$binaryName';
      _currencySymbol = json['Currency Symbol'] ?? 'xch';
      _minorCurrencySymbol = json['Minor Currency Symbol'] ?? 'mojo';
      _net = json['Net'] ?? 'mainnet';
      _logPath = json['Log Path'] ?? '';
      _configPath = json['Config Path'] ?? '';
      _blockRewards = json['Block Rewards'] ?? 2.0;
      _blocksPer10Mins = json['Blocks Per 10 Minutes'] ?? 32.0;
      _onlineConfig = json['Online Config'] ?? true;
      _majorToMinorMultiplier = json['Major to Minor Multiplier'] ?? 1e12;
      _checkPlotSize = json['Check for Complete Plots'] ?? true;
      _reportInterval = json['Report Interval'] ?? 600;
      _logParseInterval = json['Log Parse Interval'] ?? 5;
    }

    //sets limits of report interval
    if (_reportInterval < 60) _reportInterval = 60;
    if (_reportInterval > 1800) _reportInterval = 1800;

    //initializes default rpc ports for xch
    if (currencySymbol == "xch") {
      const defaultMap = const {
        "harvester": 8560,
        "farmer": 8559,
        "fullNode": 8555,
        "wallet": 9256,
        "daemon": 55400
      };
      rpcPorts = RPCPorts.fromJson(defaultMap);
    }
    //overwrites default ports with ports from config
    if (json != null && json['Ports'] != null) {
      rpcPorts = RPCPorts.fromJson(json['Ports']);
    }
  }

  static OS? detectOS() {
    OS? os;
    if (io.File(".github/workflows/config.yaml").existsSync())
      os = OS.GitHub;
    else if (io.Platform.isLinux)
      os = OS.Linux;
    else if (io.Platform.isMacOS)
      os = OS.MacOS;
    else if (io.Platform.isWindows)
      os = OS.Windows;
    else
      throw Exception("This OS is not supported!");

    return os;
  }

  Future<void> initializePorts() async {
    //DEBUG PURPOSES
    //await rpcPorts?.printStatus();
    //io.stdin.readByteSync();

    //initializes map with list of RPC services and if they are running or not
    _initialServiceStatus =
        await rpcPorts?.isServiceRunning(RPCService.values) ?? {};

    final bool? harvesterRunning = _initialServiceStatus[RPCService.Harvester];
    final bool? farmerRunning = _initialServiceStatus[RPCService.Farmer];

    //hpool argument overrides type
    if (_args.contains("hpool") && currencySymbol == "xch")
      type = ClientType.HPool;
    //harvester agument overrides type
    else if (_args.contains("harvester"))
      type = ClientType.Harvester;
    //in case RPC Ports are not defined or there was an exception
    //chooses type based on arguments
    else if (harvesterRunning == null && farmerRunning == null)
      type = ClientType.Farmer;
    //chooses farmer if farmer service is running
    else if (farmerRunning != null && farmerRunning)
      type = ClientType.Farmer;
    //chooses harvester if harvester service is running
    else if (harvesterRunning != null && harvesterRunning)
      type = ClientType.Harvester;
    else {
      //throws exception if blockchain is not running
      String exception =
          "Unable to detect running $binaryName farming/harvesting service.";
      print(exception);

      await Future.delayed(Duration(seconds: 10));

      throw Exception(exception);
    }

    print("Starting farmr for $binaryName in $typeName mode...");
    //io.stdin.readByteSync(); //DEBUGGING, comment
  }

  Future<void> init(bool firstInit) async {
    // Setup
    this.cache = new Cache(this, _rootPath, firstInit);

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(this, this.cache, _rootPath, type);

    await this.cache.init();
    cache.binPath; //forces asking for binPath

    await this.config.init(this.onlineConfig,
        this._args.contains("headless") || this._args.contains("hpool"));

    this.log = new Log(
        this.logPath,
        this.cache,
        this.config.parseLogs,
        this.binaryName,
        this.config.type,
        configPath,
        firstInit,
        this.logParsingIntervalDuration);
  }

  /** Returns configPath & logPath for the coin based on platform */
  String _getPath(String binaryName, String finalFolder) {
    Map<OS, String> configPathMap = {
      //Sets config file path according to platform
      OS.Linux:
          "${io.Platform.environment['HOME']}/$folderName/$net/$finalFolder",
      OS.MacOS:
          "${io.Platform.environment['HOME']}/$folderName/$net/$finalFolder",
      OS.Windows:
          "${io.Platform.environment['UserProfile']}\\$folderName\\$net\\$finalFolder",
      //test mode for github releases
      OS.GitHub: ".github/workflows",
    };
    // TODO: Potentially leverage String os = io.Platform.operatingSystem;

    return configPathMap[_os]!;
  }
}

//github is reserved to github actions
enum OS { Linux, MacOS, Windows, GitHub }
