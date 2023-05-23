import 'dart:convert';
import 'package:universal_io/io.dart' as io;

import 'package:http/http.dart' as http;

class Price {
  final int _untilTimeStamp =
      DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch;
  var _cacheFile;

  //list of currencies to get from api and their symbols
  static const Map<String, String> currencies = {
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
    'TWD': 'NT\$',
    'KRW': '₩',
    'ETH': 'ETH',
    'BTC': '₿',
    'ETC': 'ETC'
  };

  // coin => map<currency, rate>
  Map<String, Map<String, Rate>> coinRates = {};
  final otherCoins = {"xfx", "hdd", "stor", "xcc", "stai"};

  Map<String, Rate> getRates(String coin) {
    return coinRates.putIfAbsent(coin, () => new Map<String, Rate>());
  }

  int _timestamp = 0;
  int get timestamp => _timestamp;

  Map toJson() => {
        "rates": coinRates, //getRates("xch"),
        "timestamp": timestamp,
      };

  Price();

  //genCache=true forces generation of price.json file
  Future<void> init([bool genCache = false, bool skipCache = false]) async {
    if (skipCache) {
      await _getPriceFromApi();
      await _getOtherCurrencies();
      await _getPriceOtherCoins();
    } else {
      _cacheFile = io.File("price.json");
      if (_cacheFile.existsSync())
        await _load(genCache);
      else {
        await _getPriceFromApi();
        await _getOtherCurrencies();
        await _getPriceOtherCoins();
        _save();
      }
    }
  }

  _load([bool genCache = false]) async {
    var json = jsonDecode(_cacheFile.readAsStringSync());
    Price previousPrice = Price.fromJson(json);

    //if last time price was parsed from api was longer than 1 minute ago
    //then parses new price from api
    if (previousPrice.timestamp < _untilTimeStamp || genCache) {
      await _getPriceFromApi();
      await _getOtherCurrencies();
      await _getPriceOtherCoins();
      _save();
    } else {
      _timestamp = previousPrice.timestamp;
      coinRates = previousPrice.coinRates;
    }
  }

