import 'package:chiabot/harvester.dart';
import 'package:chiabot/harvester/plots.dart';
import 'package:chiabot/farmer.dart';
import 'package:chiabot/plot.dart';
import 'package:chiabot/server/price.dart';
import 'package:chiabot/server/netspace.dart';
import 'package:chiabot/log/shortsync.dart';

import 'package:chiabot/extensions/swarpm.dart';

class Stats {
  Farmer _client;
  Rate _price;
  NetSpace _netSpace;

  //name of client
  String get name => _client.name;
  String get status => (_client is Farmer) ? _client.status : 'Harvesting';
  Map<String, int> get typeCount => _client.typeCount;

  // FARMED BALANCE
  String get currency => _client.currency;
  double get balance => (_client is Farmer) ? _client.balance : 0.0;
  double get balanceFiat => (_client is Farmer) ? balance * _price.rate : 0.0;

  // WALLET BALANCE
  double get walletBalance =>
      (_client is Farmer) ? _client.wallet.balance : 0.0;
  double get walletBalanceFiat =>
      (_client is Farmer) ? walletBalance * _price.rate : 0.0;
  double get walletBalanceFiatChange =>
      (_client is Farmer) ? walletBalanceFiat * _price.change : 0.0;

  //PLOTS
  //total number of plots (complete plots)
  int get numberOfPlots => _client.plots.length;

  //DRIVES
  bool get supportDiskSpace => (_client.supportDiskSpace);
  //sums size occupied by plots
  int get plotsSize => plotSumSize(_client.plots);
  String get plottedSpace => fileSize(plotsSize);
  //total space available
  int get totalSize => _client.freeDiskSpace + plotsSize;
  String get totalSpace => fileSize(totalSize);

  //ETW AND EDV
  double get etw => estimateETW(_client, _netSpace);
  final double blockSize = 2.0;
  double get edv => blockSize / etw;
  double get edvFiat => estimateEDV(etw, _price.rate);

  //EFFORT
  Duration get farmedDuration => (farmedTime(_client.plots));
  double get farmedDays => (farmedDuration.inHours / 24.0);
  double get effort => _client.wallet.getCurrentEffort(etw, farmedDays);
  double get daysSinceLastBlock =>
      _client.wallet.daysSinceLastBlock.roundToDouble();

  String get netSpace => _netSpace.humanReadableSize;
  String get netSpaceGrowth => _netSpace.dayDifference;

  int get fullNodesConnected => _client.fullNodesConnected;

  Stats(this._client, this._price, this._netSpace);

  static String showName(Harvester harvester, [int count]) {
    String name = harvester.name + ((count == null) ? '' : count.toString());

    return ":farmer: **$name**";
  }

  static String showPlotsInfo(Stats stats) {
    String totalSizeUnits = stats.totalSpace.split(' ')[1];
    //total space used by plots
    String plotsSizeUnits = stats.plottedSpace.split(' ')[1];

    //displays 15/16TiB when both units match
    String plotInfo =
        (stats.supportDiskSpace && totalSizeUnits == plotsSizeUnits)
            ? stats.plottedSpace.split(' ')[0]
            : stats.plottedSpace;

    if (stats.supportDiskSpace) {
      double percentage = (stats.plotsSize / (stats.totalSize)) * 100;
      String percentageString = "(" + percentage.toStringAsFixed(0) + "%)";
      plotInfo += "/" +
          stats.totalSpace +
          " " +
          percentageString; //if farm supports disk space then
    }

    return "\n:tractor: **" +
        stats.numberOfPlots.toString() +
        " plots** - " +
        plotInfo +
        "";
  }

