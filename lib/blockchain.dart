import 'dart:core';
import 'package:farmr_client/config.dart';
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

  late Cache cache;
  late Config config;

  BlockChain(String rootPath, String coinName, List<String> args) {
    // TODO: read file
    this.binaryName = "chia";
    this.configName = "config.json";
    this.currencySymbol = "XCH";

    // Setup
    this.cache = new Cache(rootPath);

    Map configPath = {
      "Unix": io.Platform.environment['HOME'] ??
          '' + "/.${coinName}/mainnet/config",
      "Windows": io.Platform.environment['UserProfile'] ??
          '' + "\\.${coinName}\\mainnet\\config",
      "GitHub": ".github/workflows",
    };

    // TODO: Potentially leverage String os = io.Platform.operatingSystem;
    var os = "";
    if (io.Platform.isLinux || io.Platform.isMacOS) os = "Unix";
    if (io.Platform.isWindows) os = "Windows";
    if (io.File(".github/workflows/config.yaml").existsSync()) os = "GitHub";

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(
        this.cache,
        configPath[os],
        rootPath,
        args.contains("harvester"),
        args.contains("hpool"),
        args.contains("foxypoolog"));
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
}
