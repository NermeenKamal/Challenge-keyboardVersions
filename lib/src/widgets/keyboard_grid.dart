import 'package:flutter/material.dart';
import 'package:hexagon/hexagon.dart';
import '../game_provider.dart';
import 'dart:math';
import 'hex_keyboard_painter.dart';

class KeyboardGrid extends StatefulWidget {
  final String highlightLetter;
  final Map<String, Team> letterStatus;
  final void Function(String letter)? onKeyPressed;
  final double keyWidth;
  final List<String>? winnerPathLetters; // الحروف التي تمثل المسار الفائز
  final List<List<String?>> hexKeyboardLayout;
  final bool isWinnerPathFlashing;
  final double winnerFlashValue;
  const KeyboardGrid({
    super.key,
    required this.highlightLetter,
    required this.letterStatus,
    this.onKeyPressed,
    this.keyWidth = 44,
    this.winnerPathLetters,
    required this.hexKeyboardLayout,
    this.isWinnerPathFlashing = false,
    this.winnerFlashValue = 0.0,
  });

  @override
  State<KeyboardGrid> createState() => _KeyboardGridState();
}

class _KeyboardGridState extends State<KeyboardGrid>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _colorTween;
  late AnimationController _winnerController;
  late Animation<double> _winnerTween;

  // متغير لتتبع الحرف المضغوط
  String? _flashingLetter;

  void _flashLetter(String letter) {
    setState(() => _flashingLetter = letter);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted && _flashingLetter == letter) {
        setState(() => _flashingLetter = null);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _colorTween = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _winnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _winnerTween = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _winnerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _winnerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KeyboardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.reset();
    _controller.repeat(reverse: true);
    if (oldWidget.winnerPathLetters != widget.winnerPathLetters) {
      _winnerController.reset();
      _winnerController.repeat(reverse: true);
    }
  }

  final Color yellowCell = const Color(0xFFFFF9C4); // أصفر فاتح
  final Color redSide = const Color(0xFFE53935); // أحمر جانبي
  final Color greenSide = const Color(0xFF43A047); // أخضر جانبي
  final Color borderColor =
      const Color.fromARGB(71, 0, 0, 0); // حدود سوداء سميكة
  final Color textBlue = Color(0xFF0D2474); // أزرق غامق للنص
  final Color bgColor = Color(0xFFE3ECF7); // أزرق فاتح جدًا مشابه للمرجع

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rows = widget.hexKeyboardLayout.length;
    final cols = widget.hexKeyboardLayout[0].length;

    // تحسين حساب الحجم للعمل بشكل صحيح على الموبايل
    final availableWidth = screenWidth - 16; // هامش 8 بكسل من كل جانب
    final hexWidth = availableWidth / cols;
    final hexRadius =
        (hexWidth * 0.7) / sqrt(3); // تقليل الحجم أكثر لضمان عدم التداخل

    final Map<String, Color> letterColors = {};
    widget.letterStatus.forEach((letter, team) {
      if (team == Team.green) {
        letterColors[letter] = const Color(0xFF43A047);
      } else if (team == Team.red) {
        letterColors[letter] = const Color(0xFFE53935);
      }
    });

    return Container(
      width: screenWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: HexKeyboardPainter(
        layout: widget.hexKeyboardLayout,
        hexRadius: hexRadius,
        letterColors: letterColors,
        borderColor: const Color.fromARGB(71, 0, 0, 0),
        borderWidth: 2, // تقليل سمك الحدود
        emptyColor: const Color(0xFFE3ECF7),
        textColor: const Color(0xFF0D2474),
        bgColor: const Color(0xFFE3ECF7),
        fontScale: 1.2, // تقليل حجم الخط ليكون مناسباً للموبايل
        onKeyPressed: widget.onKeyPressed,
      ),
    );
  }

  Widget _buildHexCell({
    required String letter,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required double borderWidth,
    required double keyWidth,
    VoidCallback? onTap,
    bool shadow = false,
  }) {
    final isFlashing = _flashingLetter == letter;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isFlashing ? 0.4 : 1.0,
        child: HexagonWidget.flat(
          width: keyWidth,
          color: color,
          elevation: 2,
          padding: 0,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: keyWidth * 0.45,
                  color: textColor,
                  shadows: shadow
                      ? [
                          Shadow(
                            color: Colors.black.withOpacity(0.13),
                            blurRadius: 4,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool isWinnerPath(String letter) =>
      widget.winnerPathLetters?.contains(letter) == true;
}

class FlashScale extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double Function(double value) scaleBuilder;

  const FlashScale({
    Key? key,
    required this.child,
    required this.animation,
    required this.scaleBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleBuilder(animation.value),
          child: child,
        );
      },
      child: child,
    );
  }
}
