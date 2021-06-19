import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/debug.dart';
import 'package:universal_io/io.dart' as io;

import 'package:farmr_client/cache.dart';

class Blockchain {
  OS? _os;

  String _binaryName = '';
  String get binaryName => _binaryName.toLowerCase();

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

  late Cache cache;
  late Config config;
  late Log log;

  Blockchain(String rootPath, List<String> args, [dynamic json = null]) {
    //loads blockchain file from json file if that object is defined
    if (json != null) {
      //defaults to chia config
      _binaryName = json['Binary Name'] ?? 'chia';
      _currencySymbol = json['Currency Symbol'] ?? 'xch';
      _minorCurrencySymbol = json['Minor Currency Symbol'] ?? 'mojo';
      _net = json['Net'] ?? 'mainnet';
      _logPath = json['Log Path'] ?? '';
      _configPath = json['Config Path'] ?? '';
    }

    _os = detectOS();

    if (_os == null) throw Exception("This OS is not supported!");

    // Setup
    this.cache = new Cache(this, rootPath);

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(
        this,
        this.cache,
        rootPath,
        args.contains("harvester"),
        args.contains("hpool"),
        args.contains("foxypoolog"));
  }

  static OS? detectOS() {
    OS? os;
    if (io.File(".github/workflows/config.yaml").existsSync())
      os = OS.GitHub;
    else if (io.Platform.isLinux)
      os = OS.Linux;
    else if (io.Platform.isMacOS)
      os = OS.MacOS;
    else if (io.Platform.isWindows) os = OS.Windows;

    return os;
  }

  Future<void> init() async {
    await this.cache.init();
    await this.config.init();

    this.log = new Log(
        this.logPath, this.cache, this.config.parseLogs, this.binaryName);
  }

  /** Returns configPath & logPath for the coin based on platform */
  String _getPath(String binaryName, String finalFolder) {
    Map<OS, String> configPathMap = {
      //Sets config file path according to platform
      OS.Linux:
          "${io.Platform.environment['HOME']}/.${binaryName}/${net}/${finalFolder}",
      OS.MacOS:
          "${io.Platform.environment['HOME']}/.${binaryName}/${net}/${finalFolder}",
      OS.Windows:
          "${io.Platform.environment['UserProfile']}\\.${binaryName}\\${net}\\${finalFolder}",
      //test mode for github releases
      OS.GitHub: ".github/workflows",
    };
    // TODO: Potentially leverage String os = io.Platform.operatingSystem;

    return configPathMap[_os]!;
  }
}

//github is reserved to github actions
enum OS { Linux, MacOS, Windows, GitHub }
