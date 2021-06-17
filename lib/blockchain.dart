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

    // TODO: Dynamic
    String chiaConfigPath =
        (io.File(".github/workflows/config.yaml").existsSync())
            ? ".github/workflows"
            //Sets config file path according to platform
            : (io.Platform.isLinux || io.Platform.isMacOS)
                ? io.Platform.environment['HOME']! + "/.chia/mainnet/config"
                : (io.Platform.isWindows)
                    ? io.Platform.environment['UserProfile']! +
                        "\\.chia\\mainnet\\config"
                    : "";

    /** Initializes config, either creates a new one or loads a config file */
    this.config = new Config(
        this.cache,
        chiaConfigPath,
        rootPath,
        args.contains("harvester"),
        args.contains("hpool"),
        args.contains("foxypoolog"));
  }

  Future<void> init() async {
    this.cache.init();
    await this.config.init();
  }

  // Not completely sure what this is for
  Map toJson() => {
        "binaryName": binaryName,
        "configName": configName,
        "currencySymbol": currencySymbol,
      };
}
