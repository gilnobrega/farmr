import 'package:farmr_client/foxypool/foxypoolog.dart';
import 'package:farmr_client/foxypool/wallet.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/harvester/plots.dart';
import 'package:farmr_client/farmer/farmer.dart';
import 'package:farmr_client/hpool/hpool.dart';
import 'package:farmr_client/hpool/wallet.dart';
import 'package:farmr_client/plot.dart';
import 'package:farmr_client/server/price.dart';
import 'package:farmr_client/server/netspace.dart';
import 'package:farmr_client/log/shortsync.dart';

import 'package:farmr_client/extensions/swarpm.dart';

class Stats {
  Harvester _client; //Either a Farmer or Harvester
  Rate? _price;
  NetSpace _netSpace;

  //name of client
  String get name => _client.name;
  String get status => _client.status;

  Map<String, int> get typeCount => _client.typeCount;

  // FARMED BALANCE
  String get crypto => _client.crypto;
  String get currency => _client.currency;

  double get blockRewards => _client.blockRewards;
  double get blocksPer10Mins => _client.blocksPer10Mins;

  double get balance =>
      (_client is Farmer) ? (_client as Farmer).balance : -1.0;
  double get balanceFiat => calculateFiat(balance, _price, crypto);

  static double calculateFiat(double balance, Rate? price, String crypto) =>
      (crypto == "xch") ? balance * (price?.rate ?? 0.0) : 0.0;

  static double calculateFiatChange(double balanceFiat, Rate? price) =>
      balanceFiat * (price?.change ?? 0.0);

  // WALLET BALANCE
  double get walletBalance =>
      (_client is Farmer) ? (_client as Farmer).wallet.balance : -1.0;
  double get walletBalanceFiat => calculateFiat(walletBalance, _price, crypto);
  double get walletBalanceFiatChange =>
      calculateFiatChange(walletBalanceFiat, _price);

  // COLD BALANCE
  double get coldGrossBalance =>
      (_client is Farmer) ? (_client as Farmer).coldWallet.grossBalance : -1.0;
  double get coldGrossBalanceFiat =>
      calculateFiat(coldGrossBalance, _price, crypto);

  double get coldNetBalance =>
      (_client is Farmer) ? (_client as Farmer).coldWallet.netBalance : -1.0;
  double get coldNetBalanceFiat =>
      calculateFiat(coldNetBalance, _price, crypto);
  double get coldNetBalanceFiatChange =>
      calculateFiatChange(coldNetBalanceFiat, _price);

  //HPool Wallet
  double get undistributedBalance => (_client is HPool)
      ? ((_client as HPool).wallet as HPoolWallet).undistributedBalance
      : -1.0;
  double get undistributedBalanceFiat =>
      calculateFiat(undistributedBalance, _price, crypto);
  double get undistributedBalanceFiatChange =>
      calculateFiatChange(undistributedBalanceFiat, _price);

  //FoxyPool Wallet
  double get pendingBalance => (_client is FoxyPoolOG)
      ? ((_client as FoxyPoolOG).wallet as FoxyPoolWallet).pendingBalance
      : -1.0;
  double get pendingBalanceFiat =>
      calculateFiat(pendingBalance, _price, crypto);
  double get pendingBalanceFiatChange =>
      calculateFiatChange(pendingBalanceFiat, _price);

  double get collateralBalance => (_client is FoxyPoolOG)
      ? ((_client as FoxyPoolOG).wallet as FoxyPoolWallet).collateralBalance
      : -1.0;
  double get collateralBalanceFiat =>
      calculateFiat(collateralBalance, _price, crypto);
  double get collateralBalanceFiatChange =>
      calculateFiatChange(collateralBalanceFiat, _price);

  //PLOTS
  //total number of plots (complete plots)
  int get numberOfPlots => _client.plots.length;
  Duration get averagePlotLength => averagePlotDuration(_client.plots);

