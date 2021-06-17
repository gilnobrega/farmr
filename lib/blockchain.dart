import 'dart:core';

// hmmm creating a blockchain.dart class with path / file structure classes would be great
// and then replacing any path containing chia with the respective file
// then we could serialize that blockchain class into a blockchain.json file
// and users could customize that
// or download other templates

class BlockChain {
  String binaryName = '';
  String configName = '';
  String currencySymbol = '';

  BlockChain(this.binaryName, this.configName, this.currencySymbol);

  Map toJson() => {
        "binaryName": binaryName,
        "configName": configName,
        "currencySymbol": currencySymbol,
      };
}
