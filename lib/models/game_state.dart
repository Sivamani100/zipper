import 'package:flutter/material.dart';
import 'level_model.dart';
import '../utils/audio_manager.dart';

class GameState extends ChangeNotifier {
  final Level level;
  List<GridPos> path = [];
  List<List<GridPos>> undoHistory = [];
  bool isSolved = false;

  // The pre-defined solution path for hints
  final List<GridPos> solutionPath;

  GameState({
    required this.level,
    required this.solutionPath,
  }) {
    // Start the path at checkpoint 1
    final startPos = level.checkpoints[1];
    if (startPos != null) {
      path.add(startPos);
    }
  }

  // Get the next checkpoint number that we need to reach
  int get nextCheckpointTarget {
    // Find the highest checkpoint number currently in the path
    int maxReached = 1;
    for (var i = 0; i < path.length; i++) {
      final pos = path[i];
      // Check if this position is a checkpoint
      level.checkpoints.forEach((number, checkpointPos) {
        if (pos == checkpointPos && number > maxReached) {
          // Verify that all checkpoints before this one are also in the path
          bool allPriorInPath = true;
          for (int j = 1; j < number; j++) {
            if (!path.contains(level.checkpoints[j])) {
              allPriorInPath = false;
              break;
            }
          }
          if (allPriorInPath) {
            maxReached = number;
          }
        }
      });
    }

    if (maxReached < level.checkpoints.length) {
      return maxReached + 1;
    }
    return -1; // All checkpoints reached
  }

  // Check if a cell is visited
  bool isVisited(GridPos pos) {
    return path.contains(pos);
  }

  // Save the current path to undo history
  void saveToUndoHistory() {
    undoHistory.add(List.from(path));
    if (undoHistory.length > 50) {
      undoHistory.removeAt(0);
    }
  }

  // Try to add a cell to the path (handles both adjacent moves and straight-line corridor zips)
  bool tryMoveTo(GridPos nextPos) {
    if (isSolved) return false;
    if (path.isEmpty) return false;
    final currentPos = path.last;

    // If nextPos is already in the path, truncate back to it
    if (path.contains(nextPos)) {
      final index = path.indexOf(nextPos);
      if (index < path.length - 1) {
        debugPrint('[GameState] Truncating path back to: $nextPos (Index: $index)');
        saveToUndoHistory();
        path = path.sublist(0, index + 1);
        checkCompletion();
        notifyListeners();
        AudioManager.playClick();
        return true;
      }
      return false; // Already the last element, no move needed
    }

    // Check if it's adjacent (single step)
    final dx = (nextPos.x - currentPos.x).abs();
    final dy = (nextPos.y - currentPos.y).abs();
    final isAdjacent = (dx == 1 && dy == 0) || (dx == 0 && dy == 1);

    if (isAdjacent) {
      if (!_isValidMove(currentPos, nextPos, path)) {
        return false;
      }
      debugPrint('[GameState] Path extended to: $nextPos');
      saveToUndoHistory();
      path.add(nextPos);
      checkCompletion();
      notifyListeners();
      AudioManager.playClick();
      return true;
    } else {
      // Not adjacent. Check if it's in the same row or column (corridor zip!)
      final isSameRow = currentPos.y == nextPos.y;
      final isSameCol = currentPos.x == nextPos.x;
      if (!isSameRow && !isSameCol) {
        return false;
      }

      final diffX = nextPos.x - currentPos.x;
      final diffY = nextPos.y - currentPos.y;
      final stepX = diffX == 0 ? 0 : (diffX > 0 ? 1 : -1);
      final stepY = diffY == 0 ? 0 : (diffY > 0 ? 1 : -1);
      final stepsCount = diffX == 0 ? diffY.abs() : diffX.abs();

      List<GridPos> tempPath = List.from(path);
      bool allSucceeded = true;

      for (int i = 1; i <= stepsCount; i++) {
        final intermediatePos = GridPos(currentPos.x + stepX * i, currentPos.y + stepY * i);
        if (!_isValidMove(tempPath.last, intermediatePos, tempPath)) {
          allSucceeded = false;
          break;
        }
        tempPath.add(intermediatePos);
      }

      if (allSucceeded) {
        debugPrint('[GameState] Corridor zip to: $nextPos');
        saveToUndoHistory();
        path = tempPath;
        checkCompletion();
        notifyListeners();
        AudioManager.playClick();
        return true;
      }
      return false;
    }
  }

