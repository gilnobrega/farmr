import 'dart:convert';

import 'package:farmr_client/farmer/wallet.dart';
import 'package:http/http.dart' as http;

import 'package:logging/logging.dart';

Logger log = Logger("Cold Wallet");

//Wallet that uses chiaexplorer/flaxexplorer/posat.io
class ColdWallet {
  //gross balance
  //CHIAEXPLORER ONLY
  double _grossBalance = -1.0;
  double get grossBalance => roundTo12Decimals(_grossBalance);

  //net balance
  double _netBalance = -1.0;
  double get netBalance => roundTo12Decimals(_netBalance);

  //farmed balance
  //FLAX EXPLORER ONLY
  double _farmedBalance = -1.0;
  double get farmedBalance => roundTo12Decimals(_farmedBalance);

  Map toJson() => {
        "grossBalance": grossBalance,
        "netBalance": netBalance,
        "farmedBalance": farmedBalance
      };

  ColdWallet();

  ColdWallet.fromJson(dynamic json) {
    if (json['grossBalance'] != null)
      _grossBalance = double.parse(json['grossBalance'].toString());
    if (json['netBalance'] != null)
      _netBalance = double.parse(json['netBalance'].toString());
    if (json['farmedBalance'] != null)
      _farmedBalance = double.parse(json['farmedBalance'].toString());
  }

  Future<void> init(String publicAddressesString, Wallet mainWallet) async {
    const String chiaExplorerURL = "https://api2.chiaexplorer.com/";
    const String flaxExplorerURL =
        "https://flaxexplorer.org/blockchain/address/";
    //multiple cold wallet addresses
    List<String> publicAddresses = [publicAddressesString];
    if (publicAddressesString.contains(","))
      publicAddresses = publicAddressesString.split(",");

    List<double> grossBalances = [];
    List<double> netBalances = [];
    List<double> farmedBalances = [];

    for (String publicAddress in publicAddresses) {
      if (publicAddress.startsWith("xch") &&
          publicAddress.length == 62 &&
          mainWallet.blockchain.currencySymbol == "xch") {
        try {
          String contents = await http
              .read(Uri.parse(chiaExplorerURL + "balance/" + publicAddress));

          var object = jsonDecode(contents);

          grossBalances
              .add((double.parse(object['grossBalance'].toString()) * 1e-12));
          netBalances
              .add(double.parse(object['netBalance'].toString()) * 1e-12);

          String coins = await http.read(
              Uri.parse(chiaExplorerURL + "coinsForAddress/" + publicAddress));

          var coinsObject = jsonDecode(coins);

          for (int i = 0;
              coinsObject['coins'] != null && i < coinsObject['coins'].length;
              i++) {
            var coin = coinsObject['coins'][i];
            if (coin['coinbase'] && int.tryParse(coin['timestamp']) != null)
              mainWallet
                  .setDaysAgoWithTimestamp(int.parse(coin['timestamp']) * 1000);
          }
        } catch (error) {
          //404 error means wallet is empty
          if (error is http.ClientException &&
              error.toString().contains("404")) {
            //if wallet is empty then assumes both gross balance and net balance are 0
            grossBalances.add(0.0);
            netBalances.add(0.0);
          } else {
            log.warning("Failed to get info about chia cold wallet");
          }
        }
      } else if (publicAddress.startsWith("xfx") &&
          publicAddress.length == 62 &&
          mainWallet.blockchain.currencySymbol == "xfx") {
        //flaxexplorer has no way to know if wallet is empty or address invalid
        // always start with net balance and farm balances 0
        netBalances.add(0.0);
        farmedBalances.add(0.0);

        try {
          String contents =
              await http.read(Uri.parse(flaxExplorerURL + publicAddress));

          RegExp regex =
              RegExp(r"([0-9]+\.[0-9]+) XFX</span>", multiLine: true);

          try {
            var matches = regex.allMatches(contents);

            if (matches.length == 2) {
              netBalances
                  .add(double.parse(matches.elementAt(0).group(1) ?? "-1.0"));
              farmedBalances
                  .add(double.parse(matches.elementAt(1).group(1) ?? "-1.0"));
            }
          } catch (error) {
            log.warning("Failed to get info about flax cold wallet balance");
          }

          //tries to parse last farmed  reward
          RegExp blockHeightExp = RegExp(
              r'farmer reward<\/td>[\s]+<td><a href="\/blockchain\/coin\/[\w]+">[\w]+<\/a><\/td>[\s]+<td>[0-9\.]+ xfx<\/td>[\s]+<td>([0-9]+)',
              multiLine: true);

          try {
            var blockHeightMatches =
                blockHeightExp.allMatches(contents.toLowerCase());
            if (blockHeightMatches.length > 0)
              mainWallet.setLastBlockFarmed(
                  int.parse(blockHeightMatches.first.group(1) ?? "-1"));
          } catch (error) {
            log.warning(
                "Failed to get info about cold wallet last farmed reward");
          }
        } catch (error) {
          log.warning("Failed to get info about flax cold wallet");
        }
      }
      //if not flax or chia then try posat.io
      else if (publicAddress.length == 62 &&
          publicAddress.startsWith(mainWallet.blockchain.currencySymbol)) {
        String posatExplorerURL =
            "https://${mainWallet.blockchain.binaryName}.posat.io/address/";

        netBalances.add(0.0);

        try {
          String contents =
              await http.read(Uri.parse(posatExplorerURL + publicAddress));

          RegExp regex = RegExp(
              r"balance: <strong>([0-9]+\.[0-9]+) " +
                  mainWallet.blockchain.currencySymbol.toUpperCase(),
              multiLine: true);

          try {
            var matches = regex.allMatches(contents);

            if (matches.length > 0) {
              netBalances
                  .add(double.parse(matches.elementAt(0).group(1) ?? "-1.0"));
            }
          } catch (error) {
            log.warning(
                "Failed to get info about ${mainWallet.blockchain.binaryName} cold wallet balance");
          }

          //tries to parse last farmed  reward
          RegExp blockHeightExp = RegExp(
              r'([0-9]+)<\/a><\/td>[\s]+<td><a href="\/coin\/[\w]+">[\w]+<\/a><\/td>[\s]+<td>farmer reward<\/td>[\s]+<td class="right">[0-9\.]+ ' +
                  mainWallet.blockchain.currencySymbol.toLowerCase() +
                  r'<\/td>',
              multiLine: true);

          try {
            var blockHeightMatches =
                blockHeightExp.allMatches(contents.toLowerCase());
            if (blockHeightMatches.length > 0)
              mainWallet.setLastBlockFarmed(
                  int.parse(blockHeightMatches.first.group(1) ?? "-1"));
          } catch (error) {
            log.warning(
                "Failed to get info about cold wallet last farmed reward");
          }
        } catch (error) {
          log.warning(
              "Failed to get info about ${mainWallet.blockchain.binaryName} cold wallet");
        }
      } else {
        log.warning("Invalid cold wallet address");
      }
    }

    if (netBalances.length > 0) _netBalance = 0;
    for (double netBalance in netBalances) _netBalance += netBalance;

    if (mainWallet.blockchain.currencySymbol == "xfx") {
      if (farmedBalances.length > 0) _farmedBalance = 0;

      for (double farmedBalance in farmedBalances)
        _farmedBalance += farmedBalance;
    }

    if (mainWallet.blockchain.currencySymbol == "xch") {
      if (grossBalances.length > 0) _grossBalance = 0;

      for (double grossBalance in grossBalances) _grossBalance += grossBalance;
    }
  }

  static double roundTo12Decimals(double input) =>
      double.parse(input.toStringAsFixed(12));
}
