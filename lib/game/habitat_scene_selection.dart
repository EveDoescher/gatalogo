import 'quintal_scene_target.dart';

/// Highlight state of the scene, independent from rendering and camera transforms.
class HabitatSceneSelection {
  String? itemId, catId;
  QuintalSceneTarget? production;
  void clear() {
    itemId = null;
    catId = null;
    production = null;
  }
}
