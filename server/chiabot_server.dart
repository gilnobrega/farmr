import 'dart:core';
import 'dart:math' as Math;

import 'package:http/http.dart' as http;
import 'package:stats/stats.dart';

import '../lib/farmer.dart';
import '../lib/harvester.dart';
import '../lib/plot.dart';

import '../lib/log/filter.dart';

Future<void> main(List<String> args) async {
  //Discord User ID
  String userID = args[0];

  String contents = await http.read("https://chiabot.znc.sh/read.php?user=" + userID);

  List<Farmer> farmers = [];
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
        farmers.add(client);
      } else if (clientSerial.contains('"type":1')) {
        client = Harvester.fromJson(clientSerial);
        harvesters.add(client);
      }
    }

    //Sorts farms by newest
    farmers.sort((farm1, farm2) => (farm1.lastUpdated.millisecondsSinceEpoch
        .compareTo(farm2.lastUpdated.millisecondsSinceEpoch)));

    Farmer farm = farmers.last; //Selects newest farm as main farm
    String networkSize = farm.networkSize;

    if (args.contains("workers")) {
      print("**Farmer:**");

      farm.filterDuplicates(); //filters duplicates
      farm.sortPlots();

      farmStatus(farm, networkSize);
      mainText(farm);
      print("");
      fullText(farm);

      print("");
      showFilters(farm);

      lastUpdatedText(farm, 0);

      harvesters.sort(
          (harvester2, harvester1) => harvester1.plots.length.compareTo(harvester2.plots.length));

      for (int k = 0; k < harvesters.length; k++) {
        print(";;"); // discord bot uses ;; to split into a new message

        Harvester harvester = harvesters[k];
        harvester.filterDuplicates(); //filters duplicates in harvester
        harvester.sortPlots();

        print("**Harvester " + (k + 1).toString() + ":**");
        farmStatus(harvester, networkSize);
        mainText(harvester, false);
        print("");
        fullText(harvester);

        print("");
        showFilters(harvester);

        lastUpdatedText(harvester, 0);
      }
    } else {
      for (int j = 0; j < harvesters.length; j++)
        farm.addHarvester(harvesters[j]); //Adds harvesters plot to main farm

      farm.filterDuplicates(); //filters duplicates
      farm.sortPlots(); //VERY IMPORTANT TO SORT PLOTS BEFORE CALCULATING STATS

      farmStatus(farm, networkSize);

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

      print("");
      showFilters(farm);

      lastUpdatedText(farm, harvesters.length);
    }

    print("");
  } catch (Exception) {
    if (harvesters.length > 0) print(harvesters.length.toString() + " harvesters found.");
    print("Farmer could not be found.\nMake sure your farmer client is running.");
  }
}

void mainText(Harvester client, [bool showPerDay = true]) {
  Duration farmedTime = farmingTime(client.plots);
  double chiaPerDay =
      (client is Farmer) ? (client.balance / farmingTime(client.plots).inMinutes) * (60 * 24) : 0;

  lastPlotTime(client.plots);
  lastPlotSize(client);

  //hides balance if client is harvester or if it's farmer and showBalance is false
  String chiaPerDayString = (!(client is Farmer) || ((client is Farmer) && client.balance < 0.0))
      ? "" //for some reason needs a new line here
      : "(" +
          chiaPerDay.toStringAsFixed(2) +
          " XCH per day)"; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

  print(":clock10: Farmed for " + durationToTime(farmedTime) + " " + chiaPerDayString);
}

