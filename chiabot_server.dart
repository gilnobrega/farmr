import 'dart:core';

import 'package:http/http.dart' as http;

import 'farm.dart';
import 'plot.dart';
import 'config.dart';

Future<void> main(List<String> args) async {
  //Discord User ID
  String userID = args[0];

  String contents =
      await http.read("https://chiabot.znc.sh/read.php?user=" + userID);

  List<Farm> farmers = [];
  List<Farm> harvesters = [];

  try {
    contents = contents.substring(
        0,
        contents.length -
            3); //filters last , of send page, can be fixed on server side later

    var clientsSerial = contents
        .replaceAll("[;;]", "")
        .split(';;')
        .where((element) => element != "[]" && element != "")
        .toList();

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

    Farm farm = farmers.last; //Selects newest farm as main farm

    if (args.contains("workers")) {
      print("**Farmer:**");

      farm.filterDuplicates(); //filters duplicates
      farm.sortPlots();

      farmStatus(farm);
      mainText(farm);
      fullText(farm);

      lastUpdatedText(farm, 0);

      harvesters.sort((harvester2, harvester1) =>
          harvester1.plots.length.compareTo(harvester2.plots.length));

      for (int k = 0; k < harvesters.length; k++) {
        print(";;"); // discord bot uses ;; to split into a new message

        Farm harvester = harvesters[k];
        harvester.filterDuplicates(); //filters duplicates in harvester
        harvester.sortPlots();

        print("**Harvester " + (k + 1).toString() + ":**");
        farmStatus(harvester);
        mainText(harvester);
        fullText(harvester);
        lastUpdatedText(harvester, 0);
      }
    } else {
      for (int j = 0; j < harvesters.length; j++)
        farm.addHarvester(harvesters[j]); //Adds harvesters plot to main farm

      farm.filterDuplicates(); //filters duplicates
      farm.sortPlots(); //VERY IMPORTANT TO SORT PLOTS BEFORE CALCULATING STATS

      farmStatus(farm);

      //Throws exception in case no plots were found
      if (farm.plots.length == 0) throw Exception("No plots have been found!");

      mainText(farm);
    }

    //Shows statistics if full command is issued by discord bot
    if (args.contains("full")) {
      print("");

      print("*STATISTICS*");
      averagePlotDuration(farm.plots);

      fullText(farm);
      lastUpdatedText(farm, harvesters.length);
    }

    print("");
  } catch (Exception) {
    if (harvesters.length > 0)
      print(harvesters.length.toString() + " harvesters found.");
    print(
        "Farmer could not be found.\nMake sure your farmer client is running.");
  }
}

void mainText(Farm farm) {
  Duration farmedTime = farmingTime(farm.plots);
  double chiaPerDay =
      (farm.balance / farmingTime(farm.plots).inMinutes) * (60 * 24);

  lastPlotTime(farm.plots);
  lastPlotSize(farm);

  String chiaPerDayString = (farm.balance < 0.0)
      ? "\n" //for some reason needs a new line here
      : "(" +
          chiaPerDay.toStringAsFixed(2) +
          " XCH per day)"; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

  print(":clock10: Farmed for " +
      durationToTime(farmedTime) +
      " " +
      chiaPerDayString);
}

