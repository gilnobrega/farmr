import 'dart:core';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../lib/farmer.dart';
import '../lib/harvester.dart';
import '../lib/stats.dart';

final log = Logger('Server');

Future<void> main(List<String> args) async {
  initLogger();

  //Discord User ID
  String userID = args[0];

  String contents = await http.read("https://chiabot.znc.sh/read.php?user=" + userID);

  List<Harvester> harvesters = [];

  try {
    contents = contents.trim(); //filters last , of send page, can be fixed on server side later

    var clientsSerial = contents
        .replaceAll("[;;]", "")
        .split(';;')
        .where((element) => element != "[]" && element != "")
        .toList();

    for (int i = 0; i < clientsSerial.length; i++) {
      String clientSerial = clientsSerial[i];

      var client;

      //If this object is a farmer then adds it to farmers list, if not adds it to harvesters list
      if (clientSerial.contains('"type":0')) {
        client = Farmer.fromJson(clientSerial);
        harvesters.add(client);
      } else if (clientSerial.contains('"type":1')) {
        client = Harvester.fromJson(clientSerial);
        harvesters.add(client);
      }
    }

    //Sorts harvesters by newest
    harvesters.sort((client2, client1) => (client1.lastUpdated.millisecondsSinceEpoch
        .compareTo(client2.lastUpdated.millisecondsSinceEpoch)));

    //Sorts harvesters by farmer/harvester type
    harvesters.sort((client1, client2) => client1.type.index.compareTo(client2.type.index));

    Farmer farm =
        harvesters.where((client) => client is Farmer).first; //Selects newest farm as main farm
    String networkSize = farm.networkSize;

    int harvestersCount = harvesters.where((client) => !(client is Farmer)).length;
    int farmersCount = harvesters.length - harvestersCount;

    if (args.contains("workers")) {
      for (Harvester harvester in harvesters) {
        harvester.filterDuplicates(false);
        harvester.sortPlots();

        showHarvester(harvester, harvestersCount, farmersCount, networkSize, args.contains("full"),
            args.contains("workers"));
      }
    } else {
      farm.filterDuplicates(false);
      farm.sortPlots();

      harvesters.remove(farm);

      for (Harvester harvester in harvesters) {
        farm.addHarvester(harvester);
      }

      showHarvester(farm, harvestersCount, farmersCount, networkSize, args.contains("full"),
          args.contains("workers"));
    }
  } catch (Exception) {
    if (harvesters.length > 0) log.shout(harvesters.length.toString() + " clients found.");
    log.info("${userID} - Exception: ${Exception.toString()}");
  }
}

showHarvester(Harvester harvester, int harvestersCount, int farmersCount, String networkSize,
    bool isFull, bool isWorkers) {
  if (!isFull) {
    harvestersCount = 0;
    farmersCount = 0;
  }

  String name = (isWorkers) ? Stats.showName(harvester) : '';
  String lastUpdated = (!isFull && !isWorkers)
      ? Stats.showLastUpdated(harvester, farmersCount, harvestersCount)
      : '';

  String main = name +
      Stats.showBalanceAndETW(harvester, networkSize) +
      Stats.showPlotsInfo(harvester) +
      Stats.showLastPlotInfo(harvester) +
      Stats.showNetworkSize(harvester) +
      Stats.showFarmedTime(harvester);

  String full = (isFull || isWorkers)
      ? Stats.showLastNDaysPlots(harvester, 8) +
          Stats.showIncompletePlotsWarning(harvester) +
          Stats.showFilters(harvester, true) +
          Stats.showSubSlots(harvester)
      : '';

  print(main + full + lastUpdated);
}

final io.File logFile = io.File("log.txt");

void initLogger() {
  //Creates log file
  logFile.createSync();

  //Initializes logger
  Logger.root.level = Level.SHOUT; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    String output = '${record.message}';
    if (record.level.value >= Level.SHOUT.value)
      print(output); //prints output if level is warning/error

    //otherwise logs stuff to log file
    //2021-05-02 03:02:26.548953 Client: Sent farmer report to server.
    //logFile.writeAsStringSync('\n${record.time} ${record.loggerName}: ' + output,
    //    mode: io.FileMode.append);
  });
}
