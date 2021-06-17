import 'dart:core';
import 'package:farmr_client/config.dart';
import 'package:farmr_client/debug.dart';
import 'package:universal_io/io.dart' as io;

import 'package:farmr_client/cache.dart';

// hmmm creating a blockchain.dart class with path / file structure classes would be great
// and then replacing any path containing chia with the respective file
// then we could serialize that blockchain class into a blockchain.json file
// and users could customize that
// or download other templates

class BlockChain {
  String binaryName = '';
  String configName = '';
  String currencySymbol = '';
  String configPath = '';
  String logPath = '';

  late Cache cache;
  late Config config;
  late Log log;

  BlockChain(String rootPath, String coinName, List<String> args) {
    // TODO: read file
    this.binaryName = "chia";
    this.configName = "config.json";
    this.currencySymbol = "XCH";

    // Setup
    this.cache = new Cache(rootPath);
    this.configPath = this.getCoinNamePath(coinName, "config");
    this.logPath = this.getCoinNamePath(coinName, "log");
    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(
        this.cache,
        this.configPath,
        rootPath,
        args.contains("harvester"),
        args.contains("hpool"),
        args.contains("foxypoolog"));

    this.log = new Log(this.logPath, this.cache, this.config.parseLogs);
  }

  Future<void> init() async {
    await this.cache.init();
    await this.config.init();
  }

  // Not completely sure what this is for
  Map toJson() => {
        "binaryName": binaryName,
        "configName": configName,
        "currencySymbol": currencySymbol,
      };

  /** Returns configPath & logPath for the coin based on platform */
  String getCoinNamePath(String coinName, String finalFolder) {
    Map configPathMap = {
      //Sets config file path according to platform
      "Unix": io.Platform.environment['HOME'] ??
          '' + "/.${coinName}/mainnet/${finalFolder}",
      "Windows": io.Platform.environment['UserProfile'] ??
          '' + "\\.${coinName}\\mainnet\\${finalFolder}",
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