void fullText(Farm farm) {
  var n = [
    null,
    5,
    20,
    50,
    100,
    200,
    500
  ]; //last n plots, null represents all plots
  var d = [null]; //last d days, null represents overall

  int daysAgo = 8; //Lists plots upto 8 days ago, including current day
  int weekCount = 0; //counts plots in week of completed days

  for (int k = 0; k < daysAgo; k++) {
    List<Plot> plots = plotsNDaysAgo(farm, k);

    int count = plots.length;
    int sumSize = plotSumSize(plots);

    String text = "";
    //displays plot count for today even if it's 0
    if (k == 0 || count > 0) {
      if (k == 0) {
        text += "Today: completed " + count.toString() + " plots";
      } else {
        text += humanReadableDate(nDaysAgoString(farm, k)) +
            ": completed " +
            count.toString() +
            " plots";
        weekCount += count;
      }

      text += " (" + fileSize(sumSize, 1);
      text += ")";
      print(text);
    }
  }

  print("");

  Duration farmed = farmedTime(farm.plots);

  for (int j = 0; j < d.length; j++) {
    double ppd = 0.0; //plots per day

    //does overall plot per day if overPeriod average period is not defined,
    //if this period is defined then it calculates plotsPerDay using its dedicated function
    if (d[j] == null) {
      ppd = (farm.plots.length / farmed.inMinutes) * 60.0 * 24.0;
      print("All time:  " + ppd.toStringAsFixed(2) + " plots per day");
    } else {
      Duration overPeriod = Duration(days: d[j]);
      ppd = plotsPerDay(farm.plots, overPeriod);

      print("Last " +
          d[j].toString() +
          " days: " +
          ppd.toStringAsFixed(2) +
          " plots per day");
    }
  }

  print("Last 7 days: " +
      (weekCount / 7.0).toStringAsFixed(2) +
      " plots per day");

  print("");

  for (int i = 0; i < n.length; i++) {
    if (n[i] == null) {
      Duration avg = averagePlotDuration(farm.plots);

      print("All time average plot length: " + durationToTime(avg));
    } else if (farm.plots.length > n[i]) {
      //LAST N PLOT AVERAGE
      Duration avg = averagePlotDuration(lastNPlots(farm.plots, n[i]));

      print(
          "Last " + n[i].toString() + " plots average: " + durationToTime(avg));
    }
  }
}

//Output regarding info from "chia farm summary" command
void farmStatus(Farm farm) {
  //if its farmer then shows balance and farming status
  if (farm.type == ClientType.Farmer) {
    String etw = farm.estimateETW().toStringAsFixed(1);

    String balanceText = (farm.balance < 0.0)
        ? "Next block in ~" + etw + " days"
        : "**" +
            farm.balance.toString() +
            " XCH** (next block in ~" +
            etw +
            " days)"; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

    if (farm.status != "Farming") print(":warning: **NOT FARMING** :warning:");
    print("\\<:chia:833767070201151528> " + balanceText);
  }

  //e.g. using 3.7 TB out of 7TB
  String plotInfo = "(using " + fileSize(plotSumSize(farm.plots));

  if (farm.supportDiskSpace)
    plotInfo += " out of " +
        fileSize(farm.totalDiskSpace); //if farm supports disk space then

  print(":farmer: **" +
      farm.plots.length.toString() +
      " plots** " +
      plotInfo +
      ")");
}

//calculates plot time of last plot
void lastPlotTime(List<Plot> plots) {
  Plot plot = lastPlot(plots);
  Duration average = averagePlotDuration(plots);

  //relative difference in % of plot duration vs average plot duration
  double ratio = 1 - (plot.duration.inMilliseconds / average.inMilliseconds);
  String difference = (ratio > 0)
      ? (ratio * 100).toStringAsFixed(0) + "% below Ø"
      : (-ratio * 100).toStringAsFixed(0) + "% above Ø";

  print(":hourglass: Last plot length: **" +
      durationToTime(plot.duration) +
      "** " +
      "(" +
      difference +
      ")");
}