  //DRIVES
  int get drivesCount => (_client.drivesCount);
  int get totalDriveSize => (_client.totalDiskSpace);
  String get totalDriveSpace => fileSize(totalDriveSize);

  bool get supportDiskSpace => (_client.supportDiskSpace);
  //sums size occupied by plots
  int get plotsSize => plotSumSize(_client.plots);
  String get plottedSpace => fileSize(plotsSize);
  //free space
  int get freeSize => _client.freeDiskSpace;
  //total space (used + available)
  int get totalSize => freeSize + plotsSize;
  String get totalSpace => fileSize(totalSize);

  //OUT OF SPACE STATS (based on 7 days average)
  int get plotsLastWeek => countPlotsLastWeek(_client);
  int get plotsSizeLastWeek => countPlotsSizeLastWeek(_client);
  int get daysWithPlotsLastWeek => countDaysWithPlotsLastWeek(_client);
  Duration get outOfSpace => (plotsLastWeek > 0)
      ? Duration(
          hours: ((_client.freeDiskSpace / plotsSizeLastWeek) *
                  daysWithPlotsLastWeek *
                  24)
              .round())
      : Duration(hours: 0);
  String get outOfSpaceString =>
      (plotsLastWeek > 0) ? durationToTime(outOfSpace) : '';

  //EARNINGS
  double get etw => estimateETW(_client, _netSpace);
  double get edv => blockRewards / etw; //daily
  double get edvFiat => calculateFiat(edv, _price, crypto);
  double get ewv => edv * 7; //weekly
  double get ewvFiat => calculateFiat(ewv, _price, crypto);
  double get emv => edv * 30; //monthly
  double get emvFiat => calculateFiat(emv, _price, crypto);

  //EFFORT
  Duration get farmedDuration {
    late Duration duration;
    try {
      duration = farmedTime(_client.plots);
    } catch (err) {
      duration = Duration(seconds: 0);
    }

    return duration;
  }

  double get farmedDays => (farmedDuration.inHours / 24.0);
  double get effort => (_client is Farmer)
      ? (_client as Farmer).wallet.getCurrentEffort(etw, farmedDays)
      : 0.0;
  double get daysSinceLastBlock => (_client is Farmer)
      ? (_client as Farmer).wallet.daysSinceLastBlock.roundToDouble()
      : 0;

  String get netSpace => _netSpace.humanReadableSize;
  String get netSpaceGrowth => _netSpace.dayDifference;

  DateTime get currentDay => stringToDate(_client.lastUpdatedString);

  //Filter stats
  double get avgPlots => (_client.totalPlots > 0)
      ? _client.totalPlots
      : (_client.plots.length / 1.0);
  int get numberFilters => _client.numberFilters;
  int get eligiblePlots => _client.eligiblePlots;
  int get proofsFound => _client.proofsFound;
  int get missedChallenges => _client.missedChallenges;

  //Calculates ratio based on each harvesters proportion (farmer's filterRatio)
  double get filterPassedRatio => (_client is Farmer && _client.filterRatio > 0)
      ? _client.filterRatio / avgPlots
      : (eligiblePlots / numberFilters * 512 / avgPlots);
  String get efficiency => (filterPassedRatio * 100).toStringAsFixed(0);

  //filter response times
  double get maxTime => _client.maxTime;
  double get minTime => _client.minTime;
  double get avgTime => _client.avgTime;
  double get medianTime => _client.medianTime;
  double get stdDeviation => _client.stdDeviation;

  //Full Node Stats
  int get fullNodesConnected =>
      (_client is Farmer) ? (_client as Farmer).fullNodesConnected : 0;
  int get completeSubSlots =>
      (_client is Farmer) ? (_client as Farmer).completeSubSlots : 0;
  int get looseSignagePoints =>
      (_client is Farmer) ? (_client as Farmer).looseSignagePoints : 0;
  int get totalSignagePoints => (64 * completeSubSlots) + looseSignagePoints;
  double get looseRatio => looseSignagePoints / totalSignagePoints;
  double get orderedRatio => 1 - looseRatio;
  String get loosePercentage => (looseRatio * 100).toStringAsFixed(1);
  String get orderedPercentage => (orderedRatio * 100).toStringAsFixed(1);