  static String showBalance(Stats stats) {
    String output = '';

    if (stats.status != "Farming")
      output += "\n:warning: **${stats.status}** :warning:";

    String balanceText = '';

    String priceText = (stats.balanceFiat > 0)
        ? " (${stats.balanceFiat.toStringAsFixed(2)} ${stats.currency})"
        : '';

    balanceText += (stats.balance >= 0.0)
        ? "\n\<:chia:833767070201151528> **${stats.balance}** **XCH**" +
            priceText
        : ''; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

    output += balanceText;

    String sign = (stats.walletBalanceFiatChange >= 0) ? '+' : '-';

    String walletPriceText = (stats.walletBalanceFiat > 0)
        ? "(${stats.walletBalanceFiat.toStringAsFixed(2)} ${stats.currency}, $sign${stats.walletBalanceFiatChange.abs().toStringAsFixed(2)}${Price.currencies[stats.currency]})"
        : '';

    String walletBalanceText =
        (stats.walletBalance >= 0.0 && stats.walletBalance != stats.balance)
            ? "\n:credit_card: ${stats.walletBalance} XCH $walletPriceText"
            : '';

    output += walletBalanceText;

    return output;
  }

  static String showETWEDV(Stats stats, bool full) {
    String output = '';

    if (stats.etw > 0) {
      String etwValue = "${stats.etw.toStringAsFixed(1)} days";

      //if shorter than a  day then display value in hours
      if (stats.etw < 1)
        etwValue = "${(stats.etw * 24).toStringAsFixed(1)} hours";

      String etwString = "\n:moneybag: ETW: $etwValue";

      if (stats.balanceFiat > 0) {
        etwString +=
            " EDV: ${stats.edv.toStringAsPrecision(3)} XCH (${stats.edvFiat.toStringAsFixed(2)}${Price.currencies[stats.currency]})";
      }

      output += etwString;
    }

    if (stats.numberOfPlots > 0 && full) {
      if (stats.effort > 0.0) {
        //doesnt show last block days ago if user has not found a block at all
        String lastBlock = (stats.farmedDays > stats.daysSinceLastBlock)
            ? "(last block ~${stats.daysSinceLastBlock} days ago)"
            : '';
        output +=
            "\n:person_lifting_weights: Effort: ${stats.effort.toStringAsFixed(1)}% $lastBlock";
      }
    }

    return output;
  }

  static String showLastPlotInfo(Harvester client) {
    String output = '';

    if (client.plots.length > 0) {
      Plot plot = lastPlot(
          client.plots.where((plot) => plot.duration.inMinutes > 0).toList());
      Duration average = averagePlotDuration(
          client.plots.where((plot) => plot.duration.inMinutes > 0).toList());

      //relative difference in % of plot duration vs average plot duration
      double ratio =
          1 - (plot.duration.inMilliseconds / average.inMilliseconds);
      String difference = (ratio > 0)
          ? (ratio * 100).toStringAsFixed(0) + "% below Ø"
          : (-ratio * 100).toStringAsFixed(0) + "% above Ø";

      output += "\n:hourglass: Last plot length: **" +
          durationToTime(plot.duration) +
          "** " +
          "(" +
          difference +
          ")";
      Duration finishedAgo =
          DateTime.now().difference(lastPlot(client.plots).end);

      //If the finished timestamp is less than 1 minute ago then it assumes it's still copying the plot to the destination
      String finishedAgoString = (finishedAgo.inMinutes == 0)
          ? "(moving to destination)"
          : ("(completed " + durationToTime(finishedAgo) + "ago)");

      output += "\n\<:hdd:831678109018751037> Size: " +
          fileSize(plot.size, 1) +
          " " +
          finishedAgoString;
    }

    return output;
  }

  static String showNetworkSize(Stats stats) {
    String output = '';

    String growth = "(${stats.netSpaceGrowth})";
    output += "\n:satellite: Netspace: ${stats.netSpace} $growth";

    return output;
  }

