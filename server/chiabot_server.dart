import 'dart:core';

import 'package:http/http.dart' as http;

import '../lib/farmer.dart';
import '../lib/harvester.dart';
import '../lib/stats.dart';
import 'price.dart';

Future<void> main(List<String> args) async {
  //Discord User ID
  String userID = args[0];

  String contents = '';

  //use chiabot.znc.sh if not hosted on local server
  contents = await http
      .read("http://127.0.0.1/read.php?user=" + userID)
      .then((value) => contents = value);

  List<Harvester> harvesters = [];
  int farmersCount = 0;
  int harvestersCount = 0;

  Price price = Price();
  await price.init();

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

    if (harvesters.length == 0) throw new Exception("No Harvesters found.");

    //Sorts harvesters by newest
    harvesters.sort((client2, client1) => (client1.lastUpdated.millisecondsSinceEpoch
        .compareTo(client2.lastUpdated.millisecondsSinceEpoch)));

    Farmer farm =
        harvesters.where((client) => client is Farmer).first; //Selects newest farm as main farm
    String networkSize = farm.networkSize;

    harvestersCount = harvesters.where((client) => !(client is Farmer)).length;
    farmersCount = harvesters.length - harvestersCount;

    if (args.contains("workers")) {
      //Sorts workers by alphabetical order
      harvesters.sort((harvester1, harvester2) => harvester1.name.compareTo(harvester2.name));

      //Sorts workers by farmer/harvester type
      harvesters.sort((client1, client2) => client1.type.index.compareTo(client2.type.index));

      for (Harvester harvester in harvesters) {
        harvester.filterDuplicates(false);
        harvester.sortPlots();

        showHarvester(harvester, harvestersCount, farmersCount, networkSize, args.contains("full"),
            args.contains("workers"), price.price);

        print(';;');
      }
    } else {
      //Sorts harvesters by farmer/harvester type
      harvesters.sort((client1, client2) => client1.type.index.compareTo(client2.type.index));

      farm.filterDuplicates(false);
      farm.sortPlots();

      harvesters.remove(farm);

      for (Harvester harvester in harvesters) {
        farm.addHarvester(harvester);
      }

      showHarvester(farm, harvestersCount, farmersCount, networkSize, args.contains("full"),
          args.contains("workers"), price.price);
    }
  } catch (Exception) {
    if (farmersCount == 0)
      print("Error: Farmer not found.");
    else if (harvesters.length > 0)
      print("Error: ${farmersCount} farmers and ${harvestersCount} harvesters found.");
    else
      print("No clients found!");

    //print("${userID} - Exception: ${Exception.toString()}");
  }
}

showHarvester(Harvester harvester, int harvestersCount, int farmersCount, String networkSize,
    bool isFull, bool isWorkers, double price,
    [bool discord = true]) {
  String output;

  try {
    if (!isFull) {
      harvestersCount = 0;
      farmersCount = 0;
    }

    String name = (isWorkers) ? Stats.showName(harvester) : '';
    String lastUpdated = ((isFull || isWorkers) && discord)
        ? Stats.showLastUpdated(harvester, farmersCount, harvestersCount)
        : '';

    String main = name +
        Stats.showBalanceAndETW(harvester, networkSize, true, price) +
        Stats.showPlotsInfo(harvester) +
        Stats.showLastPlotInfo(harvester) +
        Stats.showNetworkSize(harvester) +
        Stats.showFarmedTime(harvester);

    String full = (isFull || isWorkers)
        ? Stats.showLastNDaysPlots(harvester, 8) +
            Stats.showIncompletePlotsWarning(harvester) +
            Stats.showFilters(harvester) +
            Stats.showSubSlots(harvester)
        : '';

    output = main + full + lastUpdated;

    //removes discord emojis
    if (!discord) {
      try {
        RegExp emojiRegex = RegExp('(:[\\S]+: )');
        RegExp externalEmojiRegex = RegExp('(<:[\\S]+:[0-9]+> )');

        var matches = emojiRegex.allMatches(output).toList();
        matches.addAll(externalEmojiRegex.allMatches(output).toList());

        for (var match in matches)
          output = output.replaceAll(match.group(1), "").replaceAll("**", "");
      } catch (e) {}
    }
  } catch (e) {
    output = "Failed to display stats.";
  }

  print(output);
}
