import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/debug.dart';
import 'package:universal_io/io.dart' as io;

import 'package:farmr_client/cache.dart';

class Blockchain {
  String binaryName = '';
  String configName = '';
  String currencySymbol = '';
  String minorCurrencySymbol = '';
  String configPath = '';
  String logPath = '';

  late Cache cache;
  late Config config;
  late Log log;

  Blockchain(String configToProcess, String rootPath, List<String> args) {
    // TODO: read file via configToProcess
    this.binaryName = "chia";
    this.configName = "config.json";
    this.currencySymbol = "XCH";
    this.minorCurrencySymbol = "mojo";

    // Setup
    this.cache = new Cache(rootPath);
    this.logPath = this.getMainnetPath(this.binaryName, "log");

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(this.cache, rootPath, args.contains("harvester"),
        args.contains("hpool"), args.contains("foxypoolog"));
    this.log = new Log(
        this.logPath, this.cache, this.config.parseLogs, this.binaryName);

    // TODO: Clean this up further
    this.configPath = (this.config.type == ClientType.HPool)
        ? this.config.hpoolConfigPath
        : this.getMainnetPath(this.binaryName, "config");
  }

  Future<void> init() async {
    await this.cache.init();
    await this.config.init();
  }

  /** Returns configPath & logPath for the coin based on platform */
  String getMainnetPath(String binaryName, String finalFolder) {
    // TODO: Enum?
    Map configPathMap = {
      //Sets config file path according to platform
      "Unix": io.Platform.environment['HOME']! +
          "/.${binaryName}/mainnet/${finalFolder}",
      // FIXME: How to fix the null issue?
      // "Windows": io.Platform.environment['UserProfile']! +
      //     "\\.${coinName}\\mainnet\\${finalFolder}",
      //test mode for github releases
      "GitHub": ".github/workflows",
    };
    // TODO: Potentially leverage String os = io.Platform.operatingSystem;
    var os = "";
    if (io.Platform.isLinux || io.Platform.isMacOS) os = "Unix";
    if (io.Platform.isWindows) os = "Windows";
    if (io.File(".github/workflows/config.yaml").existsSync()) os = "GitHub";

    return configPathMap[os];
  }
}
