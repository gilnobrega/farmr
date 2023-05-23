import 'dart:core';
import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/cache/cacheStruct.dart';

import 'package:logging/logging.dart';

final log = Logger('Cache');

class Cache extends CacheStruct {
  Cache(Blockchain blockchain, String rootPath, bool firstInit) : super(blockchain, rootPath);
}
