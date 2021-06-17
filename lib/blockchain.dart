import 'dart:core';
import 'package:universal_io/io.dart' as io;
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/log/filter.dart';
import 'package:farmr_client/log/signagepoint.dart';
import 'package:farmr_client/log/shortsync.dart';

import 'package:farmr_client/hardware.dart';


// hmmm creating a blockchain.dart class with path / file structure classes would be great
// and then replacing any path containing chia with the respective file
// then we could serialize that blockchain class into a blockchain.json file
// and users could customize that
// or download other templates

class BlockChain {
  String binaryPath = '';
  String configPath = '';
  String currencySymbol = '';
  
  BlockChain(this.binaryPath, this.configPath, this.currencySymbol)

    // Map toJson() => {
    //   binaryPath,
    //   configPath
    //   currencySymbol,
    // };
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