//calculates plot size of last plot
void lastPlotSize(Farm farm) {
  Duration finishedAgo = DateTime.now().difference(lastPlot(farm.plots).end);

  //If the finished timestamp is less than 1 minute ago then it assumes it's still copying the plot to the destination
  String finishedAgoString = (finishedAgo.inMinutes == 0)
      ? "(moving to destination)"
      : ("(completed " + durationToTime(finishedAgo) + "ago)");

  print("\\<:hdd:831678109018751037> Size: " +
      fileSize(lastPlot(farm.plots).size, 1) +
      " " +
      finishedAgoString);
  if (farm.type == ClientType.Farmer)
    print(":satellite: Network size: " + farm.networkSize);
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

Duration averagePlotDuration(List<Plot> lastNPlots) {
  int totalTime = 0;
  int avgTime = 0;

  lastNPlots.forEach((plot) {
    totalTime += plot.duration.inMilliseconds;
  });

  avgTime = totalTime ~/ lastNPlots.length;

  Duration averageDuration = Duration(milliseconds: avgTime);

  return averageDuration;
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
  String count = "--"; // -- is last updated split character
  count += (harvestersCount > 0)
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

//Calculates the plots per day average over a given period.
//Starts counting from the PENULTIMATE plot completed time
double plotsPerDay(List<Plot> plots, Duration overPeriod) {
  DateTime end = lastPlot(plots.sublist(0, plots.length - 1))
      .end; //PENUlTIMATE because its more accurate than last plot
  DateTime begin = end.subtract(overPeriod);

  //Plot number is the fractional number of plots which are within that duration
  double plotNumber = 0.0;

  //Filters plots which ended after start time, or began before period end time
  for (int i = 0; i < plots.length; i++) {
    Plot plot = plots[i]; //current plot being evaluated in iteration

    //if whole plot was started and completed within that period
    bool isFullyWithin =
        plot.begin.millisecondsSinceEpoch >= begin.millisecondsSinceEpoch &&
            plot.end.millisecondsSinceEpoch <= end.millisecondsSinceEpoch;

    //if plot started before period began but got completed after period started
    bool endedAfterPeriodBegan =
        plot.end.millisecondsSinceEpoch >= begin.millisecondsSinceEpoch &&
            plot.begin.millisecondsSinceEpoch < begin.millisecondsSinceEpoch;

    //if plot started before period ended but got completed after period ended
    bool startedBeforePeriodEnded =
        plot.begin.millisecondsSinceEpoch <= end.millisecondsSinceEpoch &&
            plot.end.millisecondsSinceEpoch > end.millisecondsSinceEpoch;

    bool startedAfterPeriodBeganAndEndedBeforePeriodCompleted =
        plot.begin.millisecondsSinceEpoch <= begin.millisecondsSinceEpoch &&
            plot.end.millisecondsSinceEpoch >= end.millisecondsSinceEpoch;

    double fraction = 0.0; //fraction of plot within period

    if (isFullyWithin)
      fraction = 1.0;
    else if (endedAfterPeriodBegan)
      fraction =
          (plot.end.millisecondsSinceEpoch - begin.millisecondsSinceEpoch) /
              overPeriod.inMilliseconds;
    else if (startedBeforePeriodEnded)
      fraction =
          (end.millisecondsSinceEpoch - plot.begin.millisecondsSinceEpoch) /
              overPeriod.inMilliseconds;
    else if (startedAfterPeriodBeganAndEndedBeforePeriodCompleted)
      fraction = overPeriod.inMilliseconds /
          plot.duration.inMilliseconds; //CHECK THIS PART

    plotNumber += fraction;
  }

  double plotsPerMinute = plotNumber / overPeriod.inMinutes;
  double plotsPerDay = plotsPerMinute * 60 * 24;

  return plotsPerDay;
}

//Returns number of plots finished n days ago
List<Plot> plotsNDaysAgo(Farm farm, int n) {
  return farm.plots
      .where((plot) => plot.date == nDaysAgoString(farm, n))
      .toList();
}

//Makes an n days ago string based on farmer's timezone
String nDaysAgoString(Farm farm, int n) {
  DateTime clientToday = stringToDate(farm.lastUpdatedString);

  DateTime nDaysAgo = clientToday.subtract(Duration(days: n));

  return dateToString(nDaysAgo);
}

//Human readable n days ago string seen above
String humanReadableDate(String ndaysago) {
  List<String> months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec"
  ];

  String day = ndaysago.split('-')[2];

  if (day.length == 1) day = " " + day;

  String month = months[int.parse(ndaysago.split('-')[1]) - 1];

  return month + " " + day;
}
