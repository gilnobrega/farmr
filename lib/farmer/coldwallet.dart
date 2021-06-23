import 'dart:convert';

import 'package:http/http.dart' as http;

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
    try {
      String contents =
          await http.read(Uri.parse(chiaExplorerURL + publicAddress));

      var object = jsonDecode(contents);

      _grossBalance = object['grossBalance'] * 1e-12;
      _netBalance = object['netBalance'] * 1e-12;
    } catch (error) {}
  }
}
