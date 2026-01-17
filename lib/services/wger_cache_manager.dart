import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class WgerCacheManager extends CacheManager {
  WgerCacheManager._()
      : super(
          Config(
            'wger_cache',
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 200,
          ),
        );

  static final WgerCacheManager instance = WgerCacheManager._();
}
