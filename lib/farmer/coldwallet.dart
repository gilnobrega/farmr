import 'dart:convert';

import 'package:farmr_client/farmer/wallet.dart';
import 'package:http/http.dart' as http;

import 'package:logging/logging.dart';

Logger log = Logger("Cold Wallet");

//Wallet that uses chiaexplorer
class ColdWallet {
  Wallet _mainWallet;

  //gross balance
  //CHIAEXPLORER ONLY
  double _grossBalance = -1.0;
  double get grossBalance => _grossBalance;

  //net balance
  double _netBalance = -1.0;
  double get netBalance => _netBalance;

  //farmed balance
  //FLAX EXPLORER ONLY
  double _farmedBalance = -1.0;
  double get farmedBalance => _farmedBalance;

  Map toJson() => {
        "grossBalance": grossBalance,
        "netBalance": netBalance,
        "farmedBalance": farmedBalance
      };

  ColdWallet(this._mainWallet);

  ColdWallet.fromJson(dynamic json, this._mainWallet) {
    if (json['grossBalance'] != null)
      _grossBalance = double.parse(json['grossBalance'].toString());
    if (json['netBalance'] != null)
      _netBalance = double.parse(json['netBalance'].toString());
    if (json['farmedBalance'] != null)
      _farmedBalance = double.parse(json['farmedBalance'].toString());
  }

  Future<void> init(String publicAddress) async {
    const String chiaExplorerURL = "https://api2.chiaexplorer.com/balance/";
    const String flaxExplorerURL =
        "https://flaxexplorer.org/blockchain/address/";
    if (publicAddress.startsWith("xch") && publicAddress.length == 62) {
      try {
        String contents =
            await http.read(Uri.parse(chiaExplorerURL + publicAddress));

        var object = jsonDecode(contents);

        _grossBalance = object['grossBalance'] * 1e-12;
        _netBalance = object['netBalance'] * 1e-12;
      } catch (error) {
        //404 error means wallet is empty
        if (error is http.ClientException && error.toString().contains("404")) {
          _grossBalance = 0;
          _netBalance = 0;
        } else
          log.warning("Failed to get info about chia cold wallet");
      }
    } else if (publicAddress.startsWith("xfx") && publicAddress.length == 62) {
      try {
        String contents =
            await http.read(Uri.parse(flaxExplorerURL + publicAddress));

        RegExp regex = RegExp(r"([0-9]+\.[0-9]+) XFX</span>", multiLine: true);

        try {
          var matches = regex.allMatches(contents);

          if (matches.length == 2) {
            _netBalance = double.parse(matches.elementAt(0).group(1) ?? "-1.0");
            _farmedBalance =
                double.parse(matches.elementAt(0).group(1) ?? "-1.0");
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
            _mainWallet.setLastBlockFarmed(
                int.parse(blockHeightMatches.first.group(1) ?? "-1"));
        } catch (error) {
          log.warning(
              "Failed to get info about cold wallet last farmed reward");
        }
      } catch (error) {
        log.warning("Failed to get info about flax cold wallet");
      }
    } else {
      log.warning("Invalid cold wallet address");
    }
  }
}
