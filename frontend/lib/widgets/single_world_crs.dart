import 'package:flutter_map/flutter_map.dart';

/// Web Mercator without sideways world copies. flutter_map paints and
/// hit-tests shapes once per world copy until one is off-screen; in the
/// browser that check can fail and throw "Infinite loop going beyond 30".
/// The app only shows Poland, so one world is enough. Used by every map.
class SingleWorldCrs extends Epsg3857 {
  const SingleWorldCrs();

  @override
  bool get replicatesWorldLongitude => false;
}
