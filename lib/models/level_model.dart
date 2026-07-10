import 'package:flutter/material.dart';

class GridPos {
  final int x;
  final int y;

  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPos && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => '($x, $y)';

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory GridPos.fromJson(Map<String, dynamic> json) => GridPos(json['x'] as int, json['y'] as int);
}

class Wall {
  final GridPos pos1;
  final GridPos pos2;

  const Wall(this.pos1, this.pos2);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Wall) return false;
    // Order independent equality because walls are bidirectional
    return (pos1 == other.pos1 && pos2 == other.pos2) ||
        (pos1 == other.pos2 && pos2 == other.pos1);
  }

  @override
  int get hashCode => pos1.hashCode ^ pos2.hashCode;

  @override
  String toString() => 'Wall{$pos1 <-> $pos2}';
}

class Level {
  final int id;
  final int gridSize; // E.g., 6 for a 6x6 grid
  final Map<int, GridPos> checkpoints; // checkpoint number -> position
  final List<Wall> walls;
  final Color themeColor;
  final String difficulty;

  const Level({
    required this.id,
    required this.gridSize,
    required this.checkpoints,
    required this.walls,
    required this.themeColor,
    required this.difficulty,
  });

  // Checks if pos1 and pos2 are adjacent and separated by a wall
  bool hasWallBetween(GridPos pos1, GridPos pos2) {
    return walls.contains(Wall(pos1, pos2));
  }
}
