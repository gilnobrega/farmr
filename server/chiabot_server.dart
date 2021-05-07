import 'dart:core';

import 'package:mysql1/mysql1.dart' as mysql;
import 'package:dotenv/dotenv.dart' as dotenv;

import '../lib/farmer.dart';
import '../lib/harvester.dart';
import '../lib/stats.dart';
import 'price.dart';

Future<void> main(List<String> args) async {
  dotenv.load();

  //Discord User ID
  String userID = args[0];

  Price price;

  List<Harvester> harvesters;

  int farmersCount = 0;
  int harvestersCount = 0;

  try {
    //Gets user data and Price in parallel, since both are parsed from web
    var async1 = _getUserData(userID);
    var async2 = _getPrice();

    price = await async2;
    harvesters = await async1;
  } catch (e) {
    print("Failed to connect to server.");
  }

  try {
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

//gets harvesters linked to user from mysql db
Future<List<Harvester>> _getUserData(String userID) async {
  List<Harvester> harvesters = [];

  var settings = new mysql.ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: dotenv.env['MYSQL_USER'],
      password: dotenv.env['MYSQL_PASSWORD'],
      db: 'chiabot');
  var conn = await mysql.MySqlConnection.connect(settings);

  var results =
      await conn.query("SELECT data FROM farms WHERE user='${userID}' AND data<>'' AND data<>';;'");

  for (var result in results) {
    String data = "[" + result[0].toString() + "]";

    if (data.contains('"type":0'))
      harvesters.add(Farmer.fromJson(data));
    else if (data.contains('"type":1')) harvesters.add(Harvester.fromJson(data));
  }

  conn.close();

  return harvesters;
}

//get price in an isolate
Future<Price> _getPrice() async {
  Price price = Price(dotenv.env['COINMARKETCAP']);
  await price.init();

  return price;
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
        Stats.showBalance(harvester, price) +
        Stats.showPlotsInfo(harvester) +
        Stats.showETWEDV(harvester, networkSize, price) +
        Stats.showNetworkSize(harvester) +
        Stats.showFarmedTime(harvester);

    String full = (isFull || isWorkers)
        ? Stats.showLastPlotInfo(harvester) +
            Stats.showLastNDaysPlots(harvester, 8) +
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
