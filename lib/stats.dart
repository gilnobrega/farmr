import 'package:chiabot/harvester.dart';
import 'package:chiabot/farmer.dart';
import 'package:chiabot/plot.dart';
import 'package:chiabot/price.dart';

import 'dart:math' as Math;

class Stats {
  static String showName(Harvester harvester, [int count = null]) {
    String name = harvester.name + ((count == null) ? '' : count.toString());

    return ":farmer: **${name}**";
  }

  static String showPlotsInfo(Harvester client) {
    //sums size occupied by plots
    int plotsSize = plotSumSize(client.plots);
    //total space available
    String totalSizeString = fileSize(client.freeDiskSpace + plotsSize);
    String totalSizeUnits = totalSizeString.split(' ')[1];
    //total space used by plots
    String plotsSizeString = fileSize(plotsSize);
    String plotsSizeUnits = plotsSizeString.split(' ')[1];

    //displays 15/16TiB when both units match
    String plotInfo = (client.supportDiskSpace && totalSizeUnits == plotsSizeUnits)
        ? plotsSizeString.split(' ')[0]
        : plotsSizeString;

    if (client.supportDiskSpace) {
      double percentage = (plotsSize / (client.freeDiskSpace + plotsSize)) * 100;
      String percentageString = "(" + percentage.toStringAsFixed(0) + "%)";
      plotInfo += "/" + totalSizeString + " " + percentageString; //if farm supports disk space then
    }

    return "\n:tractor: **" + client.plots.length.toString() + " plots** - " + plotInfo + "";
  }

  static String showBalance(Harvester client, double price) {
    String output = '';

    if (client is Farmer && client.status != "Farming")
      output += "\n:warning: **${client.status}** :warning:";

    //Farmed balance
    double balance = (client is Farmer) ? client.balance : -1.0;
    double balanceUSD = balance * price;

    String balanceText = '';

    String priceText = (price > 0) ? " (${balanceUSD.toStringAsFixed(2)} ${client.currency})" : '';

    balanceText += (balance >= 0.0)
        ? "\n\<:chia:833767070201151528> **${balance}** **XCH**" + priceText
        : ''; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

    output += balanceText;

    //Wallet balance
    double walletBalance = (client is Farmer) ? client.wallet.balance : -1.0;
    double walletBalanceUSD = walletBalance * price;

    String walletPriceText =
        (price > 0) ? "(${walletBalanceUSD.toStringAsFixed(2)} ${client.currency})" : '';

    String walletBalanceText =
        (client is Farmer && walletBalance >= 0.0 && client.wallet.balance != client.balance)
            ? "\n:credit_card: ${client.wallet.balance} XCH ${walletPriceText}"
            : '';

    output += walletBalanceText;

    return output;
  }

  static String showETWEDV(Harvester client, String networkSize, double price, bool full) {
    String output = '';
    double etw = estimateETW(client, networkSize);

    if (etw > 0) {
      String etwString = "\n:moneybag: ETW: ${etw.toStringAsFixed(1)} days";
      if (price > 0) {
        final double blockSize = 2.0;
        double XCHPerDay = blockSize / etw;
        double epd = estimateEDV(etw, price);
        etwString +=
            " EDV: ${XCHPerDay.toStringAsPrecision(3)} XCH (${epd.toStringAsFixed(2)}${Price.currencies[client.currency]})";
      }

      output += etwString;
    }

    if (client.plots.length > 0 && full) {
      double farmedTimeDays = (farmedTime(client.plots).inHours / 24.0);

      double effort =
          (client is Farmer) ? client.wallet.getCurrentEffort(etw, farmedTimeDays) : 0.0;
      int daysAgo = (client is Farmer) ? client.wallet.daysSinceLastBlock.round() : 0;

      if (effort > 0.0) {
        //doesnt show last block days ago if user has not found a block at all
        String lastBlock = (farmedTimeDays > daysAgo) ? "(last block ~${daysAgo} days ago)" : '';
        output += "\n:person_lifting_weights: Effort: ${effort.toStringAsFixed(1)}% ${lastBlock}";
      }
    }

    return output;
  }

