import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/debug.dart';
import 'package:farmr_client/rpc.dart';
import 'package:universal_io/io.dart' as io;
import 'package:farmr_client/id.dart';

import 'package:farmr_client/cache.dart';

class Blockchain {
  List<String> _args = [];
  late ID id;

  OS? _os;

  String _binaryName = '';
  String get binaryName => _binaryName.toLowerCase();

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

  late Cache cache;
  late Config config;
  late Log log;

  RPCPorts? rpcPorts;

  Blockchain(this.id, String rootPath, this._args, [dynamic json = null]) {
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
    if (json['Ports'] != null) {
      rpcPorts = RPCPorts.fromJson(json['Ports']);
    }

    //doesnt load online config if standalone argument is provided
    if (_args.contains("standalone") ||
        //online configuration is incompatible with hpool mode
        (_args.contains("hpool") && currencySymbol == "xch"))
      _onlineConfig = false;

    _os = detectOS();

    // Setup
    this.cache = new Cache(this, rootPath);

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(
        this,
        this.cache,
        rootPath,
        _args.contains("harvester"),
        _args.contains("hpool"),
        _args.contains("foxypoolog"),
        _args.contains("flexpool"));
  }

  //this is used on server side
  //since blockchain objects cant be initialized as null
  Blockchain.fromSymbol(this._currencySymbol,
      {String binaryName = '', double majorToMinorMultiplier = 1e12}) {
    _binaryName = binaryName;
    _majorToMinorMultiplier = majorToMinorMultiplier;
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

  Future<void> init() async {
    await this.cache.init();
    await this.config.init(this.onlineConfig,
        this._args.contains("headless") || this._args.contains("hpool"));

    //TODO: find a way to not have to run this logUpdate command twice (in blockchain.init and every 10 minutes)
    logUpdate();
  }

  //reparses log and adds new filters/shortsyncs/signagepoints
  void logUpdate() {
    this.log = new Log(this.logPath, this.cache, this.config.parseLogs,
        this.binaryName, this.config.type, configPath);
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
