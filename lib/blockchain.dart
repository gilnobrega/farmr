import 'dart:core';

// hmmm creating a blockchain.dart class with path / file structure classes would be great
// and then replacing any path containing chia with the respective file
// then we could serialize that blockchain class into a blockchain.json file
// and users could customize that
// or download other templates

class BlockChain {
  String binaryPath = '';
  String configPath = '';
  String currencySymbol = '';

  BlockChain(this.binaryPath, this.configPath, this.currencySymbol);

  Map toJson() => {
        "binaryPath": binaryPath,
        "configPath": configPath,
        "currencySymbol": currencySymbol,
      };

  // void test() {
  //   this.currencySymbol = "XCHHH";
  // }
}

// Map toJson() => {
//   "Name": "Harvester",
//   "Currency": "USD",
//   "Show Farmed XCH": true,
//   "Show Wallet Balance": false,
//   "Block Notifications": true,
//   "Plot Notifications": false,
//   "Offline Notifications": false,
//   "Farm Status Notifications": true,
//   "Parse Logs": false,
//   "Number of Discord Users": 1,
//   "Public API": false,
//   "Swar's Chia Plot Manager Path": ""
//   "ids": ids,
//   "binPath": binPath,
//   "plots": plots,
//   "filters": filters,
//   "signagePoints": signagePoints,
//   "shortSyncs": shortSyncs,
//   "memories": memories,
// };