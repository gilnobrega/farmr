import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;

class Price {
  String _apiKey = '';

  final int _untilTimeStamp = DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;
  final io.File _cacheFile = io.File("price.json");

  //list of currencies to get from api and their symbols
  static final Map<String, String> currencies = {
    'USD': '\$',
    'EUR': '€',
    'CAD': '\$',
    'GBP': '£',
    'AUD': '\$',
    'SGD': '\$',
    'JPY': '¥',
    'INR': '₹',
    'MYR': 'RM',
    'CNY': '¥',
    'CHF': 'Fr',
    'HKD': 'HK\$',
    'BRL': 'R\$',
    'DKK': 'kr.',
    'NZD': '\$',
    'TRY': '₺',
    'THB': '฿',
    'ETH': 'ETH',
    'BTC': '₿',
    'ETC': 'ETC'
  };

  Map<String, double> rates = {};

  int _timestamp = 0;
  int get timestamp => _timestamp;

  Map toJson() => {"rates": rates, "timestamp": timestamp};

  Price(String apikey) {
    _apiKey = apikey;
  }

  Future<void> init() async {
    if (_cacheFile.existsSync())
      await _load();
    else {
      await _getPriceFromApi();
      await _getOtherCurrencies();

      _save();
    }
  }

  _load() async {
    var json = jsonDecode(_cacheFile.readAsStringSync());
    Price previousPrice = Price.fromJson(json);

    //if last time price was parsed from api was longer than 1 minute ago
    //then parses new price from api
    if (previousPrice.timestamp < _untilTimeStamp) {
      await _getPriceFromApi();
      await _getOtherCurrencies();
      _timestamp = DateTime.now().millisecondsSinceEpoch;

      _save();
    } else {
      _timestamp = previousPrice.timestamp;
      rates = previousPrice.rates;
    }
  }

  _getPriceFromApi() async {
    try {
//gets xch/usd exchange rate from coinbase
      var json = jsonDecode(await http.read(
          "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=XCH&convert=" +
              currencies.entries.first.key,
          headers: {'X-CMC_PRO_API_KEY': _apiKey}));

      var rate = json['data']['XCH']['quote'][currencies.entries.first.key]['price'];

      rates.putIfAbsent(currencies.entries.first.key, () => rate);
    } catch (e) {}
  }

  _getOtherCurrencies() async {
    //attempts to get main currencies rate in overall USD rates page,
    //if that fails then it gets them from individual pages

    final mainjson = jsonDecode(await http.read("https://api.coinbase.com/v2/prices/USD/spot"));

    for (String otherCurrency in currencies.entries
        .where((entry) => entry != currencies.entries.first)
        .map((entry) => entry.key)
        .toList()) {
      try {
        var data = mainjson['data'];
        double rate = 0.0;

        for (var object in data) {
          if (object['base'] == otherCurrency) {
            rate = 1 / double.parse(object['amount']);
          }
        }

        if (rate == 0.0) {
          try {
            var json = jsonDecode(await http
                .read("https://api.coinbase.com/v2/prices/USD-" + otherCurrency + "/spot"));

            rate = double.parse(json['data']['amount']);
          } catch (e) {}
        }

        if (rate > 0) {
          // xch price = usd/eur price * xch/usd price
          double xchprice = (rate) * rates[currencies.entries.first.key];

          rates.putIfAbsent(otherCurrency, () => xchprice);
        }
      } catch (e) {}
    }
  }

  _save() {
    String serial = jsonEncode(this);
    _cacheFile.writeAsStringSync(serial);
  }

  Price.fromJson(dynamic json) {
    if (json['rates'] != null) rates = Map<String, double>.from(json['rates']);
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
  }
}