  int get shortSyncNumber =>
      (_client is Farmer) ? (_client as Farmer).shortSyncs.length : 0;
  int get shortSyncSkippedBlocks => (_client is Farmer)
      ? ShortSync.skippedBlocks((_client as Farmer).shortSyncs)
      : 0;
  String get shortSyncDescription {
    String output = '';
    if (_client is Farmer) {
      for (ShortSync shortSync in (_client as Farmer).shortSyncs)
        output +=
            "\n${shortSync.localTime} from block ${shortSync.start} to ${shortSync.end}";
    }
    return output;
  }

  //Hardware
  String get cpuName => ((_client.hardware?.cpus.length ?? 0) > 0)
      ? _client.hardware?.cpus[0].name ?? ""
      : "";
  int get cpuThreads => ((_client.hardware?.cpus.length ?? 0) > 0)
      ? _client.hardware?.cpus[0].threads ?? 0
      : 0;

  int get totalMemory => _client.hardware?.recentMemory.totalMemory ?? 0;
  int get freeMemory => _client.hardware?.recentMemory.freeMemory ?? 0;
  int get usedMemory => _client.hardware?.recentMemory.usedMemory ?? 0;

  double get usedMemoryRatio => usedMemory / totalMemory;
  String get usedMemoryPercentage =>
      ("${(usedMemoryRatio * 100).toStringAsFixed(1)}");

  String get totalMemoryString => fileSize(totalMemory);
  String get freeMemoryString => fileSize(freeMemory);
  String get usedMemoryString => fileSize(usedMemory);

  Stats(this._client, this._price, this._netSpace);

