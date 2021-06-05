import 'dart:convert';

import 'package:chiabot/config.dart';
import 'package:chiabot/farmer/wallet.dart';
import 'package:chiabot/harvester.dart';
import 'package:chiabot/farmer.dart';
import 'package:chiabot/debug.dart' as Debug;
import 'package:chiabot/hpool/api.dart';
import 'package:chiabot/hpool/wallet.dart';

class HPool extends Farmer {
  String _authToken = '';

  @override
  String get status => "HPool";

  double _balance = -1.0;
  @override
  double get balance => _balance; //hides balance

  HPoolWallet _wallet = HPoolWallet(-1.0, -1.0);
  @override
  Wallet get wallet => _wallet;

  @override
  final ClientType type = ClientType.HPool;

  HPool({required Config config, required Debug.Log log, String version = ''})
      : super(config: config, log: log, version: version, hpool: true) {
    _authToken = config.hpoolAuthToken;
  }

  HPool.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    if (object['balance'] != null) _balance = object['balance'];

    if (object['walletBalance'] != null &&
        object['undistributedBalance'] != null)
      _wallet =
          HPoolWallet(object['walletBalance'], object['undistributedBalance']);
  }

  @override
  Map toJson() {
    Map farmerMap = (super.toJson());

    farmerMap.update("balance", (value) => _balance);
    farmerMap.update("walletBalance", (value) => _wallet.balance);

    farmerMap.addEntries({
      'undistributedBalance': _wallet.undistributedBalance, //wallet balance
    }.entries);

    return farmerMap;
  }

  //Adds harvester's plots into farm's plots
  @override
  void addHarvester(Harvester harvester) {
    allPlots.addAll(harvester.allPlots);

    if (harvester.totalDiskSpace == 0 || harvester.freeDiskSpace == 0)
      supportDiskSpace = false;

    //Adds harvester total and free disk space when merging
    totalDiskSpace += harvester.totalDiskSpace;
    freeDiskSpace += harvester.freeDiskSpace;
    drivesCount += harvester.drivesCount;

    //Disables avg, median, etc. in !chia full
    this.disableDetailedTimeStats();

    //adds swar pm jobs
    swarPM.jobs.addAll(harvester.swarPM.jobs);
  }

  @override
  Future<void> init(String chiaConfigPath) async {
    //tries to parse hpool api
    HPoolApi api = HPoolApi();
    await api.init(_authToken);

    _balance = api.poolIncome; //farmed balance
    //wallet balance and unsettled income
    _wallet = HPoolWallet(api.balance, api.undistributedIncome);

    await super.init(chiaConfigPath);
  }
}
