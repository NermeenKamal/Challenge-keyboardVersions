import 'package:flutter/material.dart';
import 'dart:math';

class HexKeyboardPainter extends StatelessWidget {
  final List<List<String?>> layout;
  final double hexRadius;
  final Map<String, Color> letterColors; // لون كل حرف (أو null)
  final Color borderColor;
  final double borderWidth;
  final Color emptyColor;
  final Color textColor;
  final Color bgColor;
  final double fontScale;
  final void Function(String letter)? onKeyPressed; // إضافة callback للتفاعل
  final Set<String> flashingKeys;
  final String? selectedHexKey;
  final Map<String, String> keyTeamColors;

  const HexKeyboardPainter({
    Key? key,
    required this.layout,
    this.hexRadius = 32,
    required this.letterColors,
    this.borderColor = Colors.black,
    this.borderWidth = 4,
    this.emptyColor = const Color(0xFFE3ECF7),
    this.textColor = const Color(0xFF0D2474),
    this.bgColor = const Color(0xFFE3ECF7),
    this.fontScale = 0.7,
    this.onKeyPressed,
    this.flashingKeys = const {},
    this.selectedHexKey,
    this.keyTeamColors = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rows = layout.length;
    final cols = layout[0].length;
    final hexHeight = hexRadius * 2;
    final hexWidth = sqrt(3) * hexRadius;
    final gridHeight = hexHeight * (0.75 * (rows - 1) + 1);
    final gridWidth = hexWidth * cols;

    return GestureDetector(
      onTapDown: (details) {
        // حساب أي حرف تم الضغط عليه
        final localPosition = details.localPosition;
        final tappedLetter =
            _getLetterAtPosition(localPosition, hexRadius, hexWidth, hexHeight);
        if (tappedLetter != null && onKeyPressed != null) {
          onKeyPressed!(tappedLetter);
        }
      },
      child: Container(
        color: bgColor,
        width: gridWidth,
        height: gridHeight,
        child: CustomPaint(
          size: Size(gridWidth, gridHeight),
          painter: _HexGridPainter(
            layout: layout,
            hexRadius: hexRadius,
            letterColors: letterColors,
            borderColor: borderColor,
            borderWidth: borderWidth,
            emptyColor: emptyColor,
            textColor: textColor,
            fontScale: fontScale,
            flashingKeys: flashingKeys,
            selectedHexKey: selectedHexKey,
            keyTeamColors: keyTeamColors,
          ),
        ),
      ),
    );
  }

  String? _getLetterAtPosition(
      Offset position, double hexRadius, double hexWidth, double hexHeight) {
    final rows = layout.length;
    final cols = layout[0].length;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final String? letter = layout[row][col];
        if (letter == null) continue;

        final dx = col * hexWidth + (row % 2 == 1 ? hexWidth / 2 : 0);
        final dy = row * hexHeight * 0.75 + hexRadius;
        final center = Offset(dx, dy);

        // حساب المسافة من المركز مع هامش أكبر للتفاعل
        final distance = (position - center).distance;
        if (distance <= hexRadius * 1.2) {
          // زيادة منطقة التفاعل بنسبة 20%
          return letter;
        }
      }
    }
    return null;
  }
}

class _HexGridPainter extends CustomPainter {
  final List<List<String?>> layout;
  final double hexRadius;
  final Map<String, Color> letterColors;
  final Color borderColor;
  final double borderWidth;
  final Color emptyColor;
  final Color textColor;
  final double fontScale;
  final Set<String> flashingKeys;
  final String? selectedHexKey;
  final Map<String, String> keyTeamColors;

  _HexGridPainter({
    required this.layout,
    required this.hexRadius,
    required this.letterColors,
    required this.borderColor,
    required this.borderWidth,
    required this.emptyColor,
    required this.textColor,
    required this.fontScale,
    required this.flashingKeys,
    required this.selectedHexKey,
    required this.keyTeamColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hexHeight = hexRadius * 2;
    final hexWidth = sqrt(3) * hexRadius;
    final rows = layout.length;
    final cols = layout[0].length;
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final String? letter = layout[row][col];
        final dx = col * hexWidth + (row % 2 == 1 ? hexWidth / 2 : 0);
        final dy = row * hexHeight * 0.75 + hexRadius;
        final center = Offset(dx, dy);
        final key = '$row-$col';
        if (letter == null) {
          bool isTop = row == 0;
          bool isBottom = row == rows - 1;
          bool isLeft = col == 0;
          bool isRight = col == cols - 1;
          Color fillColor;
          if (isTop || isBottom) {
            fillColor = Color(0xFF43A047); // أخضر
          } else if (isLeft || isRight) {
            fillColor = Color(0xFFE53935); // أحمر
          } else {
            fillColor = Color(0xFF1E90FF); // أزرق قوي وواضح للفراغات الداخلية
          }
          final hexPath = _hexPath(center, hexRadius);
          final paint = Paint()
            ..color = fillColor
            ..style = PaintingStyle.fill;
          canvas.drawPath(hexPath, paint);
          final borderPaint = Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth;
          canvas.drawPath(hexPath, borderPaint);
          continue;
        }
        // الحروف/الأرقام
        Color fillColor = letterColors[letter] ?? Color(0xFFFFF9C4);
        // تلوين حسب الفريق
        if (keyTeamColors.containsKey(key)) {
          if (keyTeamColors[key] == 'red') {
            fillColor = Colors.red[300]!;
          } else if (keyTeamColors[key] == 'green') {
            fillColor = Colors.green[300]!;
          }
        }
        // إذا كان الحرف/الرقم في حالة وميض، غيّر اللون
        if (flashingKeys.contains(key)) {
          fillColor = const Color(0xFF90CAF9); // أزرق فاتح جدًا عند الضغط
        }
        final hexPath = _hexPath(center, hexRadius);
        final paint = Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(hexPath, paint);
        // إذا كانت الخلية محددة (selected)
        if (selectedHexKey == key) {
          final selectedPaint = Paint()
            ..color = Colors.blueAccent.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth + 3;
          canvas.drawPath(hexPath, selectedPaint);
        } else {
          final borderPaint = Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth;
          canvas.drawPath(hexPath, borderPaint);
        }
        textPainter.text = TextSpan(
          text: letter,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize:
                hexRadius * 0.7 * fontScale, // استخدام fontScale بشكل صحيح
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 2,
                offset: Offset(0.5, 1.0),
              ),
            ],
          ),
        );
        textPainter.layout();
        final textOffset =
            center - Offset(textPainter.width / 2, textPainter.height / 2);
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i - pi / 6;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
