import 'harvester.dart';
import 'farmer.dart';
import 'plot.dart';

import 'dart:math' as Math;

class Stats {
  static String showName(Harvester harvester, [int count = null]) {
    String name = harvester.name + ((count == null) ? '' : count.toString());

    return ":farmer: **${name}**";
  }

  static String showPlotsInfo(Harvester client) {
    int plotsSize = plotSumSize(client.plots);
    //e.g. using 3.7 TB out of 7TB
    String plotInfo = "(using " + fileSize(plotsSize);

    if (client.supportDiskSpace)
      plotInfo += " out of " +
          fileSize(client.freeDiskSpace + plotsSize); //if farm supports disk space then

    return "\n:tractor: **" + client.plots.length.toString() + " plots** " + plotInfo + ")";
  }

  static String showBalanceAndETW(Harvester client, String networkSize, [bool showETW = true]) {
    String output = '';
    String etw = "";
    String etwtext = "";

    if (client is Farmer && client.status != "Farming")
      output += "\n:warning: **${client.status}** :warning:";

    //if its farmer then shows balance and farming status
    etw = estimateETW(client, networkSize).toStringAsFixed(1);
    etwtext = (showETW && client.plots.length > 0) ? "(next block in " + etw + " days)" : '';

    double balance = (client is Farmer) ? client.balance : -1.0;

    String balanceText = '\n\<:chia:833767070201151528> ';

    balanceText += (balance < 0.0)
        ? "Next block in ~" + etw + " days"
        : "**" +
            balance.toString() +
            " XCH** " +
            etwtext; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

    output += balanceText;

    return output;
  }

  static String showLastPlotInfo(Harvester client) {
    String output = '';

    if (client.plots.length > 0) {
      Plot plot = lastPlot(client.plots);
      Duration average =
          averagePlotDuration(client.plots.where((plot) => plot.duration.inMinutes > 0).toList());

      //relative difference in % of plot duration vs average plot duration
      double ratio = 1 - (plot.duration.inMilliseconds / average.inMilliseconds);
      String difference = (ratio > 0)
          ? (ratio * 100).toStringAsFixed(0) + "% below Ø"
          : (-ratio * 100).toStringAsFixed(0) + "% above Ø";

      output += "\n:hourglass: Last plot length: **" +
          durationToTime(plot.duration) +
          "** " +
          "(" +
          difference +
          ")";
      Duration finishedAgo = DateTime.now().difference(lastPlot(client.plots).end);

      //If the finished timestamp is less than 1 minute ago then it assumes it's still copying the plot to the destination
      String finishedAgoString = (finishedAgo.inMinutes == 0)
          ? "(moving to destination)"
          : ("(completed " + durationToTime(finishedAgo) + "ago)");

      output +=
          "\n\<:hdd:831678109018751037> Size: " + fileSize(plot.size, 1) + " " + finishedAgoString;
    }

    return output;
  }

  static String showNetworkSize(Harvester client) {
    String output = '';
    if (client is Farmer) output += "\n:satellite: Network size: " + client.networkSize;

    return output;
  }

  static String showFarmedTime(Harvester client) {
    String output = '';
    if (client.plots.length > 0) {
      Duration farmedTime = farmingTime(client.plots);
      double chiaPerDay = (client is Farmer)
          ? (client.balance / farmingTime(client.plots).inMinutes) * (60 * 24)
          : 0;

      //hides balance if client is harvester or if it's farmer and showBalance is false
      String chiaPerDayString =
          (!(client is Farmer) || ((client is Farmer) && client.balance < 0.0))
              ? "" //for some reason needs a new line here
              : "(" +
                  chiaPerDay.toStringAsFixed(2) +
                  " XCH per day)"; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

      output += "\n:clock10: Farmed for " + durationToTime(farmedTime) + " " + chiaPerDayString;
    }
    return output;
  }

