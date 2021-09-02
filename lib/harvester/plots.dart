import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/hpool/hpool.dart';
import 'package:farmr_client/utils/rpc.dart';
import 'package:universal_io/io.dart' as io;

import 'package:yaml/yaml.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

import 'package:farmr_client/plot.dart';
import 'package:farmr_client/config.dart';

final Logger log = Logger('Harvester.Plots');

class HarvesterPlots {
  //checks if plot is larger than k32 (for most forks)
  bool checkPlotSize = true;

  //Private list with complete and incomplete plots
  List<Plot> allPlots = [];

  //Returns list of complete and loaded plots
  List<Plot> get plots => allPlots
      .where((plot) => (plot.complete || !checkPlotSize) && plot.loaded)
      .toList();

  //Returns list of complete
  List<Plot> get completePlots =>
      allPlots.where((plot) => plot.complete || !checkPlotSize).toList();

  //Returns list of incomplete plots
  List<Plot> get incompletePlots =>
      allPlots.where((plot) => !plot.complete && checkPlotSize).toList();

  //Returns list of og plots
  List<Plot> get ogPlots =>
      allPlots.where((plot) => plot.isOG && plot.loaded).toList();

  //Returns list of nft plots
  List<Plot> get nftPlots =>
      allPlots.where((plot) => plot.isNFT && plot.loaded).toList();

  //Returns list of plots which failed to load
  List<Plot> get failedPlots => allPlots
      .where((plot) => plot.failed || (!plot.complete && checkPlotSize))
      .toList();

  //creates a map with the following structure { 'k32' : 3, 'k33' : 2 } etc.
  Map<String, int> get typeCount => genPlotTypes(plots);

  List<String> winnerPlotPublicKeys = []; //ids of plots which won blocks

  List<Plot> get winnerPlots =>
      allPlots.where((plot) => winnerPlotPublicKeys.contains(plot.id)).toList();

  dynamic rpcPlotInfo;

  //Parses chia's config.yaml and finds plot destionation paths
  List<String> listPlotDest(String chiaConfigPath) {
    String configPath = (chiaConfigPath != "")
        ? chiaConfigPath + io.Platform.pathSeparator + "config.yaml"
        : "config.yaml";

    var configYaml = loadYaml(
        io.File(configPath).readAsStringSync().replaceAll("!!set", ""));

    List<String> pathsUnfiltered = (this is HPool)
        ? ylistToStringlist(configYaml['path'])
        : ylistToStringlist(configYaml['harvester']['plot_directories']);

    //Filters duplicate paths
    List<String> pathsFiltered = [];

    for (int i = 0; i < pathsUnfiltered.length; i++) {
      try {
        io.Directory dir = io.Directory(pathsUnfiltered[i]);

        if (dir.existsSync()) {
          //It used to not add empty directories before,
          //but that would mean it would not get the disk space of those directories
          //bool isEmpty =
          //  dir.listSync().where((file) => extension(file.path) == ".plot").toList().length == 0;

          //Adds plot dest if it contains at least one .plot file
          //if (!isEmpty) {
          pathsFiltered.add(dir.absolute.path);
          log.info("Found plot destination directory:" + dir.absolute.path);
          //}
        }
      } catch (err) {
        log.warning("Unable to load " + pathsUnfiltered[i]);
      }
    }

    return pathsFiltered.toSet().toList();
  }