  static String showFarmedTime(Stats stats) {
    String output = '';
    if (stats.numberOfPlots > 0) {
      double chiaPerDay = (stats.balance / stats.farmedDays);

      //hides balance if client is harvester or if it's farmer and showBalance is false
      String chiaPerDayString = (stats.balance < 0.0)
          ? "" //for some reason needs a new line here
          : "(" +
              chiaPerDay.toStringAsFixed(2) +
              " XCH per day)"; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

      output += "\n:clock10: Farmed for " +
          durationToTime(stats.farmedDuration) +
          " " +
          chiaPerDayString;
    }
    return output;
  }

  //Counts types of plots, k32, k33, etc.
  static String showPlotTypes(Harvester client) {
    String output = '';
    List<Plot> plots = client.plots;

    if (plots.length > 0) {
      output += '\n\n:abacus: Types: ';

      var entries = client.typeCount.entries.toList();
      entries.sort((entry1, entry2) => entry1.key.compareTo(entry2.key));

      for (var type in entries) {
        //adds comma if not the last key
        String comma = (entries.last.key != type.key) ? ', ' : '';
        output += "${type.value} ${type.key} plots" + comma;
      }
    }

    return output;
  }

  static String showLastNDaysPlots(
      Harvester client, int daysAgo, NetSpace netSpace) {
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
        String day = "Today";

        Map<String, int> typeCount = HarvesterPlots.genPlotTypes(plots);
        String types = '';

        var entries = typeCount.entries.toList();

        entries.sort((entry1, entry2) => entry1.key.compareTo(entry2.key));

        if (entries.length > 1) {
          types = '(';

          for (var type in entries) {
            //adds comma if not the last key
            String comma = (entries.last.key != type.key) ? ', ' : ')';
            types += "${type.value}x${type.key}" + comma;
          }
        } else if (typeCount.entries.length == 1)
          types += "(all ${typeCount.entries.first.key})";

        if (k > 0) {
          day = "${humanReadableDate(nDaysAgoString(client, k))}";
          weekCount += count;
          weekSize += sumSize;
          daysWithPlots += 1;
        }

        text += "\n$day: completed $count plots $types";

        text += " (${fileSize(sumSize, 1)})";
      }
    }

    if (netSpace.pastSizes.entries.length > 7) {
      var entries = netSpace.pastSizes.entries.toList();
      entries.sort((entry1, entry2) =>
          int.parse(entry2.key).compareTo(int.parse(entry1.key)));

      double ratio = (entries.first.value / entries[6].value - 1);

      //shows number of plots client needs to plot to keep up with netspace growth
      if (ratio > 0) {
        int plotsPerDay = (ratio * client.plots.length / 7).ceil();
        text +=
            "\nNeed $plotsPerDay plots per day to keep up with Netspace growth";
      }
    }

    text += showWeekPlots(client, weekCount, weekSize, daysWithPlots);

    return text;
  }

  static String showWeekPlots(
      Harvester client, int weekCount, int weekSize, int daysWithPlots) {
    String output = '';

    if (weekCount > 0) {
      //Calculates when it will run out of space based on last week's statistics
      int outOfSpaceHours = (weekSize > 0)
          ? ((client.freeDiskSpace / weekSize) * daysWithPlots * 24).round()
          : 0;
      String outOfSpace = durationToTime(Duration(hours: outOfSpaceHours));

      output += "\n\nLast week: completed ${weekCount.toString()} plots";

      if (client.supportDiskSpace) {
        //If free space is less than a k32 plot size
        if (client.freeDiskSpace > 0 && client.freeDiskSpace < 1.1e9)
          output += "\n:warning: **OUT OF SPACE** :warning:";
        if (client.freeDiskSpace > 0 && weekSize > 0)
          output += "\nOut of space in $outOfSpace";
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
      output += "\nLast 7 days: " +
          (weekAverage).toStringAsFixed(2) +
          " plots per day";

      Duration avg = averagePlotDuration(client.plots);

      output += "\nAll time average plot length: " + durationToTime(avg);
    }

    return output;
  }

  static String showIncompletePlotsWarning(Harvester client) {
    String output = '';
    //If found incomplete plots then it will show this warning below
    if (client.incompletePlots.length > 0) {
      output =
          "\n**${client.incompletePlots.length}** potentially incomplete plots";
    }

    return output;
  }

  static String showFilters(Harvester harvester) {
    String output = '';
    if (harvester.numberFilters > 0) {
      int totalEligiblePlots = harvester.eligiblePlots;
      output +=
          "\n\nLast 24 hours: $totalEligiblePlots plots passed ${harvester.numberFilters} filters";

      //displays number of proofs found if > 0
      if (harvester.proofsFound > 0)
        output += "\nFound ${harvester.proofsFound} proofs";

      double totalPlots = (harvester.totalPlots > 0)
          ? harvester.totalPlots
          : (harvester.plots.length / 1.0);

      //Calculates ratio based on each harvesters proportion (farmer's filterRatio)
      double ratio = (harvester is Farmer && harvester.filterRatio > 0)
          ? harvester.filterRatio / totalPlots
          : (totalEligiblePlots / harvester.numberFilters * 512 / totalPlots);
      String ratioString = ratio.toStringAsFixed(2);
      String luck = ((ratio) * 100).toStringAsFixed(0) + "%";

      output += "\nEach plot passed $ratioString times per 512 filters";
      output += "\n24h Efficiency: **$luck**";

      output += "\n\nLongest response: **${harvester.maxTime}** seconds";
      output += "\nShortest response: ${harvester.minTime} seconds";

      int decimals = 3;

      if (harvester.medianTime > 0 || harvester.avgTime > 0)
        output +=
            "\nMedian: ${harvester.medianTime.toStringAsFixed(decimals)}s Avg: ${harvester.avgTime.toStringAsFixed(decimals)}s σ: ${harvester.stdDeviation.toStringAsFixed(decimals)}s";

      if (harvester.maxTime >= 30) {
        output +=
            "\n:warning: **Missed ${harvester.missedChallenges} challenges** :warning:";
        output += "\nFailed challenges with response times > 30 seconds";
      }

      if (harvester.filterCategories.isNotEmpty) {
        output += '\n';
        var list = harvester.filterCategories.entries.toList();

        //orders entries by doubles in ranges
        list.sort((entry1, entry2) => double.parse(entry1.key.split('-')[0])
            .compareTo(double.parse(entry2.key.split('-')[0])));

        //sums percentage and then assumes missing % comes from challenges with 0s
        double totalPercentage =
            0 + 100 * (harvester.missedChallenges / harvester.numberFilters);
        List<String> lines = [];
        for (var entry in list) {
          //adds comma if not the last key
          double percentage = 100 * (entry.value / harvester.numberFilters);

          totalPercentage += percentage;

          String percentageString = percentage.toStringAsPrecision(3);
          String newline = (list.last.key != entry.key) ? '\n' : '';
          lines.add(
              "${entry.key}s: ${entry.value} filters ($percentageString%)" +
                  newline);
        }

        //if total percentage doesnt add up to 100% then it assumes its missing filters with 0s
        //NASTY FIX FOR OLD CLIENTS WITH 0.0000s bug (only affects windows afaik)
        if (totalPercentage < 99) {
          int firstCategory = list.first.value +
              (harvester.numberFilters * (100 - totalPercentage) / 100).floor();
          double percentage = 100 * (firstCategory / harvester.numberFilters);
          String percentageString = percentage.toStringAsPrecision(3);

          String newline = (list.last.key != list.first.key) ? '\n' : '';
          lines.first =
              "${list.first.key}s: $firstCategory filters ($percentageString%)" +
                  newline;
        }

        if (harvester.missedChallenges > 0) {
          double missedPercentage =
              100 * (harvester.missedChallenges / harvester.numberFilters);
          String missedPercentageText = missedPercentage.toStringAsPrecision(3);

          lines.add(
              "\n>30s: ${harvester.missedChallenges} filters ($missedPercentageText%)");
        }

        for (String line in lines) output += line;
      }
    }

    return output;
  }

  static String showFullNodeStats(Harvester harvester) {
    String output = '';
    output += "\n*Full Node Stats*";

    if (harvester is Farmer && harvester.completeSubSlots > 0) {
      int totalSignagePoints =
          (64 * harvester.completeSubSlots) + harvester.looseSignagePoints;

      double ratio = harvester.looseSignagePoints / (totalSignagePoints);

      String percentage = (ratio * 100).toStringAsFixed(2);

      output += "\n${harvester.completeSubSlots} complete Sub Slots";
      output += "\n$percentage% orphan Signage Points";
    }

    if (harvester is Farmer && harvester.shortSyncs.length > 0) {
      int events = harvester.shortSyncs.length;

      //sums al lengths of short sync events
      int totalBlocksSkipped = ShortSync.skippedBlocks(harvester.shortSyncs);

      output +=
          "\n:warning: **Lost sync $events times**, skipped $totalBlocksSkipped blocks";

      for (ShortSync shortSync in harvester.shortSyncs)
        output +=
            "\n${shortSync.localTime} from block ${shortSync.start} to ${shortSync.end}";
    }

    if (harvester is Farmer && harvester.fullNodesConnected > 0) {
      output += "\nConnected to ${harvester.fullNodesConnected} peers";
    }

    return output;
  }

//Shows harvester count and when farm was last updated
  static String showLastUpdated(
      Harvester client, int farmersCount, int harvestersCount) {
    String output = '\n';
    String count =
        "--"; // '--' is 'last updated' split character to be used in discord bot
    count += (harvestersCount > 0 || farmersCount > 0)
        ? "$farmersCount farmers, $harvestersCount harvesters - "
        : "";

    //client version
    String version =
        (client.version != '' && count == '--') ? " - v${client.version}" : '';

    Duration difference = DateTime.now().difference(client.lastUpdated);
    if (difference.inSeconds >= 60) {
      output += count +
          "updated " +
          difference.inMinutes.toString() +
          " minutes ago" +
          version;
    } else {
      output += count +
          "updated " +
          difference.inSeconds.toString() +
          " seconds ago" +
          version;
    }
    return output;
  }

  static String showSwarPMJobs(Harvester client) {
    String output = '';

    if (client.swarPM != null && client.swarPM.jobs.length > 0) {
      output += "\n**Swar's Chia Plot Manager**";

      for (Job job in client.swarPM.jobs) {
        output +=
            "\n${job.number} ${job.name} ${job.elapsed} ${job.phase} ${job.phaseTimes} ${job.percentage} ${job.space}";
      }
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
    return client.plots
        .where((plot) => plot.date == nDaysAgoString(client, n))
        .toList();
  }

//Makes an n days ago string based on farmer's timezone
  static String nDaysAgoString(Harvester client, int n) {
    DateTime clientToday = stringToDate(client.lastUpdatedString);

    DateTime nDaysAgo = clientToday.subtract(Duration(days: n));

    return dateToString(nDaysAgo);
  }

//Estimates ETW in days
//Decimals are more precise (in theory)
  static double estimateETW(Harvester client, NetSpace netSpace) {
    double networkSizeBytes = (netSpace.size * 1.0);

    int size = plotSumSize(client.plots);

    double blocks = 32.0; //32 blocks per 10 minutes

    double calc = (networkSizeBytes / size) / (blocks * 6.0 * 24.0);

    return calc;
  }

  //estimated price per day
  static double estimateEDV(double etw, double price) {
    final double blockSize = 2.0;
    return blockSize * price / etw;
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
  static Duration farmedTime(List<Plot> plots) {
    Duration duration1 = DateTime.now().difference(firstPlot(plots).begin);
    Duration duration2 = DateTime.now().difference(firstPlot(plots).end);

    if (duration1.inMilliseconds > duration2.inMilliseconds)
      return duration1;
    else
      return duration2;
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
