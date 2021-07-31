import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/farmer/farmer.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/log/logitem.dart';

enum HarvesterStatus { Harvesting, Not_Harvesting }

class HarvesterStatusMixin {
  HarvesterStatus harvesterStatus = HarvesterStatus.Harvesting;
  String get harvesterStatusString =>
      harvesterStatusString.toString().split('.')[1].replaceAll("_", " ");

  String _legacyStatus = "N/A";
  String get status {
    if (_legacyStatus != "N/A")
      return _legacyStatus;
    else if (this is Farmer) {
      if (harvesterStatus != HarvesterStatus.Harvesting)
        return "${(this as Farmer).farmerStatusString}, ${this.harvesterStatusString}";
      else
        return "${(this as Farmer).farmerStatusString}";
    } else
      return "${this.harvesterStatusString}";
  }

  void updateHarvesterStatus(Blockchain blockchain) {
    if (harvestingStatus(blockchain.config.parseLogs, blockchain.cache.filters))
      harvesterStatus = HarvesterStatus.Harvesting;
    else
      harvesterStatus = HarvesterStatus.Not_Harvesting;
  }

  //used by harvester to evaluate filters
  // used by farmer to evaluate signage points
  // true means harvesting/farming, false means not farming/harvesting
  static bool harvestingStatus(bool parseLogs, List<LogItem> logItems) {
    final int harvestingLimit =
        DateTime.now().subtract(Duration(minutes: 10)).millisecondsSinceEpoch;
    final int last10mins =
        logItems.where((logItem) => logItem.timestamp > harvestingLimit).length;

    //detects if for some reason filters stopped being logged -> assumes its not harvesting
    if (parseLogs && logItems.length > 0 && last10mins == 0)
      return false;
    else
      return true;
  }

  void loadStatusFromJson(dynamic object) {
    //loads harvester status
    if (object['status'] != null) _legacyStatus = object['status'];
  }

  void combineStatus(Harvester harvester) {
    //shows harvesters status if theyre not harvesting
    if (harvester._legacyStatus != "N/A" &&
        harvester._legacyStatus != "Harvesting" &&
        harvester._legacyStatus != "Farming")
      _legacyStatus =
          "$_legacyStatus,\n${harvester.name} is ${harvester._legacyStatus}";
  }
}
