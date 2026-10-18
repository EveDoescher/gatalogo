import 'package:flutter/foundation.dart';

/// Shared navigation intent; opening a notification never claims a gift.
class HabitatNavigation {
  static final focusGift = ValueNotifier<String?>(null);
  static final hasGift = ValueNotifier<bool>(false);
  static final focusProduction = ValueNotifier<String?>(null);
}
