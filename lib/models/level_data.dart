import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'level_model.dart';

class LevelData {
  static const List<Color> themeColors = [
    Color(0xFFE52521), // Red
    Color(0xFFF39200), // Orange
    Color(0xFFE5B700), // Yellow/Gold
    Color(0xFF43B02A), // Green
    Color(0xFF00A3E0), // Cyan/Blue
    Color(0xFF0038A8), // Royal Blue
    Color(0xFF7F44AB), // Violet/Purple
    Color(0xFFD61A5E), // Pink/Magenta
    Color(0xFF009639), // Emerald
    Color(0xFFE93CAC), // Coral/Hot Pink
    Color(0xFF00A88F), // Mint/Teal
    Color(0xFFE25B45), // Terracotta
  ];

  // Procedural list of 300 levels generated lazily to prevent page freeze
  static final List<Level> levels = LazyLevelList();

  static Level _generateLevel(int id) {
    // Scaling Grid Size and Checkpoint Counts
    int gridSize = 4;
    int checkpointsCount = 4;
    String difficulty = 'Intro';

    if (id <= 10) {
      gridSize = 4;
      checkpointsCount = 4;
      difficulty = 'Intro';
    } else if (id <= 30) {
      gridSize = 5;
      checkpointsCount = 5 + (id % 2); // 5 or 6
      difficulty = 'Easy';
    } else if (id <= 80) {
      gridSize = 6;
      checkpointsCount = 7 + (id % 3); // 7, 8, or 9
      difficulty = 'Medium';
    } else if (id <= 150) {
      gridSize = 7;
      checkpointsCount = 10 + (id % 3); // 10, 11, or 12
      difficulty = 'Hard';
    } else {
      gridSize = 8;
      checkpointsCount = 13 + (id % 2); // 13 or 14 (Capped at 14!)
      difficulty = 'Expert';
    }

    final rand = Random(id * 7890); // Seed for deterministic generation per level

    // Search for a valid Hamiltonian Path
    List<GridPos>? path;
    int attempts = 0;
    while (path == null && attempts < 100) {
      path = _findRandomHamiltonianPath(gridSize, rand);
      attempts++;
    }

    // Snake Fallback
    if (path == null) {
      path = [];
      for (int y = 0; y < gridSize; y++) {
        if (y % 2 == 0) {
          for (int x = 0; x < gridSize; x++) {
            path.add(GridPos(x, y));
          }
        } else {
          for (int x = gridSize - 1; x >= 0; x--) {
            path.add(GridPos(x, y));
          }
        }
      }
    }

    // Distribute Checkpoints
    final Map<int, GridPos> checkpoints = {};
    checkpoints[1] = path.first;

    final intermediateIndices = <int>{};
    final totalCells = gridSize * gridSize;
    final step = (totalCells - 2) / (checkpointsCount - 1);

    for (int i = 1; i < checkpointsCount - 1; i++) {
      double targetIndex = i * step;
      int indexOffset = rand.nextInt(3) - 1; // -1, 0, or 1
      int idx = (targetIndex + indexOffset).round().clamp(1, totalCells - 2);
      intermediateIndices.add(idx);
    }

    final sortedIndices = intermediateIndices.toList()..sort();
    for (int i = 0; i < sortedIndices.length; i++) {
      checkpoints[i + 2] = path[sortedIndices[i]];
    }
    checkpoints[checkpointsCount] = path.last;

    // Generate dynamic walls that don't block the solution path
    final List<Wall> walls = [];
    final wallChance = gridSize >= 6 ? 0.14 : 0.06;
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        final current = GridPos(x, y);
        if (x < gridSize - 1 && rand.nextDouble() < wallChance) {
          final neighbor = GridPos(x + 1, y);
          if (!_areConsecutiveInPath(path, current, neighbor)) {
            walls.add(Wall(current, neighbor));
          }
        }
        if (y < gridSize - 1 && rand.nextDouble() < wallChance) {
          final neighbor = GridPos(x, y + 1);
          if (!_areConsecutiveInPath(path, current, neighbor)) {
            walls.add(Wall(current, neighbor));
          }
        }
      }
    }

    return Level(
      id: id,
      gridSize: gridSize,
      themeColor: themeColors[(id - 1) % themeColors.length],
      difficulty: difficulty,
      checkpoints: checkpoints,
      walls: walls,
    );
  }

  static bool _areConsecutiveInPath(List<GridPos> path, GridPos a, GridPos b) {
    final idxA = path.indexOf(a);
    final idxB = path.indexOf(b);
    if (idxA == -1 || idxB == -1) return false;
    return (idxA - idxB).abs() == 1;
  }

  static List<GridPos>? _findRandomHamiltonianPath(int gridSize, Random rand) {
    final totalCells = gridSize * gridSize;
    final start = GridPos(rand.nextInt(gridSize), rand.nextInt(gridSize));
    final List<GridPos> path = [start];
    final Set<GridPos> visited = {start};

    int steps = 0;
    const maxSteps = 2000; // Cap search depth/backtracks to prevent page freeze on large grids

    bool dfs(GridPos current) {
      steps++;
      if (steps > maxSteps) {
        return false;
      }
      if (path.length == totalCells) {
        return true;
      }

      final directions = [
        GridPos(1, 0),
        GridPos(-1, 0),
        GridPos(0, 1),
        GridPos(0, -1),
      ]..shuffle(rand);

      for (final dir in directions) {
        final next = GridPos(current.x + dir.x, current.y + dir.y);
        if (next.x >= 0 && next.x < gridSize && next.y >= 0 && next.y < gridSize) {
          if (!visited.contains(next)) {
            visited.add(next);
            path.add(next);
            if (dfs(next)) return true;
            path.removeLast();
            visited.remove(next);
          }
        }
      }
      return false;
    }

    if (dfs(start)) {
      return path;
    }
    return null;
  }

  // Caching solved paths
  static final Map<int, List<GridPos>> solutions = {};

  static List<GridPos> getSolutionForLevel(Level level) {
    if (solutions.containsKey(level.id)) {
      return solutions[level.id]!;
    }

    final start = level.checkpoints[1]!;
    List<GridPos> path = [start];
    
    int steps = 0;
    const maxSolveSteps = 5000; // Cap steps to prevent freeze on complex puzzles

    bool solve(GridPos current, int checkpointTarget) {
      steps++;
      if (steps > maxSolveSteps) return false;

      if (path.length == level.gridSize * level.gridSize) {
        return checkpointTarget > level.checkpoints.length;
      }

      final neighbors = [
        GridPos(current.x + 1, current.y),
        GridPos(current.x - 1, current.y),
        GridPos(current.x, current.y + 1),
        GridPos(current.x, current.y - 1),
      ];

      for (final next in neighbors) {
        if (next.x < 0 || next.x >= level.gridSize || next.y < 0 || next.y >= level.gridSize) continue;
        if (path.contains(next)) continue;
        if (level.hasWallBetween(current, next)) continue;

        int? checkpointNum;
        level.checkpoints.forEach((number, pos) {
          if (pos == next) checkpointNum = number;
        });

        int nextTarget = checkpointTarget;
        if (checkpointNum != null) {
          if (checkpointNum != checkpointTarget) continue;
          nextTarget = checkpointTarget + 1;
        }

        path.add(next);
        if (solve(next, nextTarget)) return true;
        path.removeLast();
      }
      return false;
    }

    if (solve(start, 2)) {
      solutions[level.id] = path;
      return path;
    }
    return [start];
  }

  static Level generateCustomLevel({required int seed, required int gridSize}) {
    int checkpointsCount = 4;
    String difficulty = 'Medium';

    if (gridSize == 4) {
      checkpointsCount = 4;
      difficulty = 'Intro';
    } else if (gridSize == 5) {
      checkpointsCount = 5;
      difficulty = 'Easy';
    } else if (gridSize == 6) {
      checkpointsCount = 7;
      difficulty = 'Medium';
    } else if (gridSize == 7) {
      checkpointsCount = 10;
      difficulty = 'Hard';
    } else {
      checkpointsCount = 13;
      difficulty = 'Expert';
    }

    final rand = Random(seed);

    List<GridPos>? path;
    int attempts = 0;
    while (path == null && attempts < 100) {
      path = _findRandomHamiltonianPath(gridSize, rand);
      attempts++;
    }

    if (path == null) {
      path = [];
      for (int y = 0; y < gridSize; y++) {
        if (y % 2 == 0) {
          for (int x = 0; x < gridSize; x++) {
            path.add(GridPos(x, y));
          }
        } else {
          for (int x = gridSize - 1; x >= 0; x--) {
            path.add(GridPos(x, y));
          }
        }
      }
    }

    final Map<int, GridPos> checkpoints = {};
    checkpoints[1] = path.first;

    final intermediateIndices = <int>{};
    final totalCells = gridSize * gridSize;
    final step = (totalCells - 2) / (checkpointsCount - 1);

    for (int i = 1; i < checkpointsCount - 1; i++) {
      double targetIndex = i * step;
      int indexOffset = rand.nextInt(3) - 1;
      int idx = (targetIndex + indexOffset).round().clamp(1, totalCells - 2);
      intermediateIndices.add(idx);
    }

    final sortedIndices = intermediateIndices.toList()..sort();
    for (int i = 0; i < sortedIndices.length; i++) {
      checkpoints[i + 2] = path[sortedIndices[i]];
    }
    checkpoints[checkpointsCount] = path.last;

    final List<Wall> walls = [];
    final wallChance = gridSize >= 6 ? 0.14 : 0.06;
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        final current = GridPos(x, y);
        if (x < gridSize - 1 && rand.nextDouble() < wallChance) {
          final neighbor = GridPos(x + 1, y);
          if (!_areConsecutiveInPath(path, current, neighbor)) {
            walls.add(Wall(current, neighbor));
          }
        }
        if (y < gridSize - 1 && rand.nextDouble() < wallChance) {
          final neighbor = GridPos(x, y + 1);
          if (!_areConsecutiveInPath(path, current, neighbor)) {
            walls.add(Wall(current, neighbor));
          }
        }
      }
    }

    final customLevel = Level(
      id: -seed.abs(),
      gridSize: gridSize,
      themeColor: themeColors[seed.abs() % themeColors.length],
      difficulty: difficulty,
      checkpoints: checkpoints,
      walls: walls,
    );

    solutions[customLevel.id] = path;

    return customLevel;
  }
}

class LazyLevelList extends ListBase<Level> {
  final Map<int, Level> _cache = {};

  @override
  int get length => 300;

  @override
  set length(int newLength) => throw UnsupportedError("Cannot modify length of levels list");

  @override
  Level operator [](int index) {
    final id = index + 1;
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }
    debugPrint('[LevelData] Lazily generating level $id (Index: $index)...');
    final lvl = LevelData._generateLevel(id);
    _cache[id] = lvl;
    return lvl;
  }

  @override
  void operator []=(int index, Level value) => throw UnsupportedError("Cannot modify levels list");
}
