import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:filesize/filesize.dart';

import 'farm.dart';
import 'plot.dart';
import 'config.dart';

Future<void> main(List<String> args) async {
  //Discord User ID
  String userID = args[0];

  String contents =
      await http.read("https://chiabot.znc.sh/read.php?user=" + userID);

  try {
    contents = contents.substring(
        0,
        contents.length -
            2); //filters last , of send page, can be fixed on server side later

    List<Farm> farmers = [];
    List<Farm> harvesters = [];

    var clientsSerial = contents.split(';;');

    for (int i = 0; i < clientsSerial.length; i++) {
      Farm f = Farm.fromJson(clientsSerial[i]);

      //If this object is a farmer then adds it to farmers list, if not adds it to harvesters list
      if (f.type == ClientType.Farmer)
        farmers.add(f);
      else
        harvesters.add(f);
    }

    //Sorts farms by newest
    farmers.sort((farm1, farm2) => (farm1.lastUpdated.millisecondsSinceEpoch
        .compareTo(farm2.lastUpdated.millisecondsSinceEpoch)));

    Farm farm = farmers[0]; //Selects newest farm as main farm

    for (int j = 0; j < harvesters.length; j++)
      farm.addHarvester(harvesters[j]); //Adds harvesters plot to main farm

    farmStatus(farm);

    //Throws exception in case no plots were found
    if (farm.plots.length == 0) throw Exception("No plots have been found!");

    Duration farmedTime = farmingTime(farm.plots);
    double chiaPerDay =
        (farm.balance / farmingTime(farm.plots).inMinutes) * (60 * 24);

    print(":clock10: Farmed for " +
        durationToTime(farmedTime) +
        " (" +
        chiaPerDay.toStringAsFixed(2) +
        " XCH per day)");

    lastPlotTime(farm.plots);

    //Shows statistics if full command is issued by discord bot
    if (args.contains("full")) {
      print("");

      print("*STATISTICS*");
      averagePlotDuration(farm.plots);
      print("");

      //LAST 5 PLOT AVERAGE
      List<Plot> last5plots = lastNPlots(farm.plots, 5);
      print("*LAST " + last5plots.length.toString() + " PLOTS*");
      averagePlotDuration(last5plots);
    }

    print("");
    lastUpdatedText(farm, harvesters.length);
  } catch (Exception) {
    print("User could not be found.");
  }
}

//Output regarding info from "chia farm summary" command
void farmStatus(Farm farm) {
  if (farm.status != "Farming") print(":warning: **NOT FARMING** :warning:");
  print(":seedling: **" +
      farm.balance.toString() +
      " XCH** (next block in ~" +
      farm.etw.inDays.toString() +
      " days)");
  print(":farmer: **" +
      farm.plots.length.toString() +
      " plots** (" +
      fileSize(farm.sumSize()) +
      ")");
  print(":minidisc: Network size: " + farm.networkSize);
}

//calculates plot time of last plot
lastPlotTime(List<Plot> plots) {
  Duration finishedAgo = DateTime.now().difference(lastPlot(plots).end);

  //If the finished timestamp is less than 1 minute ago then it assumes it's still copying the plot to the destination
  String finishedAgoString = (finishedAgo.inMinutes == 0)
      ? "(moving to destination)"
      : ("(" + durationToTime(finishedAgo) + "ago)");

  print(":hourglass: Last plot time: **" +
      durationToTime(lastPlot(plots).duration) +
      "** " +
      finishedAgoString);
}

//finds the last plot in a list of plots
Plot lastPlot(List<Plot> plots) {
  return plots.reduce((plot1, plot2) =>
      (plot1.end.millisecondsSinceEpoch > plot2.end.millisecondsSinceEpoch)
          ? plot1
          : plot2);
}

//finds the first plot in a list of plots
Plot firstPlot(List<Plot> plots) {
  return plots.reduce((plot1, plot2) =>
      (plot1.begin.millisecondsSinceEpoch < plot2.begin.millisecondsSinceEpoch)
          ? plot1
          : plot2);
}

//Duration between first plot started being plotted and last plot is completed
Duration farmedTime(List<Plot> plots) {
  return lastPlot(plots).end.difference(firstPlot(plots).begin);
}

//Duration between first plot is completed and current time
// NEED TO CHANGE THIS FUNCTION'S NAME BUT I DONT KNOW A BETTER NAME
Duration farmingTime(List<Plot> plots) {
  return DateTime.now().difference(firstPlot(plots).end);
}

List<Plot> lastNPlots(List<Plot> plots, int n) {
  return plots
      .where((plot) => (plots.indexOf(plot) >= plots.length - n))
      .toList();
}

averagePlotDuration(List<Plot> plots) {
  int totalTime = 0;
  int avgTime = 0;

  plots.forEach((plot) {
    totalTime += plot.duration.inMilliseconds;
  });

  avgTime = totalTime ~/ plots.length;

  Duration averageDuration = Duration(milliseconds: avgTime);
  Duration farmed = farmedTime(plots);

  double plotsPerDay = (plots.length / farmed.inMinutes) * 60 * 24;

  print("Avg plot time: " +
      durationToTime(averageDuration) +
      " (" +
      plotsPerDay.toStringAsFixed(2) +
      " plots per day)");
}

//Converts a dart duration to something human-readable
String durationToTime(Duration duration) {
  String day = (duration.inDays == 0) ? "" : duration.inDays.toString();
  String hour = (duration.inHours == 0)
      ? ""
      : (duration.inHours - 24 * duration.inDays).toString();
  String minute = (duration.inMinutes - duration.inHours * 60).toString();

  day = twoDigits(day) + ((day == "") ? "" : "d ");
  hour = twoDigits(hour) + ((hour == "") ? "" : "h ");
  minute = twoDigits(minute) + "m ";

  return day + hour + minute;
}

//Used by durationToTime to always show 2 digits example 09m
String twoDigits(String input) {
  return (input.length == 1) ? "0" + input : input;
}

//Shows harvester count and when farm was last updated
void lastUpdatedText(Farm farm, int harvestersCount) {
  String count = (harvestersCount > 0)
      ? "1 farmer, " + harvestersCount.toString() + " harvesters - "
      : "";
  Duration difference = DateTime.now().difference(farm.lastUpdated);
  if (difference.inSeconds >= 60) {
    print(
        count + "updated " + difference.inMinutes.toString() + " minutes ago");
  } else {
    print(
        count + "updated " + difference.inSeconds.toString() + " seconds ago");
  }
}

String fileSize(int input) {
  return filesize(input, 3)
      .replaceAll("TB", "TiB")
      .replaceAll("GB", "GiB")
      .replaceAll("PB", "PiB");
}
