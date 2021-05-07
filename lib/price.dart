import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;

class Price {
  String _apiKey = '';

  final int _untilTimeStamp = DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;
  final io.File _cacheFile = io.File("price.json");

  String _currency = 'USD';
  String get currency => _currency;

  double _price = 0;
  double get price => _price;

  int _timestamp = 0;
  int get timestamp => _timestamp;

  Map toJson() => {"price": price, "currency": currency, "timestamp": timestamp};

  Price(String apikey) {
    _apiKey = apikey;
  }

  Future<void> init() async {
    if (_cacheFile.existsSync())
      await _load();
    else
      await _getPriceFromApi();
  }

  _load() async {
    var json = jsonDecode(_cacheFile.readAsStringSync());
    Price previousPrice = Price.fromJson(json);

    //if last time price was parsed from api was longer than 5 minutes ago
    //then parses new price from api
    if (previousPrice.timestamp < _untilTimeStamp) {
      await _getPriceFromApi();
    } else {
      _timestamp = previousPrice.timestamp;
      _currency = previousPrice.currency;
      _price = previousPrice.price;
    }
  }

  _getPriceFromApi() async {
    try {
//gets xch/usd exchange rate from coinbase
      var json = jsonDecode(await http.read(
          "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=XCH&convert=" +
              currency,
          headers: {'X-CMC_PRO_API_KEY': _apiKey}));

      _price = json['data']['XCH']['quote']['USD']['price'];
    } catch (e) {}

    _timestamp = DateTime.now().millisecondsSinceEpoch;

    _save();
  }

  _save() {
    String serial = jsonEncode(this);
    _cacheFile.writeAsStringSync(serial);
  }

  Price.fromJson(dynamic json) {
    if (json['price'] != null) _price = json['price'];
    if (json['currency'] != null) _currency = json['currency'];
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
  }
}