void fullText(Harvester client) {
  var n = [null]; //last n plots, null represents all plots
  var d = [null]; //last d days, null represents overall

  int daysAgo = 8; //Lists plots upto 8 days ago, including current day
  int weekCount = 0; //counts plots in week of completed days
  int weekSize = 0;
  int daysWithPlots = 0; //days in the last week with plots

  for (int k = 0; k < daysAgo; k++) {
    List<Plot> plots = plotsNDaysAgo(client, k);

    int count = plots.length;
    int sumSize = plotSumSize(plots);

    String text = "";
    //displays plot count for today even if it's 0
    if (k == 0 || count > 0) {
      if (k == 0) {
        text += "Today: completed " + count.toString() + " plots";
      } else {
        text += humanReadableDate(nDaysAgoString(client, k)) +
            ": completed " +
            count.toString() +
            " plots";
        weekCount += count;
        weekSize += sumSize;
        daysWithPlots += 1;
      }

      text += " (" + fileSize(sumSize, 1);
      text += ")";
      print(text);
    }
  }

  if (weekCount > 0) {
    print("");

    //Calculates when it will run out of space based on last week's statistics
    int outOfSpaceHours =
        (weekSize > 0) ? ((client.freeDiskSpace / weekSize) * daysWithPlots * 24).round() : 0;
    String outOfSpace = durationToTime(Duration(hours: outOfSpaceHours));

    print("Last week: completed ${weekCount.toString()} plots");

    if (client.supportDiskSpace) {
      //If free space is less than a k32 plot size
      if (client.freeDiskSpace > 0 && client.freeDiskSpace < 1.1e9)
        print(":warning: **OUT OF SPACE** :warning:");
      if (client.freeDiskSpace > 0 && weekSize > 0)
        print("Out of space in ${outOfSpace}");
      //If time until out of space is shorter than 4 hours then it will assume it's out of space
      else if (outOfSpaceHours <= 4 && weekSize > 0) print("**OUT OF SPACE IN $outOfSpace**");
    }

    print("");

    Duration farmed = farmedTime(client.plots);

    for (int j = 0; j < d.length; j++) {
      double ppd = 0.0; //plots per day

      //does overall plot per day if overPeriod average period is not defined,
      //if this period is defined then it calculates plotsPerDay using its dedicated function
      if (d[j] == null) {
        ppd = (client.plots.length / farmed.inMinutes) * 60.0 * 24.0;
        print("All time:  " + ppd.toStringAsFixed(2) + " plots per day");
      } else {
        Duration overPeriod = Duration(days: d[j]);
        ppd = plotsPerDay(client.plots, overPeriod);

        print("Last " + d[j].toString() + " days: " + ppd.toStringAsFixed(2) + " plots per day");
      }
    }

    double weekAverage = weekCount / daysWithPlots;
    print("Last 7 days: " + (weekAverage).toStringAsFixed(2) + " plots per day");
  }

  print("");

  for (int i = 0; i < n.length; i++) {
    if (n[i] == null) {
      Duration avg = averagePlotDuration(client.plots);

      print("All time average plot length: " + durationToTime(avg));
    } else if (client.plots.length > n[i]) {
      //LAST N PLOT AVERAGE
      Duration avg = averagePlotDuration(lastNPlots(client.plots, n[i]));

      print("Last " + n[i].toString() + " plots average: " + durationToTime(avg));
    }
  }

  //If found incomplete plots then it will show this warning below
  if (client.incompletePlots.length > 0) {
    print("");
    print("**${client.incompletePlots.length}** potentially incomplete plots");
  }
}

//Output regarding info from "chia farm summary" command
void farmStatus(Harvester client, String networkSize, [bool showETW = true]) {
  String etw = "";
  String etwtext = "";

  if (client is Farmer && client.status != "Farming") print(":warning: **NOT FARMING** :warning:");

  //if its farmer then shows balance and farming status
  etw = estimateETW(client, networkSize).toStringAsFixed(1);
  etwtext = (showETW) ? "(next block in " + etw + " days)" : '';

  double balance = (client is Farmer) ? client.balance : -1.0;

  String balanceText = '\<:chia:833767070201151528> ';

  balanceText += (balance <= 0.0)
      ? "Next block in ~" + etw + " days"
      : "**" +
          balance.toString() +
          " XCH** " +
          etwtext; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)
  print(balanceText);

  int plotsSize = plotSumSize(client.plots);
  //e.g. using 3.7 TB out of 7TB
  String plotInfo = "(using " + fileSize(plotsSize);

  if (client.supportDiskSpace)
    plotInfo +=
        " out of " + fileSize(client.freeDiskSpace + plotsSize); //if farm supports disk space then

  print(":farmer: **" + client.plots.length.toString() + " plots** " + plotInfo + ")");
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
void lastPlotSize(Harvester client) {
  Duration finishedAgo = DateTime.now().difference(lastPlot(client.plots).end);

  //If the finished timestamp is less than 1 minute ago then it assumes it's still copying the plot to the destination
  String finishedAgoString = (finishedAgo.inMinutes == 0)
      ? "(moving to destination)"
      : ("(completed " + durationToTime(finishedAgo) + "ago)");

  print("\<:hdd:831678109018751037> Size: " +
      fileSize(lastPlot(client.plots).size, 1) +
      " " +
      finishedAgoString);
  if (client is Farmer) print(":satellite: Network size: " + client.networkSize);
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
  return plots.where((plot) => (plots.indexOf(plot) >= plots.length - n)).toList();
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
  String hour = (duration.inHours == 0) ? "" : (duration.inHours - 24 * duration.inDays).toString();
  String minute = (duration.inMinutes - duration.inHours * 60).toString();

  day = twoDigits(day) + ((day == "") ? "" : "d ");
  hour = twoDigits(hour) + ((hour == "") ? "" : "h ");
  minute = (minute == "0") ? '' : twoDigits(minute) + "m ";

  return day + hour + minute;
}

//Used by durationToTime to always show 2 digits example 09m
String twoDigits(String input) {
  return (input.length == 1) ? "0" + input : input;
}

