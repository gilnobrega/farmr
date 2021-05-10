import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;

class Price {
  String _apiKey = '';

  final int _untilTimeStamp = DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;
  final io.File _cacheFile = io.File("price.json");

  //main currency supported in coinmarketapi xch conversion
  String _currency = 'USD';

  //list of currencies to get from api 
  final List<String> _otherCurrencies = [
    'EUR',
    'CAD',
    'GBP',
    'AUD',
    'SGD',
    'JPY',
    'INR',
    'RMB',
    'CNY',
    'CHF',
    'HKD',
    'BRL',
    'DKK',
    'NZD',
    'TRY',
    'ETH',
    'BTC',
    'ETC'
  ];
  Map<String, double> rates = {};

  int _timestamp = 0;
  int get timestamp => _timestamp;

  Map toJson() => {"rates": rates, "currency": _currency, "timestamp": timestamp};

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
      _currency = previousPrice._currency;
      rates = previousPrice.rates;
    }
  }

  _getPriceFromApi() async {
    try {
//gets xch/usd exchange rate from coinbase
      var json = jsonDecode(await http.read(
          "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=XCH&convert=" +
              _currency,
          headers: {'X-CMC_PRO_API_KEY': _apiKey}));

      var rate = json['data']['XCH']['quote'][_currency]['price'];

      rates.putIfAbsent(_currency, () => rate);
    } catch (e) {}
  }

  _getOtherCurrencies() async {
    //attempts to get main currencies rate in overall USD rates page,
    //if that fails then it gets them from individual pages

    final mainjson = jsonDecode(await http.read("https://api.coinbase.com/v2/prices/USD/spot"));

    for (String otherCurrency in _otherCurrencies) {
      try {
        var data = mainjson['data'];
        double rate = 0.0;

        for (var object in data) {
          if (object['base'] == otherCurrency) {
            rate = 1/double.parse(object['amount']);
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
          double xchprice = (rate) * rates[_currency];

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
    if (json['currency'] != null) _currency = json['currency'];
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
  }
}
