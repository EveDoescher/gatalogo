import 'dart:async';
import 'dart:math' as math;

import 'habitat_cat_animations.dart';

/// Cell navigation and local visits never modify the saved spawn point.
class HabitatCatMotion {
  HabitatCatMotion(this.anchor) : current = anchor, next = anchor;

  (int, int) anchor;
  (int, int) current;
  (int, int) next;
  double progress = 0, pause = 0.8, animationTime = 0;
  int direction = 0;
  bool running = false;
  HabitatCatClip? reaction, queuedReaction;
  double reactionTime = 0;
  String? targetItemId, activity;
  (int, int, int)? targetPlacement;
  List<(int, int)> route = [];
  bool visiting = false, awaitingConsumption = false;
  double visitElapsed = 0, visitDuration = 8;
  Completer<bool>? _arrival;

  HabitatCatClip get clip {
    if (visiting) {
      if (activity == 'feed' && !awaitingConsumption) return HabitatCatClip.eat;
      if (activity == 'play') return HabitatCatClip.play;
      return HabitatCatClip.idle;
    }
    return reaction ??
        (current == next
            ? HabitatCatClip.idle
            : running
            ? HabitatCatClip.run
            : HabitatCatClip.walk);
  }

  Future<bool> goTo(
    String itemId,
    List<(int, int)> path,
    String action, {
    (int, int, int)? placement,
  }) {
    cancelVisit();
    targetItemId = itemId;
    targetPlacement = placement;
    activity = action;
    route = List.of(path);
    pause = 0;
    reaction = null;
    reactionTime = 0;
    _arrival = Completer<bool>();
    return _arrival!.future;
  }

  void cancelVisit() {
    if (_arrival != null && !_arrival!.isCompleted) _arrival!.complete(false);
    _arrival = null;
    targetItemId = activity = null;
    targetPlacement = null;
    route.clear();
    visiting = awaitingConsumption = false;
    visitElapsed = 0;
  }

  void finishFeeding() {
    awaitingConsumption = false;
    visitElapsed = animationTime = 0;
    visitDuration = 3;
  }

  void react(HabitatCatClip value) {
    if (current != next) {
      queuedReaction = value;
      return;
    }
    reaction = value;
    reactionTime = value == HabitatCatClip.dance ? 1.5 : 0.75;
    animationTime = 0;
  }

  void reset((int, int) cell) {
    cancelVisit();
    anchor = current = next = cell;
    progress = animationTime = reactionTime = 0;
    pause = 0.8;
    reaction = queuedReaction = null;
  }

  void advance(double dt, math.Random random, bool Function(int, int) free) {
    animationTime += dt;
    if (visiting) {
      visitElapsed += dt;
      if (!awaitingConsumption && visitElapsed >= visitDuration) {
        cancelVisit();
        pause = 1;
      }
      return;
    }
    if (reactionTime > 0) {
      reactionTime -= dt;
      if (reactionTime <= 0) reaction = null;
      return;
    }
    if (pause > 0) {
      pause -= dt;
      return;
    }
    if (current == next) {
      if (targetItemId != null && route.isEmpty) {
        visiting = true;
        awaitingConsumption = activity == 'feed';
        visitDuration = activity == 'play' ? 7.2 : 8;
        if (activity == 'play' && targetPlacement != null) {
          final dx = targetPlacement!.$1 - current.$1;
          final dy = targetPlacement!.$2 - current.$2;
          direction = dx.abs() >= dy.abs()
              ? (dx >= 0 ? 3 : 1)
              : (dy >= 0 ? 0 : 2);
        }
        visitElapsed = animationTime = 0;
        if (_arrival != null && !_arrival!.isCompleted) {
          _arrival!.complete(true);
        }
        return;
      }
      if (route.isNotEmpty) {
        next = route.removeAt(0);
        if (!free(next.$1, next.$2)) {
          next = current;
          cancelVisit();
          pause = 1;
          return;
        }
        running = false;
      } else {
        final neighbors = [
          (current.$1 + 1, current.$2),
          (current.$1 - 1, current.$2),
          (current.$1, current.$2 + 1),
          (current.$1, current.$2 - 1),
        ].where((cell) => free(cell.$1, cell.$2)).toList();
        if (neighbors.isEmpty) {
          pause = 1;
          return;
        }
        next = neighbors[random.nextInt(neighbors.length)];
        running = random.nextDouble() < 0.18;
      }
      direction = next.$1 > current.$1
          ? 3
          : next.$1 < current.$1
          ? 1
          : next.$2 > current.$2
          ? 0
          : 2;
      animationTime = 0;
    }
    progress += dt / (running ? 0.5 : 1.0);
    if (progress >= 1) {
      current = next;
      progress = animationTime = 0;
      pause = targetItemId == null ? 0.5 + random.nextDouble() * 1.3 : 0;
      if (queuedReaction case final value?) {
        queuedReaction = null;
        react(value);
      }
    }
  }
}
