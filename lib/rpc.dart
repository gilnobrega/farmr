import 'dart:convert';

import 'package:farmr_client/blockchain.dart';
import 'package:tcp_scanner/tcp_scanner.dart';

import 'package:universal_io/io.dart';
import 'package:logging/logging.dart';

Logger log = Logger("RPC");

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

class RPCPorts {
  Map<RPCService, int?> get _servicePorts => {
        RPCService.Daemon: daemonPort,
        RPCService.Farmer: farmerPort,
        RPCService.Harvester: harvesterPort,
        RPCService.Wallet: walletPort,
        RPCService.Full_Node: fullNodePort
      };

  final int? harvesterPort;
  final int? walletPort;
  final int? farmerPort;
  final int? daemonPort;
  final int? fullNodePort;

  Map toJson() => {
        "harvester": harvesterPort,
        "farmer": farmerPort,
        "wallet": walletPort,
        "full_node": fullNodePort,
        "daemon": daemonPort
      };

  const RPCPorts(
      {required this.harvesterPort,
      required this.farmerPort,
      required this.walletPort,
      required this.fullNodePort,
      required this.daemonPort});

  RPCPorts.fromJson(dynamic json)
      : this(
            harvesterPort: json['harvester'],
            farmerPort: json['farmer'],
            walletPort: json['wallet'],
            fullNodePort: json['fullNode'],
            daemonPort: json['daemon']);

  int? getServicePort(RPCService service) {
    return _servicePorts[service];
  }

  //returns if port is being used by service a.k.a. if service is running
  //null means port was not secified or there was an exception thrown by library
  Future<bool?> isServiceRunning(RPCService service) async {
    const String host = 'localhost';

    final int? port = getServicePort(service);

    bool? running;

    if (port != null) {
      try {
        final report =
            await TcpScannerTask(host, [port], parallelism: 1).start();

        running = report.openPorts.contains(port);
      } catch (e) {
        // Here you can catch exceptions threw in the constructor
        stderr.writeln('TCP Scanner Error: $e');
      }
    }

    return running;
  }

  //debug purposes
  //prints list of every services and if they are running
  Future<void> printStatus() async {
    for (RPCService service in RPCService.values) {
      final isRunning = await isServiceRunning(service);
      print("$service: $isRunning ");
    }
  }
}

class RPCConfiguration {
  final RPCService service;
  final String endpoint;
  final dynamic dataToSend;
  final Blockchain blockchain;

  const RPCConfiguration(
      {required this.blockchain,
      required this.service,
      required this.endpoint,
      this.dataToSend = const {}});
}

class RPCConnection {
  static String getServiceName(RPCService service) {
    return service.toString().split('.')[1].toLowerCase();
  }

  static Future<dynamic> getEndpoint(RPCConfiguration rpcConfig) async {
    try {
      HttpOverrides.global = MyHttpOverrides();

      String serviceName = getServiceName(rpcConfig.service);
      String certFile = rpcConfig.blockchain.configPath +
          "/ssl/$serviceName/private_$serviceName.crt"
              .replaceAll("/", Platform.pathSeparator);
      String privateKey = rpcConfig.blockchain.configPath +
          "/ssl/$serviceName/private_$serviceName.key"
              .replaceAll("/", Platform.pathSeparator);

      var context = SecurityContext.defaultContext;
      context.useCertificateChain(certFile);
      context.usePrivateKey(privateKey);
      HttpClient client = new HttpClient(context: context);

      //reads service port
      int? port =
          rpcConfig.blockchain.rpcPorts?.getServicePort(rpcConfig.service);
      if (port != null) {
        // The rest of this code comes from your question.
        var uri = "https://localhost:$port/${rpcConfig.endpoint}";
        var data = jsonEncode(rpcConfig.dataToSend);
        var method = 'POST';

        var request = await client.openUrl(method, Uri.parse(uri));
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(data);
        var response = await request.close();
        // Process the response and returns dynamic array with contents
        return jsonDecode(await response.transform(Utf8Decoder()).join(''));
      } else {
        log.info("Invalid port for ${rpcConfig.blockchain.currencySymbol}");
        return null;
      }
    } catch (error) {
      log.warning(
          "Failed to load RPC info for ${rpcConfig.blockchain.currencySymbol}");
      log.info(error);
      return null;
    }
  }
}
