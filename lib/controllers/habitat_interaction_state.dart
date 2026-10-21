import '../game/quintal_scene_target.dart';

enum GroundTool { move, paint, collect }

enum HabitatTray { none, inventory, cats }

/// Ephemeral editor/gesture state, independent from server snapshots and widgets.
class HabitatInteractionState {
  final Set<(int, int)> pathStroke = {};
  HabitatTray tray = HabitatTray.none;
  bool menuOpen = false;
  bool productionTrayOpen = false;
  bool editing = false;
  String? selectedItemId;
  QuintalSceneTarget? productionSelection;
  ({String id, (int, int) anchor, (int, int) food, (int, int) water})? catSet;
  bool choosingWater = false;
  bool placingSet = false;
  String? draggingCatId;
  (int, int)? hovered;
  int rotation = 0;
  GroundTool groundTool = GroundTool.move;
  String? groundSku;
  bool groundOnly = false, cameraGesture = false;
  int scenePointers = 0;

  void toggleEditing() {
    editing = !editing;
    productionSelection = null;
    menuOpen = false;
    if (!editing) {
      tray = HabitatTray.none;
      clearSelection();
    }
  }

  void clearSelection() {
    groundTool = GroundTool.move;
    groundSku = null;
    selectedItemId = null;
  }

  void openTray(HabitatTray value) {
    tray = value;
    menuOpen = false;
    if (value == HabitatTray.cats) editing = true;
    productionSelection = null;
    clearSelection();
  }
}