  //returns last bit of plot filename if plot contains '-' (such as chia plotter and madmax)
  //else returns whole filename
  static String getPlotId(String path) {
    return basenameWithoutExtension(path);
  }

//makes a list of available plots in all plot destination paths
  Future<void> listPlots(List<String> paths, Config config) async {
    List<Plot> newplots = [];

    for (int i = 0; i < paths.length; i++) {
      var path = paths[i];

      try {
        io.Directory dir = io.Directory(path);

        await dir.list(recursive: false).forEach((file) {
          //Checks if file extension is .plot
          //also checks that it is a File and not a directory
          if (extension(file.path) == ".plot" && file is io.File) {
            final String filename = getPlotId(file.path);

            bool inCache =
                allPlots.any((cachedPlot) => cachedPlot.filename == filename);
            bool duplicate = newplots.any((plot) => plot.filename == filename);

            //If plot id it is in cache then adds old plot information (timestamps, etc.)
            //but updates plot size
            Plot? plot;
            if (inCache && !duplicate) {
              plot = allPlots
                  .firstWhere((cachedPlot) => cachedPlot.filename == filename);

              //updates file size in case plot was being moved while cached
              if (!plot.complete) {
                io.FileStat stat = io.FileStat.statSync(file.path);
                plot.updateSize(stat.size);
              }
            }
            //Adds plot if it's not in cache already
            else if (!duplicate) {
              //print("Found new plot " + id); // UNCOMMENT FOR DEBUGGING PLOT CACHE
              plot = new Plot(file, filename);

              //displays warning if plot is incomplete and minimum k size is k32
              if (!plot.complete && checkPlotSize)
                log.warning("Warning: plot " + file.path + " is incomplete!");
            }

            //updates plots public key and sets if its nft
            if (rpcPlotInfo != null)
              for (var rpcPlot in rpcPlotInfo) {
                if (rpcPlot['filename'] is String) {
                  try {
                    if ((plot?.filename ?? "N/A") ==
                        getPlotId(rpcPlot['filename'])) plot?.readRPC(rpcPlot);
                  } catch (error) {
                    log.info(
                        "Failed to get RPC info about plot ${rpcPlot['filename']}");
                  }
                }
              }
            else //assumes plot is loaded if it cant load rpc info
              plot?.loaded = true;

            if (plot != null) newplots.add(plot);
          }
        });
      } catch (error) {
        log.warning("Failed to list plots in $path\nIs this directory empty?");
        log.info(error);
      }
    }

    allPlots = newplots;

    config.cache!.savePlots(allPlots);
  }

  Future<void> readRPCPlotList(Blockchain blockchain) async {
    try {
      RPCConfiguration rpcConfig = RPCConfiguration(
          blockchain: blockchain,
          service: RPCService.Harvester,
          endpoint: "get_plots",
          dataToSend: {});

      var rpcOutput = await RPCConnection.getEndpoint(rpcConfig);

      if (rpcOutput != null &&
          rpcOutput['plots'] != null &&
          rpcOutput['plots'] != null) rpcPlotInfo = rpcOutput['plots'];
    } catch (error) {
      log.warning(
          "Failed to load RPC list of ${blockchain.currencySymbol} plots");
    }
  }

  void filterDuplicates([bool client = true]) {
    final idslist = allPlots.map((plot) => plot.id);
    final idsSet = idslist.toSet();
    final difference = idslist.length - idsSet.length;

    //Removes plots with same ids!
    allPlots.retainWhere((x) {
      if (idsSet.remove(x.id)) {
        return true;
      } else {
        log.info("Found duplicate plot " + x.id);
        return false;
      }
    });

    //Counts how many plots were filtered
    if (client && difference > 0)
      log.warning("Warning: filtering $difference duplicated plots!");
  }

  //makes an id based on end and start timestamps for the last plot, necessary to call notifications webhook
  String lastPlotID() {
    if (completePlots.length > 0) {
      Plot last = lastPlot(completePlots); //last completed plot

      return last.id;
    } else {
      return "0";
    }
  }

  void sortPlots() {
    allPlots.sort((plot1, plot2) => (plot1.begin
        .compareTo(plot2.begin))); //Sorts plots from oldest to newest
  }

  //sorts plots into typeCount map
  static Map<String, int> genPlotTypes(List<Plot> plots) {
    Map<String, int> typeCount = {};

    for (Plot plot in plots) {
      String type = plot.plotSize;
      if (type.startsWith("k")) {
        typeCount.putIfAbsent(type, () => 0);
        typeCount.update(type, (value) => value + 1);
      }
    }

    return typeCount;
  }
}

//Converts a YAML List to a String list
//Used to parse chia's config.yaml
List<String> ylistToStringlist(YamlList input) {
  List<String> output = [];
  for (int i = 0; i < input.length; i++) {
    output.add(input[i].toString());
  }
  return output;
}