  _getPriceOtherCoins() async {
    // print("_getPriceOtherCoins....");
    try {
      Map<String, double> exchUSD = {};

      //gets coins/usd exchange rate from coinbase
      final json = jsonDecode(await http
          .read(Uri.parse("https://chiafork.space/API/allforks.json")));
      for (var coin in otherCoins) {
        // print(".... doing ${coin}");
        //TODO: not sure how to get directly to the coins we want (instead of this O2 algorithm)
        for (var data in json["All Forks"]) {
          //print("............... ${data}");
          if (data["symbol"].toLowerCase() == coin) {
            var rates = getRates(coin);
            var rateUSD = double.parse(data["price"]);
            rates.putIfAbsent("USD", () => Rate(rateUSD, 0, 0));

            // print("$coin/USD: **$rateUSD** (${data['name']})");

            for (var otherCurrency in currencies.keys) {
              if (otherCurrency == "USD") continue;
              try {
                double exchRate = 0;
                if (exchUSD.containsKey(otherCurrency)) {
                  exchRate = exchUSD[otherCurrency]!;
                } else {
                  if (otherCurrency == "ETC" ||
                      otherCurrency == "ETH" ||
                      otherCurrency == "BTC") {
                    final json = jsonDecode(await http.read(Uri.parse(
                        "https://api.coinbase.com/v2/prices/$otherCurrency-USD/spot")));
                    exchRate = 1 / double.parse(json['data']['amount']);
                  } else {
                    final json = jsonDecode(await http.read(Uri.parse(
                        "https://api.coinbase.com/v2/prices/USD-$otherCurrency/spot")));
                    exchRate = double.parse(json['data']['amount']);
                  }

                  exchUSD[otherCurrency] = exchRate;
                }
                rates.putIfAbsent(
                    otherCurrency, () => Rate(rateUSD * exchRate, 0, 0));
                // print(
                // "$coin/$otherCurrency: **${rateUSD * exchRate}** (${data['name']})");
              } catch (e) {}
            }
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }

  _getPriceFromApi() async {
    try {
      String currenciesParameter = '';

      for (var currency in currencies.entries)
        currenciesParameter +=
            currency.key.toLowerCase() + Uri.encodeQueryComponent(",");

      //gets xch/usd exchange rate from coinbase
      final json = jsonDecode(await http.read(Uri.parse(
          "https://api.coingecko.com/api/v3/simple/price?ids=chia&vs_currencies=$currenciesParameter&include_24hr_vol=true&include_24hr_change=true&include_last_updated_at=true")));

      for (var currency in currencies.entries) {
        var lowerCase = currency.key.toLowerCase();

        if (json['chia'][lowerCase] != null) {
          double rate = 0.0;
          double volume = 0.0;
          double change = 0.0;

          if (json['chia'][lowerCase] is double) {
            rate = json['chia'][lowerCase];
          }

          volume = json['chia'][lowerCase + '_24h_vol'];
          change = json['chia'][lowerCase + '_24h_change'] / 100;
          var rates = getRates("xch");
          rates.putIfAbsent(currency.key, () => Rate(rate, change, volume));
        }
      }

      _timestamp = json['chia']['last_updated_at'] * 1000;
    } catch (e) {}
  }

  _getOtherCurrencies() async {
    //attempts to get main currencies rate in overall USD rates page,
    //if that fails then it gets them from individual pages

    final mainjson = jsonDecode(await http
        .read(Uri.parse("https://api.coinbase.com/v2/prices/USD/spot")));

    var rates = getRates("xch");

    for (String otherCurrency in currencies.entries
        .where((entry) =>
            entry != currencies.entries.first &&
            !(rates[entry.key] != null && (rates[entry.key]!.rate > 0)))
        .map((entry) => entry.key)
        .toList()) {
      try {
        var data = mainjson['data'];
        double rate = 0.0;

        for (var object in data) {
          //JPY and INR are too small to have an accurate rate this way,
          //since the api only stores values up to 0.01 usd
          if (object['base'] == otherCurrency &&
              object['base'] != "JPY" &&
              object['base'] != "INR" &&
              object['base'] != "KRW") {
            rate = 1 / double.parse(object['amount']);
          }
        }

        if (rate == 0.0) {
          try {
            final json = jsonDecode(await http.read(Uri.parse(
                "https://api.coinbase.com/v2/prices/USD-$otherCurrency/spot")));

            rate = double.parse(json['data']['amount']);
          } catch (e) {}
        }

        if (rate > 0) {
          // xch price = usd/eur price * xch/usd price
          double xchprice =
              ((rate) * (rates[currencies.entries.first.key]?.rate ?? 0.0));
          rates.update(otherCurrency,
              (value) => Rate(xchprice, value.change, value.rate),
              ifAbsent: () => Rate(xchprice, 0, 0));
        }
      } catch (e) {}
    }
  }

  _save() {
    String serial = jsonEncode(this);
    _cacheFile.writeAsStringSync(serial);
  }

  Price.fromJson(dynamic json) {
    //var rates = getRates("xch");
    // print("Price.fromJson");
    for (var coinrate in Map<String, dynamic>.from(json['rates']).entries) {
      var rates = getRates(coinrate.key);
      for (var rate in Map<String, dynamic>.from(coinrate.value).entries) {
        rates.putIfAbsent(
            rate.key,
            () => Rate(rate.value['rate'], rate.value['change'],
                rate.value['volume']));
      }

      // rates.putIfAbsent(
      //     rate.key,
      //     () => Rate(
      //         rate.value['rate'], rate.value['change'], rate.value['volume']));
    }
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
  }
}

class Rate {
  double _rate = 0;
  double get rate => _rate;

  //24 hr change in percentage
  double _change = 0;
  double get change => _change;

  String get _sign => (change >= 0) ? '+' : '-';
  //returns change in usd, eur, etc.
  String get changeAbsolute =>
      "$_sign${(rate - (rate / (1 + change))).abs().toStringAsFixed(1)}";
  //returns change in %
  String get changeRelative =>
      "$_sign${(change * 100).abs().toStringAsFixed(1)}";

  //24h volume in xch
  double _volume = 0;
  double get volume => _volume;

  Map toJson() => {'rate': rate, 'change': change, 'volume': volume};

  Rate(this._rate, this._change, this._volume);
}
