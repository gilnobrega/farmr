import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/harvester/status.dart';
import 'package:farmr_client/rpc.dart';
import 'package:farmr_client/server/netspace.dart';
import 'package:logging/logging.dart';
import 'package:universal_io/io.dart' as io;

enum FarmerStatus {
  Farming,
  Syncing,
  Not_Synced,
  Not_Available,
  Not_Running,
  Not_Farming
}

final log = Logger('Farmer Status');

//class that contains everything related to ``chia farm summary`` command
class FarmerStatusMixin {
  FarmerStatus farmerStatus = FarmerStatus.Not_Available;
  String get farmerStatusString =>
      farmerStatus.toString().split('.')[1].replaceAll("_", " ");

  //Farmed balance
  double _farmedBalance = -1.0;
  double get farmedBalance => _farmedBalance;
  double get balance => _farmedBalance; //hides balance if string

  NetSpace _netSpace = NetSpace("1 B");
  NetSpace get netSpace => _netSpace;

  int lastBlockFarmed = 0;

  statusFromJson(dynamic object) {
    _farmedBalance = double.parse(object['balance']?.toString() ?? "-1");

    //reads netspace from json
    if (object['netSpace'] != null) {
      _netSpace =
          NetSpace.fromBytes(double.parse(object['netSpace'].toString()));
    }
  }

  Future<void> updateFarmerStatus(Blockchain blockchain) async {
    //check if farmer service is running
    final servicesRunning = (await blockchain.rpcPorts
            ?.isServiceRunning([RPCService.Farmer, RPCService.Daemon]) ??
        {}); //defaults to true if RPC Port is not defined

    final bool daemonRunning = servicesRunning[RPCService.Daemon] ?? true;
    final bool? farmerRunning = servicesRunning[RPCService.Farmer];

    //null value means RPC Port is not defined
    //In this case it tries legacy mode
    if (farmerRunning == null)
      _legacyFarmerStatus(blockchain);
    //Try RPC
    else if (farmerRunning) {
      var result = {};

      try {
        RPCConfiguration configuration = RPCConfiguration(
            blockchain: blockchain,
            service: RPCService.Full_Node,
            endpoint: "get_blockchain_state");

        result = await RPCConnection.getEndpoint(configuration);
      } catch (e) {
        log.warning("RPC erorr: get_blockchain_state failed");
        log.info(e.toString());
      }

      if (result['sync'] != null) {
        if (result['sync']['sync_mode'] ?? false)
          farmerStatus = FarmerStatus.Syncing;
        else if (!(result['sync']['synced'] ?? true))
          farmerStatus = FarmerStatus.Not_Synced;
        //checks if there were signage points in the last 10 minutes
        else if (HarvesterStatusMixin.harvestingStatus(
            blockchain.config.parseLogs, blockchain.cache.signagePoints))
          farmerStatus = FarmerStatus.Farming;
        else
          farmerStatus = FarmerStatus.Not_Farming;
      }
    } else if (daemonRunning)
      farmerStatus = FarmerStatus.Not_Available;
    else
      farmerStatus = FarmerStatus.Not_Running;
  }

  void _legacyFarmerStatus(Blockchain blockchain) {
    //runs chia farm summary if it is a farmer
    var result = io.Process.runSync(
        blockchain.config.cache!.binPath, const ["farm", "summary"]);
    List<String> lines =
        result.stdout.toString().replaceAll("\r", "").split('\n');

    //needs last farmed block to calculate effort, this is never stored
    try {
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];

        if (line.startsWith("Farming status: ")) {
          final String cliStatus =
              line.split("Farming status: ")[1].toLowerCase();

          if (cliStatus.contains("not")) {
            if (cliStatus.contains("synced"))
              farmerStatus = FarmerStatus.Not_Synced;
            else if (cliStatus.contains("running"))
              farmerStatus = FarmerStatus.Not_Running;
            else if (cliStatus.contains("available"))
              farmerStatus = FarmerStatus.Not_Available;
          } else {
            if (cliStatus.contains("syncing"))
              farmerStatus = FarmerStatus.Syncing;
            else if (cliStatus.contains("farming"))
              farmerStatus = FarmerStatus.Farming;
          }
        }
        try {
          if (line.startsWith("Total ${blockchain.binaryName} farmed: "))
            _farmedBalance = (blockchain.config.showBalance)
                ? double.parse(
                    line.split('Total ${blockchain.binaryName} farmed: ')[1])
                : -1.0;
        } catch (error) {
          log.warning(
              "Unable to parse farmed ${blockchain.currencySymbol.toUpperCase()}. Is wallet service running?");
        }

        try {
          if (line.startsWith("Last height farmed: "))
            lastBlockFarmed = int.parse(line.split("Last height farmed: ")[1]);
        } catch (error) {
          log.warning(
              "Unable to parse last height farmed for ${blockchain.currencySymbol.toUpperCase()}. Is wallet service running?");
        }
        try {
          if (line.startsWith("Estimated network space: "))
            _netSpace = NetSpace(line.split("Estimated network space: ")[1]);
        } catch (error) {
          log.warning("Unable to parse Netspace.");
        }
      }
    } catch (exception) {
      print("Error parsing Farm info.");
    }
  }
}
