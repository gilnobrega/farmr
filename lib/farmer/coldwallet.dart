import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:logging/logging.dart';

Logger log = Logger("Cold Wallet");

//Wallet that uses chiaexplorer
class ColdWallet {
  //gross balance
  double _grossBalance = -1.0;
  double get grossBalance => _grossBalance;

  //net balance
  double _netBalance = -1.0;
  double get netBalance => _netBalance;

  Map toJson() => {"grossBalance": grossBalance, "netBalance": netBalance};

  ColdWallet();

  ColdWallet.fromJson(dynamic json) {
    if (json['grossBalance'] != null)
      _grossBalance = double.parse(json['grossBalance'].toString());
    if (json['netBalance'] != null)
      _netBalance = double.parse(json['netBalance'].toString());
  }

  Future<void> init(String publicAddress) async {
    const String chiaExplorerURL = "https://api2.chiaexplorer.com/balance/";
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
        }
        log.warning("Failed to get info about cold wallet");
      }
    } else {
      log.warning("Invalid cold wallet address");
    }
  }
}