  static String showName(Harvester harvester, [int count = 0]) {
    String name = harvester.name + ((count == 0) ? '' : count.toString());

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

  static const normalStatus = const ["Harvesting", "Farming", "HPool"];

  static String showStatus(Stats stats) {
    String output = '';

    if (!normalStatus.contains(stats.status))
      output += "\n:warning: **${stats.status}** :warning:";

    return output;
  }

  static String showBalance(Stats stats, bool sumWithUnsettled) {
    //for hpool mode it combines settled and unsettled values in !chia
    //while it displays them separately in !full or !workers
    double balance = (stats.undistributedBalance > 0 && sumWithUnsettled)
        ? stats.balance + stats.undistributedBalance
        : stats.balance;
    double balanceFiat = (stats.undistributedBalance > 0 && sumWithUnsettled)
        ? stats.balanceFiat + stats.undistributedBalanceFiat
        : stats.balanceFiat;

    String output = '';

    String balanceText = '';

    String priceText = (balanceFiat > 0)
        ? " (${balanceFiat.toStringAsFixed(2)} ${stats.currency})"
        : '';

    balanceText += (balance >= 0.0)
        ? "\n\<:chia:833767070201151528> **${balance.toStringAsFixed(2)}** **${stats.crypto.toUpperCase()}**" +
            priceText
        : ''; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

    output += balanceText;

    return output;
  }

  static String showColdBalance(Stats stats) {
    String output = '';

    String balanceText = '';

    String priceText = (stats.coldNetBalanceFiat > 0)
        ? " (${stats.coldNetBalanceFiat.toStringAsFixed(2)} ${stats.currency})"
        : '';

    balanceText += (stats.coldNetBalance >= 0.0)
        ? "\n:cold_face: **${stats.coldNetBalance.toStringAsFixed(2)}** **${stats.crypto.toUpperCase()}**" +
            priceText
        : ''; //HIDES BALANCE IF NEGATIVE (MEANS USER DOES NOT HAVE COLD BALANCE)

    output += balanceText;

    return output;
  }

  static String showWalletBalance(Stats stats, bool sumWalletWithUnsettled) {
    //for hpool mode it combines settled and unsettled values in !chia
    //while it displays them separately in !full or !workers
    double walletBalance =
        (stats.undistributedBalance > 0 && sumWalletWithUnsettled)
            ? stats.walletBalance + stats.undistributedBalance
            : stats.walletBalance;
    double walletBalanceFiat =
        (stats.undistributedBalance > 0 && sumWalletWithUnsettled)
            ? stats.walletBalanceFiat + stats.undistributedBalanceFiat
            : stats.walletBalanceFiat;
    double walletBalanceFiatChange = (stats.undistributedBalance > 0 &&
            sumWalletWithUnsettled)
        ? stats.walletBalanceFiatChange + stats.undistributedBalanceFiatChange
        : stats.walletBalanceFiatChange;

    String output = '';

    String sign = (walletBalanceFiatChange >= 0) ? '+' : '-';

    String walletPriceText = (walletBalanceFiat > 0)
        ? "(${walletBalanceFiat.toStringAsFixed(2)} ${stats.currency}, $sign${walletBalanceFiatChange.abs().toStringAsFixed(2)}${Price.currencies[stats.currency]})"
        : '';

    String walletBalanceText = (walletBalance >= 0.0 &&
            stats.walletBalance != stats.balance)
        ? "\n:credit_card: $walletBalance ${stats.crypto.toUpperCase()} $walletPriceText"
        : '';

    output += walletBalanceText;

    return output;
  }

  static String showUndistributedBalance(Stats stats) {
    String output = '';

    String sign = (stats.undistributedBalanceFiatChange >= 0) ? '+' : '-';

    String undistributedPriceText = (stats.undistributedBalanceFiat > 0)
        ? "(${stats.undistributedBalanceFiat.toStringAsFixed(2)} ${stats.currency}, $sign${stats.undistributedBalanceFiatChange.abs().toStringAsFixed(2)}${Price.currencies[stats.currency]})"
        : '';

    String undistributedBalanceText = (stats.undistributedBalance >= 0.0 &&
            stats.undistributedBalance != stats.balance)
        ? "\n:grey_question: Unsettled: ${stats.undistributedBalance} ${stats.crypto.toUpperCase()} $undistributedPriceText"
        : '';

    output += undistributedBalanceText;

    return output;
  }

  static String showPendingBalance(Stats stats) {
    String output = '';

    String sign = (stats.pendingBalanceFiatChange >= 0) ? '+' : '-';

    String pendingPriceText = (stats.pendingBalanceFiat > 0)
        ? "(${stats.pendingBalanceFiat.toStringAsFixed(2)} ${stats.currency}, $sign${stats.pendingBalanceFiatChange.abs().toStringAsFixed(2)}${Price.currencies[stats.currency]})"
        : '';

    String pendingBalanceText = (stats.pendingBalance >= 0.0)
        ? "\n:grey_question: Pending: ${stats.pendingBalance} ${stats.crypto.toUpperCase()} $pendingPriceText"
        : '';

    output += pendingBalanceText;

    return output;
  }

  static String showCollateralBalance(Stats stats) {
    String output = '';

    String sign = (stats.collateralBalanceFiatChange >= 0) ? '+' : '-';

    String collateralPriceText = (stats.collateralBalanceFiat > 0)
        ? "(${stats.collateralBalanceFiat.toStringAsFixed(2)} ${stats.currency}, $sign${stats.collateralBalanceFiatChange.abs().toStringAsFixed(2)}${Price.currencies[stats.currency]})"
        : '';

    String collateralBalanceText = (stats.collateralBalance >= 0.0)
        ? "\n:grey_question: Collateral: ${stats.collateralBalance} ${stats.crypto.toUpperCase()} $collateralPriceText"
        : '';

    output += collateralBalanceText;

    return output;
  }

  static String showETWEDV(
      Stats stats, bool showLastBlock, bool showWeeklyAndMonthly) {
    String output = '';

    if (stats.etw > 0) {
      String etwValue = "${stats.etw.toStringAsFixed(1)} days";

      //if shorter than a  day then display value in hours
      if (stats.etw < 1)
        etwValue = "${(stats.etw * 24).toStringAsFixed(1)} hours";

      String etwString = "\n:moneybag: ETW: $etwValue";

      if (stats.edv > 0) {
        String edvType = (!showWeeklyAndMonthly) ? "EDV" : "\nDaily";
        etwString +=
            " $edvType: ${stats.edv.toStringAsPrecision(3)} ${stats.crypto.toUpperCase()} (${stats.edvFiat.toStringAsFixed(2)}${Price.currencies[stats.currency]})";

        if (showWeeklyAndMonthly) {
          etwString +=
              "\nWeekly: ${stats.ewv.toStringAsPrecision(3)} ${stats.crypto.toUpperCase()} (${stats.ewvFiat.toStringAsFixed(2)}${Price.currencies[stats.currency]})";

          etwString +=
              "\nMonthly: ${stats.emv.toStringAsPrecision(3)} ${stats.crypto.toUpperCase()} (${stats.emvFiat.toStringAsFixed(2)}${Price.currencies[stats.currency]})";
        }
      }

      output += etwString;
    }

    if (stats.numberOfPlots > 0 && showLastBlock) {
      if (stats.effort > 0.0) {
        //doesnt show last block days ago if user has not found a block at all
        String lastBlock = (stats.farmedDays > stats.daysSinceLastBlock)
            ? "(last block ~${stats.daysSinceLastBlock.round()} days ago)"
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

    if (stats.netSpace != "0.0 B") {
      String growth =
          (stats.netSpaceGrowth != "") ? "(${stats.netSpaceGrowth})" : "";
      output += "\n:satellite: Netspace: ${stats.netSpace} $growth";
    }

    return output;
  }

  static String showFarmedTime(Stats stats) {
    String output = '';
    if (stats.crypto.toLowerCase() == "xch" && stats.numberOfPlots > 0) {
      double chiaPerDay = (stats.balance / stats.farmedDays);

      //hides balance if client is harvester or if it's farmer and showBalance is false
      String chiaPerDayString = (stats.balance < 0.0)
          ? "" //for some reason needs a new line here
          : "(" +
              chiaPerDay.toStringAsFixed(2) +
              " ${stats.crypto.toUpperCase()} per day)"; //HIDES BALANCE IF NEGATIVE (MEANS USER DECIDED TO HIDE BALANCE)

      output += "\n:clock10: Farmed for " +
          durationToTime(stats.farmedDuration) +
          " " +
          chiaPerDayString;
    }
    return output;
  }

  static String showDrives(Stats stats) {
    String output = '\n';

    if (stats.drivesCount > 0)
      output += '\n${stats.drivesCount} drives connected';

    return output;
  }

  //Counts types of plots, k32, k33, etc.
  static String showPlotTypes(Harvester client) {
    String output = '';
    List<Plot> plots = client.plots;

    if (plots.length > 0) {
      output += '\n:abacus: ';

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

  static String showHardware(Stats stats) {
    String output = '';

    if (stats.cpuName != "")
      output += "\nCPU: ${stats.cpuName} with ${stats.cpuThreads} threads";
    if (stats.totalMemory > 0)
      output +=
          "\nRAM: using ${stats.usedMemoryString} out of ${stats.totalMemoryString} (${stats.usedMemoryPercentage}%)";

    return output;
  }

  static String showLastNDaysPlots(
      Harvester client, int daysAgo, NetSpace netSpace) {
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

    return text;
  }

  static String showWeekPlots(Stats stats) {
    String output = '';

    if (stats.plotsLastWeek > 0) {
      //Calculates when it will run out of space based on last week's statistics
      String outOfSpace = stats.outOfSpaceString;

      output += "\n\nLast week: completed ${stats.plotsLastWeek} plots";

      if (stats.supportDiskSpace) {
        //If free space is less than a k32 plot size
        if (stats.freeSize > 0 && stats.freeSize < 1.1e9)
          output += "\n:warning: **OUT OF SPACE** :warning:";
        if (stats.freeSize > 0 && stats.plotsLastWeek > 0)
          output += "\nOut of space in $outOfSpace";
        //If time until out of space is shorter than 4 hours then it will assume it's out of space
        else if (stats.outOfSpace.inHours <= 4 && stats.plotsLastWeek > 0)
          output += "\n**OUT OF SPACE IN $outOfSpace**";
      }

      double ppd = 0.0; //plots per day

      //does overall plot per day if overPeriod average period is not defined,
      //if this period is defined then it calculates plotsPerDay using its dedicated function
      ppd =
          (stats.numberOfPlots / stats.farmedDuration.inMinutes) * 60.0 * 24.0;
      output += "\nAll time:  " + ppd.toStringAsFixed(2) + " plots per day";

      double weekAverage = stats.plotsLastWeek / stats.daysWithPlotsLastWeek;
      output += "\nLast 7 days: " +
          (weekAverage).toStringAsFixed(2) +
          " plots per day";

      output += "\nAll time average plot length: " +
          durationToTime(stats.averagePlotLength);
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

  static String showFilters(Harvester harvester, Stats stats) {
    String output = '';
    if (harvester.numberFilters > 0) {
      output +=
          "\n\nLast 24 hours: ${stats.eligiblePlots} plots passed ${stats.numberFilters} filters";

      //displays number of proofs found if > 0
      if (harvester.proofsFound > 0)
        output += "\nFound ${stats.proofsFound} proofs";

      output +=
          "\nEach plot passed ${stats.filterPassedRatio.toStringAsFixed(2)} times per 512 filters";
      output += "\n24h Efficiency: **${stats.efficiency}%**";

      output += "\n\nLongest response: **${stats.maxTime}** seconds";
      output += "\nShortest response: ${stats.minTime} seconds";

      int decimals = 3;

      if (stats.medianTime > 0 || stats.avgTime > 0)
        output +=
            "\nMedian: ${stats.medianTime.toStringAsFixed(decimals)}s Avg: ${stats.avgTime.toStringAsFixed(decimals)}s σ: ${stats.stdDeviation.toStringAsFixed(decimals)}s";

      if (stats.maxTime >= 30) {
        output +=
            "\n:warning: **Missed ${stats.missedChallenges} challenges** :warning:";
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
          if (entry.value > 0)
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

  static String showFullNodeStats(Stats stats) {
    String output = '';
    output += "\n*Full Node Stats*";

    if (stats.completeSubSlots > 0) {
      output += "\n${stats.completeSubSlots} complete Sub Slots";
      output += "\n${stats.loosePercentage}% orphan Signage Points";
    }

    if (stats.shortSyncNumber > 0) {
      output +=
          "\n:warning: **Lost sync ${stats.shortSyncNumber} times**, skipped ${stats.shortSyncSkippedBlocks} blocks";

      output += stats.shortSyncDescription;
    }

    if (stats.fullNodesConnected > 0) {
      output += "\nConnected to ${stats.fullNodesConnected} peers";
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

    if (client.swarPM.jobs.length > 0) {
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

  //returns number of plots done last week
  //used to calculate out of space estimate
  static int countPlotsLastWeek(Harvester client) {
    int weekCount = 0;
    for (int k = 1; k < 8; k++) {
      List<Plot> plots = plotsNDaysAgo(client, k);

      int count = plots.length;

      weekCount += count;
    }

    return weekCount;
  }

  //returns total sum of plots done last week
  //used to calculate out of space estimate
  static int countPlotsSizeLastWeek(Harvester client) {
    int weekSize = 0;
    for (int k = 1; k < 8; k++) {
      List<Plot> plots = plotsNDaysAgo(client, k);

      int sumSize = plotSumSize(plots);

      weekSize += sumSize;
    }

    return weekSize;
  }

  //returns number of days last week that had plots
  //used to calculate better out of space estimate
  static int countDaysWithPlotsLastWeek(Harvester client) {
    int daysWithPlots = 0;
    for (int k = 1; k < 8; k++)
      if (plotsNDaysAgo(client, k).length > 0) daysWithPlots += 1;

    return daysWithPlots;
  }

//Estimates ETW in days
//Decimals are more precise (in theory)
  static double estimateETW(Harvester client, NetSpace netSpace) {
    double networkSizeBytes = (netSpace.size * 1.0);

    int size = plotSumSize(client.plots);

    double calc =
        (networkSizeBytes / size) / (client.blocksPer10Mins * 6.0 * 24.0);

    return calc;
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

  static String showHarvester(
      Harvester harvester,
      int harvestersCount,
      int farmersCount,
      NetSpace netSpace,
      bool isFull,
      bool isWorkers,
      Rate? rate,
      [bool discord = true,
      bool removeEmojis = false]) {
    String output = '';

    try {
      if (!isFull) {
        harvestersCount = 0;
        farmersCount = 0;
      }

      Stats stats = Stats(harvester, rate, netSpace);

      String name = (isWorkers) ? Stats.showName(harvester) : '';
      String lastUpdated = ((isFull || isWorkers) && discord)
          ? Stats.showLastUpdated(harvester, farmersCount, harvestersCount)
          : '';

      String main = name +
          Stats.showStatus(stats) +
          Stats.showBalance(stats, !(isFull || isWorkers)) +
          Stats.showColdBalance(stats) +
          Stats.showWalletBalance(stats, !(isFull || isWorkers)) +
          ((harvester is HPool && (isFull || isWorkers))
              ? Stats.showUndistributedBalance(stats)
              : '') +
          ((harvester is FoxyPoolOG && (isFull || isWorkers))
              ? Stats.showPendingBalance(stats) +
                  Stats.showCollateralBalance(stats)
              : '') +
          Stats.showPlotsInfo(stats) +
          Stats.showETWEDV(stats, !isWorkers, (isFull || isWorkers)) +
          Stats.showNetworkSize(stats) +
          Stats.showFarmedTime(stats);

      String full = (isFull || isWorkers)
          ? Stats.showDrives(stats) +
              Stats.showHardware(stats) +
              Stats.showPlotTypes(harvester) +
              Stats.showLastPlotInfo(harvester) +
              Stats.showLastNDaysPlots(harvester, 8, netSpace) +
              Stats.showWeekPlots(stats) +
              Stats.showIncompletePlotsWarning(harvester) +
              Stats.showFilters(harvester, stats)
          : '';

      String fullNodeStats = ((isFull || isWorkers) &&
              harvester is Farmer &&
              (harvester.completeSubSlots > 0 ||
                  harvester.fullNodesConnected > 0 ||
                  harvester.shortSyncs.length > 0))
          ? ";;" + Stats.showFullNodeStats(stats) + lastUpdated
          : '';

      String swarPM =
          ((isFull || isWorkers) && harvester.swarPM.jobs.length > 0)
              ? ";;" + Stats.showSwarPMJobs(harvester) + lastUpdated
              : '';

      output = main + full + lastUpdated + fullNodeStats + swarPM;

      //removes discord emojis
      if (!discord || removeEmojis) {
        try {
          RegExp emojiRegex = RegExp('(:[\\S]+: )');
          RegExp externalEmojiRegex = RegExp('(<:[\\S]+:[0-9]+> )');

          var matches = emojiRegex.allMatches(output).toList();
          matches.addAll(externalEmojiRegex.allMatches(output).toList());

          for (var match in matches)
            output = output.replaceAll(match.group(1) ?? 'none', "");

          if (!discord)
            output = output.replaceAll("**", "").replaceAll(";;", "\n");
        } catch (e) {}
      }
    } catch (e) {
      output = "Failed to display stats.";
    }

    return output;
  }
}
