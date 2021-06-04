import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

Logger log = Logger("HPool API");

class HPoolApi {
  double _poolIncome = 0.0;
  double get poolIncome => _poolIncome;

  double _undistributedIncome = 0.0;
  double get undistributedIncome => _undistributedIncome;

  static String stringifyCookies(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  HPoolApi();

  init(String authToken) async {
    if (authToken != "") {
      try {
        const String incomeUrl = r"/api/pool/Income?language=en&type=opened";
        //TO ADD
        //const String plotsUrl =
        //   r"/api/pool/GetPlots?language=en&page=1&count=1&pool=chia";
        //const String blocksUrl =
        //  r"/api/pool/miningdetail?language=en&type=chia&count=50&page=1";

        String baseUrl = r"https://hpool.com";

        http.Response response =
            await http.post(Uri.parse(baseUrl + incomeUrl), headers: {
          'Cookie': stringifyCookies({"auth_token": authToken.trim()})
        });

        var data = jsonDecode(response.body);
        _poolIncome =
            double.parse(data['data']['list'][0]['pool_income'].toString());
        _undistributedIncome = double.parse(
            data['data']['list'][0]['undistributed_income'].toString());
      } catch (e) {
        log.warning(
            "Failed to get HPool Info, make sure your auth_token is correct.");
      }
    }
  }
}
