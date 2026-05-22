import 'package:flutter/material.dart';

/// Safe scroll metrics for widgets built before the list attaches.
bool scrollShowsDownFab(ScrollController controller, double threshold) {
  if (!controller.hasClients) return false;
  final positions = controller.positions;
  if (positions.isEmpty) return false;
  final pos = positions.last;
  if (!pos.hasContentDimensions) return false;
  return pos.maxScrollExtent - pos.pixels > threshold;
}
