import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/id.dart';
import 'package:universal_io/io.dart';

enum RPCService { Daemon, Wallet, Farmer, Harvester, Full_Node }

//accepts self signed certificates
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

main() async {
  print(await RPC.getEndpoint(RPCService.Wallet, "get_wallet_balance",
      {"wallet_id": 1}, 9256, Blockchain(ID(""), "", [], {})));
}

class RPC {
  static String getServiceName(RPCService service) {
    return service.toString().split('.')[1].toLowerCase();
  }

  static Future<dynamic> getEndpoint(RPCService service, String endpoint,
      dynamic dataToSend, int port, Blockchain blockchain) async {
    HttpOverrides.global = MyHttpOverrides();

    String serviceName = getServiceName(service);
    print(serviceName);
    String certFile =
        blockchain.configPath + "/ssl/$serviceName/private_$serviceName.crt";
    print(certFile);
    String privateKey =
        blockchain.configPath + "/ssl/$serviceName/private_$serviceName.key";
    print(privateKey);

    var context = SecurityContext.defaultContext;
    context.useCertificateChain(certFile);
    context.usePrivateKey(privateKey);
    HttpClient client = new HttpClient(context: context);

    // The rest of this code comes from your question.
    var uri = "https://localhost:$port/$endpoint";
    print(uri);
    var data = jsonEncode(dataToSend);
    print(data);
    var method = 'POST';

    var request = await client.openUrl(method, Uri.parse(uri));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(data);
    var response = await request.close();

    return jsonDecode(await response.transform(Utf8Decoder()).join(''));
    // Process the response.
  }
}