  static String showLastNDaysPlots(Harvester client, int daysAgo) {
    int weekCount = 0; //counts plots in week of completed days
    int weekSize = 0;
    int daysWithPlots = 0; //days in the last week with plots

    String text = "";

    for (int k = 0; k < daysAgo; k++) {
      List<Plot> plots = plotsNDaysAgo(client, k);

      int count = plots.length;
      int sumSize = plotSumSize(plots);

      //displays plot count for today even if it's 0
      if (k == 0 || count > 0) {
        if (k == 0) {
          text += "\n\nToday: completed " + count.toString() + " plots";
        } else {
          text += "\n" +
              humanReadableDate(nDaysAgoString(client, k)) +
              ": completed " +
              count.toString() +
              " plots";
          weekCount += count;
          weekSize += sumSize;
          daysWithPlots += 1;
        }

        text += " (" + fileSize(sumSize, 1);
        text += ")";
      }
    }

    text += showWeekPlots(client, weekCount, weekSize, daysWithPlots);

    return text;
  }

  static String showWeekPlots(Harvester client, int weekCount, int weekSize, int daysWithPlots) {
    String output = '\n';

    if (weekCount > 0) {
      //Calculates when it will run out of space based on last week's statistics
      int outOfSpaceHours =
          (weekSize > 0) ? ((client.freeDiskSpace / weekSize) * daysWithPlots * 24).round() : 0;
      String outOfSpace = durationToTime(Duration(hours: outOfSpaceHours));

      output += "\nLast week: completed ${weekCount.toString()} plots";

      if (client.supportDiskSpace) {
        //If free space is less than a k32 plot size
        if (client.freeDiskSpace > 0 && client.freeDiskSpace < 1.1e9)
          output += "\n:warning: **OUT OF SPACE** :warning:";
        if (client.freeDiskSpace > 0 && weekSize > 0)
          output += "\nOut of space in ${outOfSpace}";
        //If time until out of space is shorter than 4 hours then it will assume it's out of space
        else if (outOfSpaceHours <= 4 && weekSize > 0)
          output += "\n**OUT OF SPACE IN $outOfSpace**";
      }

      Duration farmed = farmedTime(client.plots);

      double ppd = 0.0; //plots per day

      //does overall plot per day if overPeriod average period is not defined,
      //if this period is defined then it calculates plotsPerDay using its dedicated function
      ppd = (client.plots.length / farmed.inMinutes) * 60.0 * 24.0;
      output += "\nAll time:  " + ppd.toStringAsFixed(2) + " plots per day";

      double weekAverage = weekCount / daysWithPlots;
      output += "\nLast 7 days: " + (weekAverage).toStringAsFixed(2) + " plots per day";

      Duration avg = averagePlotDuration(client.plots);

      output += "\nAll time average plot length: " + durationToTime(avg);
    }

    return output;
  }

  static String showIncompletePlotsWarning(Harvester client) {
    String output = '';
    //If found incomplete plots then it will show this warning below
    if (client.incompletePlots.length > 0) {
      output = "\n**${client.incompletePlots.length}** potentially incomplete plots";
    }

    return output;
  }

  static String showFilters(Harvester harvester) {
    String output = '';
    if (harvester.numberFilters > 0) {
      int totalEligiblePlots = harvester.eligiblePlots;
      output +=
          "\n\nLast 24 hours: ${totalEligiblePlots} plots passed ${harvester.numberFilters} filters";

      //Calculates ratio based on each harvesters proportion (farmer's filterRatio)
      double ratio = (harvester is Farmer)
          ? harvester.filterRatio / harvester.totalPlots
          : (totalEligiblePlots / harvester.numberFilters * 512 / harvester.plots.length);
      String ratioString = ratio.toStringAsFixed(2);
      String luck = ((ratio) * 100).toStringAsFixed(0) + "%";

      output += "\nEach plot passed ${ratioString} times per 512 filters";
      output += "\n24h Efficiency: **${luck}**";

      output += "\n\nLongest response: **${harvester.maxTime}** seconds";
      output += "\nShortest response: ${harvester.minTime} seconds";

      int decimals = 3;

      if (harvester.medianTime > 0 || harvester.avgTime > 0)
        output +=
            "\nMedian: ${harvester.medianTime.toStringAsFixed(decimals)}s Avg: ${harvester.avgTime.toStringAsFixed(decimals)}s σ: ${harvester.stdDeviation.toStringAsFixed(decimals)}s";

      if (harvester.maxTime > 25) {
        output += "\n:warning: ** Response time too long ** :warning:";
        if (harvester.missedChallenges > 1)
          output += "\nPotentially missed ${harvester.missedChallenges} challenges";
      }
    }

    return output;
  }