  // Single step validation helper
  bool _isValidMove(GridPos from, GridPos to, List<GridPos> currentPath) {
    // Check if the highest checkpoint has already been reached in the path
    final highestCheckpointNum = level.checkpoints.length;
    final highestCheckpointPos = level.checkpoints[highestCheckpointNum];
    if (highestCheckpointPos != null && currentPath.contains(highestCheckpointPos)) {
      return false;
    }

    // Bounds check
    if (to.x < 0 || to.x >= level.gridSize || to.y < 0 || to.y >= level.gridSize) {
      return false;
    }

    // Wall check
    if (level.hasWallBetween(from, to)) {
      return false;
    }

    // Path collision check
    if (currentPath.contains(to)) {
      return false;
    }

    // Checkpoint sequential verification
    int? checkpointNum;
    level.checkpoints.forEach((number, pos) {
      if (pos == to) checkpointNum = number;
    });

    if (checkpointNum != null) {
      final target = _getNextCheckpointTargetForPath(currentPath);
      if (checkpointNum != target) {
        return false;
      }
    }

    return true;
  }

  // Helper to find target checkpoint relative to a temporary path representation
  int _getNextCheckpointTargetForPath(List<GridPos> currentPath) {
    int maxReached = 1;
    for (var i = 0; i < currentPath.length; i++) {
      final pos = currentPath[i];
      level.checkpoints.forEach((number, checkpointPos) {
        if (pos == checkpointPos && number > maxReached) {
          bool allPriorInPath = true;
          for (int j = 1; j < number; j++) {
            if (!currentPath.contains(level.checkpoints[j])) {
              allPriorInPath = false;
              break;
            }
          }
          if (allPriorInPath) {
            maxReached = number;
          }
        }
      });
    }

    if (maxReached < level.checkpoints.length) {
      return maxReached + 1;
    }
    return -1;
  }

  // Check if the puzzle is completed
  void checkCompletion() {
    // 1. All cells in the grid must be visited
    final totalCells = level.gridSize * level.gridSize;
    if (path.length != totalCells) {
      isSolved = false;
      return;
    }

    // 2. All checkpoints must be connected in order
    // (nextCheckpointTarget returns -1 when all checkpoints are successfully reached in order)
    if (nextCheckpointTarget != -1) {
      isSolved = false;
      return;
    }

    isSolved = true;
  }

  // Undo the last drawing action
  void undo() {
    if (undoHistory.isNotEmpty) {
      path = undoHistory.removeLast();
      debugPrint('[GameState] Undo triggered. Path reverted (Length: ${path.length})');
      isSolved = false;
      notifyListeners();
      AudioManager.playClick();
    }
  }

  // Reset the path back to the starting checkpoint
  void reset() {
    saveToUndoHistory();
    path.clear();
    final startPos = level.checkpoints[1];
    if (startPos != null) {
      path.add(startPos);
    }
    isSolved = false;
    notifyListeners();
    AudioManager.playClick();
  }

  // Apply a hint: extends the path up to the next checkpoint matching the solution path
  void applyHint() {
    if (isSolved || solutionPath.isEmpty) return;

    // Check how much of our current path matches the solution path from the start
    int matchLength = 0;
    for (int i = 0; i < path.length; i++) {
      if (i < solutionPath.length && path[i] == solutionPath[i]) {
        matchLength++;
      } else {
        break;
      }
    }

    // If the path deviates from the solution, revert to the last matching position
    if (matchLength < path.length) {
      saveToUndoHistory();
      path = List.from(solutionPath.sublist(0, matchLength));
    }

    // Find the next checkpoint target
    final targetNum = nextCheckpointTarget;
    if (targetNum == -1) {
      // All checkpoints reached, but maybe not all cells visited. Zip to end of solution.
      saveToUndoHistory();
      path = List.from(solutionPath);
      checkCompletion();
      notifyListeners();
      AudioManager.playClick();
      return;
    }

    final targetPos = level.checkpoints[targetNum];
    if (targetPos == null) return;

    // Find where the target checkpoint is in the solutionPath
    int targetIdxInSolution = solutionPath.indexOf(targetPos);
    if (targetIdxInSolution == -1 || targetIdxInSolution < matchLength) {
      // Fallback: just add one step
      if (matchLength < solutionPath.length) {
        saveToUndoHistory();
        path.add(solutionPath[matchLength]);
        checkCompletion();
        notifyListeners();
        AudioManager.playClick();
      }
      return;
    }

    // Add all cells from matchLength up to the target checkpoint index
    saveToUndoHistory();
    for (int i = matchLength; i <= targetIdxInSolution; i++) {
      path.add(solutionPath[i]);
    }
    checkCompletion();
    notifyListeners();
    AudioManager.playClick();
  }

  // Truncate path to a specific position (e.g. on direct tap)
  bool truncateTo(GridPos pos) {
    if (isSolved) return false;
    if (path.contains(pos)) {
      final index = path.indexOf(pos);
      if (index < path.length - 1) {
        saveToUndoHistory();
        path = path.sublist(0, index + 1);
        checkCompletion();
        notifyListeners();
        AudioManager.playClick();
        return true;
      }
    }
    return false;
  }
}