//Shows harvester count and when farm was last updated
void lastUpdatedText(Harvester client, int harvestersCount) {
  String count = "--"; // -- is last updated split character
  count +=
      (harvestersCount > 0) ? "1 farmer, " + harvestersCount.toString() + " harvesters - " : "";
  Duration difference = DateTime.now().difference(client.lastUpdated);
  if (difference.inSeconds >= 60) {
    print(count + "updated " + difference.inMinutes.toString() + " minutes ago");
  } else {
    print(count + "updated " + difference.inSeconds.toString() + " seconds ago");
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
    bool isFullyWithin = plot.begin.millisecondsSinceEpoch >= begin.millisecondsSinceEpoch &&
        plot.end.millisecondsSinceEpoch <= end.millisecondsSinceEpoch;

    //if plot started before period began but got completed after period started
    bool endedAfterPeriodBegan = plot.end.millisecondsSinceEpoch >= begin.millisecondsSinceEpoch &&
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
      fraction = (plot.end.millisecondsSinceEpoch - begin.millisecondsSinceEpoch) /
          overPeriod.inMilliseconds;
    else if (startedBeforePeriodEnded)
      fraction = (end.millisecondsSinceEpoch - plot.begin.millisecondsSinceEpoch) /
          overPeriod.inMilliseconds;
    else if (startedAfterPeriodBeganAndEndedBeforePeriodCompleted)
      fraction = overPeriod.inMilliseconds / plot.duration.inMilliseconds; //CHECK THIS PART

    plotNumber += fraction;
  }

  double plotsPerMinute = plotNumber / overPeriod.inMinutes;
  double plotsPerDay = plotsPerMinute * 60 * 24;

  return plotsPerDay;
}

//Returns number of plots finished n days ago
List<Plot> plotsNDaysAgo(Harvester client, int n) {
  return client.plots.where((plot) => plot.date == nDaysAgoString(client, n)).toList();
}

//Makes an n days ago string based on farmer's timezone
String nDaysAgoString(Harvester client, int n) {
  DateTime clientToday = stringToDate(client.lastUpdatedString);

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

//Estimates ETW in days
//Decimals are more precise (in theory)
double estimateETW(Harvester client, String networkSize) {
  double networkSizeBytes = 0;

  int size = plotSumSize(client.plots);

  //1 PiB is 1024^5 bytes, 1 EiB is 1024^6 bytes
  if (networkSize.contains("PiB"))
    networkSizeBytes = double.parse(networkSize.replaceAll(" PiB", "")) * Math.pow(1024, 5);
  else if (networkSize.contains("EiB"))
    networkSizeBytes = double.parse(networkSize.replaceAll(" EiB", "")) * Math.pow(1024, 6);

  double blocks = 32.0; //32 blocks per 10 minutes

  double calc = (networkSizeBytes / size) / (blocks * 6.0 * 24.0);

  return calc;
}

void showFilters(Harvester harvester) {
  if (harvester.filters.length > 0) {
    harvester.filters.sort((filter1, filter2) => filter1.time.compareTo(filter2.time));

    List<double> times = harvester.filters.map((filter) => filter.time).toList();

    Stats timeStats = Stats.fromData(times);

    String maxTime = timeStats.max.toString();
    String minTime = timeStats.min.toStringAsFixed(3);
    String avgTime = timeStats.average.toStringAsFixed(3);
    String medianTime = timeStats.median.toStringAsFixed(3);
    String stdDevTime = timeStats.standardDeviation.toStringAsFixed(3);

    int totalEligiblePlots = 0;

    for (Filter filter in harvester.filters) totalEligiblePlots += filter.eligiblePlots;
    print("Last 24 hours: ${totalEligiblePlots} plots passed ${times.length} filters");

    //Calculates ratio based on each harvesters proportion (farmer's filterRatio)
    double ratio = (harvester is Farmer)
        ? harvester.filterRatio / harvester.totalPlots
        : (totalEligiblePlots / harvester.filters.length * 512 / harvester.plots.length);
    String ratioString = ratio.toStringAsFixed(2);
    String luck = ((ratio) * 100).toStringAsFixed(0) + "%";

    print("Each plot passed ${ratioString} times per 512 filters");
    print("24h Efficiency: **${luck}**");

    print("");

    print("Longest response time: **${maxTime}** seconds");
    print("Shortest response time: ${minTime} seconds ");
    print("Median: ${medianTime}s Avg: ${avgTime}s σ: ${stdDevTime}s");

    if (timeStats.max > 25) print(":warning: ** Response time too long ** :warning:");
  }

  if (harvester is Farmer && harvester.completeSubSlots > 0) {
    int totalSignagePoints = (64 * harvester.completeSubSlots) + harvester.looseSignagePoints;

    double ratio = harvester.looseSignagePoints / (totalSignagePoints);

    String percentage = (ratio * 100).toStringAsFixed(2);

    print("");
    print("*EXPERIMENTAL*");
    print("${harvester.completeSubSlots} complete Sub Slots");
    print("${percentage}% loose Signage Points");
  }
}