  static String showSubSlots(Harvester harvester) {
    String output = '';
    if (harvester is Farmer && harvester.completeSubSlots > 0) {
      int totalSignagePoints = (64 * harvester.completeSubSlots) + harvester.looseSignagePoints;

      double ratio = harvester.looseSignagePoints / (totalSignagePoints);

      String percentage = (ratio * 100).toStringAsFixed(2);

      output += "\n\n*EXPERIMENTAL*";
      output += "\n${harvester.completeSubSlots} complete Sub Slots";
      output += "\n${percentage}% loose Signage Points";
    }

    return output;
  }

//Shows harvester count and when farm was last updated
  static String showLastUpdated(Harvester client, int farmersCount, int harvestersCount) {
    String output = '\n';
    String count = "--"; // -- is last updated split character
    count += (harvestersCount > 0 || farmersCount > 0)
        ? "${farmersCount} farmers, " + harvestersCount.toString() + " harvesters - "
        : "";
    Duration difference = DateTime.now().difference(client.lastUpdated);
    if (difference.inSeconds >= 60) {
      output += count + "updated " + difference.inMinutes.toString() + " minutes ago";
    } else {
      output += count + "updated " + difference.inSeconds.toString() + " seconds ago";
    }
    return output;
  }

//Returns sum of size of plots in a given list
  static int plotSumSize(List<Plot> plots) {
    int totalSize = 0;

    for (int i = 0; i < plots.length; i++) totalSize += plots[i].size;

    return totalSize;
  }

  //Returns number of plots finished n days ago
  static List<Plot> plotsNDaysAgo(Harvester client, int n) {
    return client.plots.where((plot) => plot.date == nDaysAgoString(client, n)).toList();
  }

//Makes an n days ago string based on farmer's timezone
  static String nDaysAgoString(Harvester client, int n) {
    DateTime clientToday = stringToDate(client.lastUpdatedString);

    DateTime nDaysAgo = clientToday.subtract(Duration(days: n));

    return dateToString(nDaysAgo);
  }

//Estimates ETW in days
//Decimals are more precise (in theory)
  static double estimateETW(Harvester client, String networkSize) {
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

//Converts a dart duration to something human-readable
  static String durationToTime(Duration duration) {
    String day = (duration.inDays == 0) ? "" : duration.inDays.toString();
    String hour =
        (duration.inHours == 0) ? "" : (duration.inHours - 24 * duration.inDays).toString();
    String minute = (duration.inMinutes - duration.inHours * 60).toString();

    day = twoDigits(day) + ((day == "") ? "" : "d ");
    hour = twoDigits(hour) + ((hour == "") ? "" : "h ");
    minute = (minute == "0") ? '' : twoDigits(minute) + "m ";

    return day + hour + minute;
  }

//Used by durationToTime to always show 2 digits example 09m
  static String twoDigits(String input) {
    return (input.length == 1) ? "0" + input : input;
  }

  static Duration averagePlotDuration(List<Plot> lastNPlots) {
    int totalTime = 0;
    int avgTime = 0;

    lastNPlots.forEach((plot) {
      totalTime += plot.duration.inMilliseconds;
    });

    avgTime = totalTime ~/ lastNPlots.length;

    Duration averageDuration = Duration(milliseconds: avgTime);

    return averageDuration;
  }

//Duration between first plot started being plotted and last plot is completed
  static Duration farmedTime(List<Plot> plots) {
    return lastPlot(plots).end.difference(firstPlot(plots).begin);
  }

//Duration between first plot is completed and current time
// NEED TO CHANGE THIS FUNCTION'S NAME BUT I DONT KNOW A BETTER NAME
  static Duration farmingTime(List<Plot> plots) {
    return DateTime.now().difference(firstPlot(plots).end);
  }

//Human readable n days ago string seen above
  static String humanReadableDate(String ndaysago) {
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
}