  static String showLastPlotInfo(Harvester client) {
    String output = '';

    if (client.plots.length > 0) {
      Plot plot = lastPlot(client.plots.where((plot) => plot.duration.inMinutes > 0).toList());
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

  //Counts types of plots, k32, k33, etc.
  static String showPlotTypes(Harvester client) {
    String output = '';
    List<Plot> plots = client.plots;

    if (plots.length > 0) {
      output += '\n\n:abacus: Types: ';

      //creates a map with the following structure { 'k32' : 3, 'k33' : 2 } etc.
      Map<String, int> typeCount = {};

      for (Plot plot in plots) {
        String type = plot.plotSize;
        if (type.startsWith("k")) {
          typeCount.putIfAbsent(type, () => 0);
          typeCount.update(type, (value) => value + 1);
        }
      }

      for (var type in typeCount.entries) {
        //adds comma if not the last key
        String comma = (typeCount.entries.last.key != type.key) ? ', ' : '';
        output += "${type.value} ${type.key} plots" + comma;
      }
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
    String output = '';

    if (weekCount > 0) {
      //Calculates when it will run out of space based on last week's statistics
      int outOfSpaceHours =
          (weekSize > 0) ? ((client.freeDiskSpace / weekSize) * daysWithPlots * 24).round() : 0;
      String outOfSpace = durationToTime(Duration(hours: outOfSpaceHours));

      output += "\n\nLast week: completed ${weekCount.toString()} plots";

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

      //displays number of proofs found if > 0
      if (harvester.proofsFound > 0) output += "\nFound ${harvester.proofsFound} proofs";

      double totalPlots =
          (harvester.totalPlots > 0) ? harvester.totalPlots : (harvester.plots.length / 1.0);

      //Calculates ratio based on each harvesters proportion (farmer's filterRatio)
      double ratio = (harvester is Farmer && harvester.filterRatio > 0)
          ? harvester.filterRatio / totalPlots
          : (totalEligiblePlots / harvester.numberFilters * 512 / totalPlots);
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

      if (harvester.maxTime >= 30) {
        output += "\n:warning: **Missed ${harvester.missedChallenges} challenges** :warning:";
        output += "\nFailed challenges with response times > 30 seconds";
      }

      if (harvester.filterCategories.isNotEmpty) {
        output += '\n';
        var list = harvester.filterCategories.entries.toList();

        //orders entries by doubles in ranges
        list.sort((entry1, entry2) => double.parse(entry1.key.split('-')[0])
            .compareTo(double.parse(entry2.key.split('-')[0])));

        //sums percentage and then assumes missing % comes from challenges with 0s
        double totalPercentage = 0 + 100 * (harvester.missedChallenges / harvester.numberFilters);
        List<String> lines = [];
        for (var entry in list) {
          //adds comma if not the last key
          double percentage = 100 * (entry.value / harvester.numberFilters);

          totalPercentage += percentage;

          String percentageString = percentage.toStringAsPrecision(3);
          String newline = (list.last.key != entry.key) ? '\n' : '';
          lines.add("${entry.key}s: ${entry.value} filters (${percentageString}%)" + newline);
        }

        //if total percentage doesnt add up to 100% then it assumes its missing filters with 0s
        //NASTY FIX FOR OLD CLIENTS WITH 0.0000s bug (only affects windows afaik)
        if (totalPercentage < 99) {
          int firstCategory =
              list.first.value + (harvester.numberFilters * (100 - totalPercentage) / 100).floor();
          double percentage = 100 * (firstCategory / harvester.numberFilters);
          String percentageString = percentage.toStringAsPrecision(3);

          String newline = (list.last.key != list.first.key) ? '\n' : '';
          lines.first =
              "${list.first.key}s: ${firstCategory} filters (${percentageString}%)" + newline;
        }

        if (harvester.missedChallenges > 0) {
          double missedPercentage = 100 * (harvester.missedChallenges / harvester.numberFilters);
          String missedPercentageText = missedPercentage.toStringAsPrecision(3);

          lines.add("\n>30s: ${harvester.missedChallenges} filters (${missedPercentageText}%)");
        }

        for (String line in lines) output += line;
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
    String count = "--"; // '--' is 'last updated' split character to be used in discord bot
    count += (harvestersCount > 0 || farmersCount > 0)
        ? "${farmersCount} farmers, " + harvestersCount.toString() + " harvesters - "
        : "";

    //client version
    String version = (client.version != '' && count == '--') ? " - v${client.version}" : '';

    Duration difference = DateTime.now().difference(client.lastUpdated);
    if (difference.inSeconds >= 60) {
      output += count + "updated " + difference.inMinutes.toString() + " minutes ago" + version;
    } else {
      output += count + "updated " + difference.inSeconds.toString() + " seconds ago" + version;
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

  //estimated price per day
  static double estimateEDV(double etw, double price) {
    final double blockSize = 2.0;
    return blockSize * price / etw;
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

//Duration between first plot is completed and current time
// NEED TO CHANGE THIS FUNCTION'S NAME BUT I DONT KNOW A BETTER NAME
  static Duration farmingTime(List<Plot> plots) {
    Duration duration1 = DateTime.now().difference(firstPlot(plots).begin);
    Duration duration2 = DateTime.now().difference(firstPlot(plots).end);

    if (duration1.inMilliseconds > duration2.inMilliseconds)
    return duration1;
    else 
    return duration2;
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
