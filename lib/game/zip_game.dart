import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/level_model.dart';

class ZipGame extends FlameGame with DragCallbacks {
  final GameState gameState;
  final VoidCallback onLevelComplete;

  late ZipBoardComponent boardComponent;

  ZipGame({
    required this.gameState,
    required this.onLevelComplete,
  });

  @override
  Color backgroundColor() => Colors.white;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Center the board on screen
    final sizeOfBoard = min(size.x, size.y) * 0.9;
    boardComponent = ZipBoardComponent(
      gameState: gameState,
      boardSize: sizeOfBoard,
      onComplete: onLevelComplete,
    );

    // Position in center
    boardComponent.position = (size - Vector2.all(sizeOfBoard)) / 2;
    add(boardComponent);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final sizeOfBoard = min(size.x, size.y) * 0.9;
      boardComponent.size = Vector2.all(sizeOfBoard);
      boardComponent.position = (size - Vector2.all(sizeOfBoard)) / 2;
      boardComponent.resizeBoard(sizeOfBoard);
    }
  }
}

class ZipBoardComponent extends PositionComponent with DragCallbacks, TapCallbacks {
  final GameState gameState;
  final VoidCallback onComplete;
  double boardSize;

  late double cellSize;
  bool isDragging = false;
  bool completedTriggered = false;

  // Visual style constants
  final double gridBorderWidth = 1.0;
  final Color gridLineColor = const Color(0xFFD3D3D3);
  final Color wallColor = const Color(0xFF000000);
  final double wallWidth = 6.0;

  ZipBoardComponent({
    required this.gameState,
    required this.boardSize,
    required this.onComplete,
  }) : super(size: Vector2.all(boardSize)) {
    cellSize = boardSize / gameState.level.gridSize;
    gameState.addListener(_onStateChanged);
  }

  void resizeBoard(double newSize) {
    boardSize = newSize;
    cellSize = boardSize / gameState.level.gridSize;
  }

  void _onStateChanged() {
    if (gameState.isSolved) {
      if (!completedTriggered) {
        completedTriggered = true;
        onComplete();
      }
    } else {
      completedTriggered = false;
    }
  }

  @override
  void onRemove() {
    gameState.removeListener(_onStateChanged);
    super.onRemove();
  }

  // Convert canvas touch coordinates to grid coordinates
  GridPos? getGridPosFromLocal(Vector2 localPos) {
    final x = (localPos.x / cellSize).floor();
    final y = (localPos.y / cellSize).floor();
    if (x >= 0 && x < gameState.level.gridSize && y >= 0 && y < gameState.level.gridSize) {
      return GridPos(x, y);
    }
    return null;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (gameState.isSolved) return;
    final gridPos = getGridPosFromLocal(event.localPosition);
    if (gridPos != null) {
      if (gameState.path.contains(gridPos)) {
        gameState.truncateTo(gridPos);
      } else {
        gameState.tryMoveTo(gridPos);
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (gameState.isSolved) return;

    final gridPos = getGridPosFromLocal(event.localPosition);
    if (gridPos != null) {
      // Start drag if touching the end of the current path, or if path is reset, checkpoint 1
      if (gameState.path.isNotEmpty && gameState.path.last == gridPos) {
        isDragging = true;
      } else if (gameState.path.isEmpty && gameState.level.checkpoints[1] == gridPos) {
        isDragging = true;
        gameState.tryMoveTo(gridPos);
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!isDragging || gameState.isSolved) return;

    final gridPos = getGridPosFromLocal(event.localEndPosition);
    if (gridPos != null && (gameState.path.isEmpty || gameState.path.last != gridPos)) {
      gameState.tryMoveTo(gridPos);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    isDragging = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final level = gameState.level;
    final int size = level.gridSize;

    // 1. Draw Cell Backgrounds (translucent highlight for visited cells)
    final pathBgPaint = Paint()
      ..color = level.themeColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        final pos = GridPos(x, y);
        if (gameState.isVisited(pos)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
              const Radius.circular(8),
            ),
            pathBgPaint,
          );
        }
      }
    }

    // 2. Draw Grid Borders
    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = gridBorderWidth
      ..style = PaintingStyle.stroke;

    // Draw thin grid lines
    for (int i = 0; i <= size; i++) {
      // Vertical line
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, boardSize),
        gridPaint,
      );
      // Horizontal line
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(boardSize, i * cellSize),
        gridPaint,
      );
    }

    // 3. Draw Path Lines
    if (gameState.path.length > 1) {
      final pathPaint = Paint()
        ..color = level.themeColor
        ..strokeWidth = cellSize * 0.38
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final startCenter = _getCellCenter(gameState.path.first);
      path.moveTo(startCenter.dx, startCenter.dy);

      for (int i = 1; i < gameState.path.length; i++) {
        final center = _getCellCenter(gameState.path[i]);
        path.lineTo(center.dx, center.dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    // 4. Draw Walls (Thick Black Lines)
    final wallPaint = Paint()
      ..color = wallColor
      ..strokeWidth = wallWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final wall in level.walls) {
      final p1 = wall.pos1;
      final p2 = wall.pos2;
      
      // Determine the boundary edge between pos1 and pos2
      if (p1.x == p2.x) {
        // Vertical wall boundary (between row y1 and row y2)
        final yBound = max(p1.y, p2.y) * cellSize;
        final xStart = p1.x * cellSize;
        final xEnd = (p1.x + 1) * cellSize;
        canvas.drawLine(Offset(xStart, yBound), Offset(xEnd, yBound), wallPaint);
      } else if (p1.y == p2.y) {
        // Horizontal wall boundary (between col x1 and col x2)
        final xBound = max(p1.x, p2.x) * cellSize;
        final yStart = p1.y * cellSize;
        final yEnd = (p1.y + 1) * cellSize;
        canvas.drawLine(Offset(xBound, yStart), Offset(xBound, yEnd), wallPaint);
      }
    }

    // 5. Draw Checkpoints (Numbered black circles)
    final checkpointPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final double dotRadius = cellSize * 0.25;

    level.checkpoints.forEach((number, pos) {
      final center = _getCellCenter(pos);
      canvas.drawCircle(center, dotRadius, checkpointPaint);

      // Draw number text
      final textSpan = TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: cellSize * 0.26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    });
  }

  Offset _getCellCenter(GridPos pos) {
    return Offset(
      pos.x * cellSize + cellSize / 2,
      pos.y * cellSize + cellSize / 2,
    );
  }
}
