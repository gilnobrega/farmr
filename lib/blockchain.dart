import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/debug.dart';
import 'package:universal_io/io.dart' as io;

import 'package:farmr_client/cache.dart';

class Blockchain {
  OS? _os;

  String binaryName = '';
  String configName = '';

  String currencySymbol = '';
  String minorCurrencySymbol = '';

  String configPath = '';
  String logPath = '';

  String net = '';

  late Cache cache;
  late Config config;
  late Log log;

  Blockchain(String configToProcess, String rootPath, List<String> args) {
    _os = detectOS();

    if (_os == null) throw Exception("This OS is not supported!");

    // TODO: read file via configToProcess
    // ALSO TODO: log path map
    this.binaryName = "chia";
    this.configName = "config.json";
    this.currencySymbol = "XCH";
    this.minorCurrencySymbol = "mojo";
    this.net = 'mainnet';

    // Setup
    this.cache = new Cache(rootPath);
    this.logPath = this._getPath(this.binaryName, "log");

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(
        this,
        this.cache,
        rootPath,
        args.contains("harvester"),
        args.contains("hpool"),
        args.contains("foxypoolog"));

    // TODO: Clean this up further
    this.configPath = (this.config.type == ClientType.HPool)
        ? this.config.hpoolConfigPath
        : this._getPath(this.binaryName, "config");
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
