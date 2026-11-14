import 'package:flutter/foundation.dart';

import 'local_cache.dart';
import 'local_cache_stub.dart' if (dart.library.io) 'local_cache_io.dart'
    as platform;

LocalCache createLocalCache() {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return const NoopLocalCache();
  }
  return platform.createSqliteLocalCache();
}
