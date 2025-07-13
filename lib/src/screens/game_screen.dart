import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game_provider.dart';
import '../widgets/keyboard_grid.dart';
import '../widgets/timer_bar.dart';
import '../widgets/question_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hexagon/hexagon.dart';

class WinnerDialog extends StatelessWidget {
  final String resultText;
  final Color resultColor;
  final String winnerTeam;
  final Color winnerColor;
  final double winnerFontSize;
  final bool isDraw;
  final bool showNextRound;
  final VoidCallback onRestart;

  const WinnerDialog({
    Key? key,
    required this.resultText,
    required this.resultColor,
    required this.winnerTeam,
    required this.winnerColor,
    required this.winnerFontSize,
    required this.isDraw,
    required this.showNextRound,
    required this.onRestart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context, listen: true);
    final greenScore = game.greenScore;
    final redScore = game.redScore;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E90FF),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 140,
                  height: 140,
                ),
              ),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: Colors.white,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        resultText,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                          shadows: [
                            Shadow(
                              color: resultColor.withOpacity(0.18),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (isDraw)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'الفريق الأخضر',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[400],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Text(
                              'الفريق الأحمر',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[400],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      Text(
                        'النقاط - الأخضر: $greenScore | الأحمر: $redScore',
                        style: const TextStyle(
                            fontSize: 20, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // زر الجولة التالية أو إعادة اللعب
              showNextRound
                  ? ElevatedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('الجولة التالية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('إعادة اللعب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  String? _animLetter;
  bool _isCorrectAnim = false;
  bool _isWrongAnim = false;
  late AnimationController _fadeController;
  late AnimationController _shakeController;
  late AnimationController _greenScoreController;
  late AnimationController _redScoreController;
  late AnimationController _finalWinnerFlashController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool showStartButton = false;
  bool isPaused = false;
  int? _lastGreenScore;
  int? _lastRedScore;
  bool _roundWinSoundPlayed = false;
  bool _finalWinSoundPlayed = false;
  bool isWinnerPathFlashing = false;
  AnimationController? _winnerFlashController;
  bool showNextRoundButton = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _greenScoreController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _redScoreController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _finalWinnerFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _winnerFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shakeController.dispose();
    _greenScoreController.dispose();
    _redScoreController.dispose();
    _finalWinnerFlashController.dispose();
    _winnerFlashController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final game = Provider.of<GameProvider>(context, listen: false);
    _lastGreenScore = game.greenScore;
    _lastRedScore = game.redScore;
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final game = Provider.of<GameProvider>(context, listen: false);
    _lastGreenScore = game.greenScore;
    _lastRedScore = game.redScore;
  }

  void _animateScoreIfChanged(GameProvider game) {
    if (_lastGreenScore != null && game.greenScore > _lastGreenScore!) {
      _greenScoreController.forward(from: 0);
    }
    if (_lastRedScore != null && game.redScore > _lastRedScore!) {
      _redScoreController.forward(from: 0);
    }
    _lastGreenScore = game.greenScore;
    _lastRedScore = game.redScore;
  }

  Future<void> _playSoundMultiFormat(String base) async {
    final formats = ['mp3', 'ogg', 'wav', 'm4a'];
    for (final ext in formats) {
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/$base.$ext'), volume: 1.0);
        return;
      } catch (e) {
        // تجاهل الأخطاء في تشغيل الصوت
      }
    }
  }

  Future<void> _animateAnswerResult(
      {required bool correct, required String letter}) async {
    setState(() {
      _animLetter = letter;
      _isCorrectAnim = false;
      _isWrongAnim = false;
    });
    if (correct) {
      _isCorrectAnim = true;
      _fadeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _isCorrectAnim = false;
        _animLetter = null;
      });
    } else {
      _isWrongAnim = true;
      _shakeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _isWrongAnim = false;
        _animLetter = null;
      });
    }
  }

  void _handleKeyTap(BuildContext context, String letter) async {
    final game = Provider.of<GameProvider>(context, listen: false);
    if (game.answered || game.selectedTeam == Team.none) return;
    final isTarget = letter == game.currentQuestion?['letter'];
    if (isTarget) {
      game.selectOption(game.currentQuestion?['answer']);
      await _animateAnswerResult(correct: true, letter: letter);
      await _playSoundMultiFormat('correct');
    } else {
      await _animateAnswerResult(correct: false, letter: letter);
      await _playSoundMultiFormat('wrong');
    }
  }

  void _resetGame(BuildContext context) {
    final game = Provider.of<GameProvider>(context, listen: false);
    setState(() {
      showStartButton = true;
    });
    game.resetGame();
  }

  void _startGame(BuildContext context) {
    final game = Provider.of<GameProvider>(context, listen: false);
    setState(() {
      showStartButton = false;
    });
    game.resetGame();
  }

  void _pauseGame() {
    setState(() => isPaused = true);
    Provider.of<GameProvider>(context, listen: false).cancelTimer();
  }

  void _resumeGame() {
    setState(() => isPaused = false);
    Provider.of<GameProvider>(context, listen: false).startTimer();
  }

  void _startWinnerFlash() async {
    setState(() {
      isWinnerPathFlashing = true;
      showNextRoundButton = false;
    });
    _winnerFlashController?.repeat(reverse: true);
    await Future.delayed(const Duration(seconds: 3));
    _winnerFlashController?.stop();
    setState(() {
      isWinnerPathFlashing = false;
      showNextRoundButton = true;
    });
  }

  Widget buildActionButton({
    required String text,
    required IconData icon,
    VoidCallback? onPressed,
    Color? color,
    Color? foregroundColor,
    double fontSize = 19,
    double minWidth = 120,
    double minHeight = 44,
    double iconSize = 22,
    double borderRadius = 16,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      label: Text(text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF42A5F5),
        foregroundColor: foregroundColor ?? Colors.white,
        minimumSize: Size(minWidth, minHeight),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildAppBarActions(GameProvider game) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.grey[700],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
          icon: const Icon(Icons.keyboard, color: Color(0xFF1E90FF)),
          label: const Text('لوحة كتابة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            // منطق فتح لوحة الكتابة
          },
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.grey[700],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
          icon: Icon(
            (game.answered ? Icons.visibility_off : Icons.visibility),
            color: Colors.grey[700],
            size: 20,
          ),
          label: Text(
            game.answered ? 'إخفاء الإجابة' : 'إظهار الإجابة',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          onPressed: (game.currentQuestion != null &&
                  (game.selectedOption != null || game.answered))
              ? () {
                  if (game.answered) {
                    game.nextQuestion();
                  } else {
                    game.selectOption(game.currentQuestion?['answer']);
                  }
                }
              : null, // غير مفعل إذا لم يبدأ سؤال
        ),
        const SizedBox(width: 8),
        // زر إعادة تشغيل اللعبة
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: Colors.orange[100],
            foregroundColor: Colors.orange[800],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('إعادة تشغيل',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('تأكيد إعادة التشغيل'),
                content: const Text('هل تريد إعادة تشغيل اللعبة بالكامل؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetGame(context);
                    },
                    child: const Text('تأكيد',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // احسب الحجم المناسب للأعمدة حسب حجم الشاشة
    final isMobile = MediaQuery.of(context).size.width < 500;
    final sideColumnWidth = isMobile ? 8.0 : 32.0;
    final sideColumnHeight = 180.0;
    final sideColumnSpacing = 0.0;
    return Consumer<GameProvider>(builder: (context, game, _) {
      _animateScoreIfChanged(game);

      // تشغيل صوت الفوز مرة واحدة فقط عند نهاية الجولة
      if (game.isRoundOver &&
          game.winnerPathLetters.isNotEmpty &&
          !_roundWinSoundPlayed) {
        _roundWinSoundPlayed = true;
        _playSoundMultiFormat('win');
        _startWinnerFlash();
      }

      // تشغيل صوت الفوز النهائي مرة واحدة فقط
      if (game.isGameOver &&
          game.winnerPathLetters.isNotEmpty &&
          !_finalWinSoundPlayed) {
        _finalWinSoundPlayed = true;
        _playSoundMultiFormat('win');
      }

      // إعادة تعيين متغيرات الصوت عند بدء جولة جديدة
      if (!game.isRoundOver && !showStartButton) {
        _roundWinSoundPlayed = false;
        showNextRoundButton = false;
      }

      // إعادة تعيين متغيرات الصوت عند إعادة اللعبة
      if (showStartButton) {
        _finalWinSoundPlayed = false;
        _roundWinSoundPlayed = false;
      }

      // إذا انتهت الجولة والفريق الفائز محدد وانتهى الأنيميشن (showWinnerAnimation == false)، أظهر شاشة الفوز
      if (game.isRoundOver &&
          game.winnerTeam != Team.none &&
          !game.showWinnerAnimation) {
        String resultText = game.winnerTeam == Team.red
            ? 'فوز الأحمر في الجولة ${game.roundNumber}'
            : 'فوز الأخضر في الجولة ${game.roundNumber}';
        Color resultColor =
            game.winnerTeam == Team.red ? Color(0xFFFF4C4C) : Color(0xFF00C97B);
        String winnerTeam = '';
        Color winnerColor = resultColor;
        double winnerFontSize = 34;
        return WinnerDialog(
          resultText: resultText,
          resultColor: resultColor,
          winnerTeam: winnerTeam,
          winnerColor: winnerColor,
          winnerFontSize: winnerFontSize,
          isDraw: false,
          showNextRound: game.roundNumber < game.totalRounds,
          onRestart: () async {
            _finalWinSoundPlayed = false;
            _roundWinSoundPlayed = false;
            try {
              final player = AudioPlayer();
              await player.play(AssetSource('sounds/start-game.mp3'),
                  volume: 1.0);
            } catch (e) {
              // تجاهل الأخطاء في تشغيل الصوت
            }
            if (game.roundNumber < game.totalRounds) {
              // بدء جولة جديدة فقط
              game.startNextRound();
            } else {
              // إعادة اللعبة بالكامل
              game.resetGame(resetScores: true);
            }
          },
        );
      }

      if (showStartButton) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(''),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E90FF),
            elevation: 0,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 64, color: Color(0xFF1E90FF)),
                const SizedBox(height: 24),
                const Text('تمت إعادة ضبط اللعبة!',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                buildActionButton(
                  text: 'ابدأ اللعب',
                  icon: Icons.play_arrow,
                  onPressed: () => _startGame(context),
                ),
              ],
            ),
          ),
        );
      }
      if (game.currentQuestions.isEmpty && !game.isGameOver) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (game.isGameOver) {
        // منطق تحديد الفائز النهائي مع رقم الجولة
        String resultText = '';
        Color resultColor = Colors.grey;
        String winnerTeam = '';
        Color winnerColor = Colors.grey;
        double winnerFontSize = 28;
        bool isDraw = false;
        int round = game.roundNumber;
        String roundText = 'في الجولة $round';
        if (game.greenScore > game.redScore) {
          resultText = 'فوز الأخضر $roundText';
          resultColor = Color(0xFF00C97B);
          winnerTeam = '';
          winnerColor = Color(0xFF00C97B);
          winnerFontSize = 34;
        } else if (game.redScore > game.greenScore) {
          resultText = 'فوز الأحمر $roundText';
          resultColor = Color(0xFFFF4C4C);
          winnerTeam = '';
          winnerColor = Color(0xFFFF4C4C);
          winnerFontSize = 34;
        } else {
          // تعادل نهائي
          resultText = 'تعادل نهائي!';
          resultColor = Colors.blueGrey;
          winnerTeam = '';
          winnerColor = Colors.blueGrey;
          winnerFontSize = 34;
          isDraw = true;
        }
        // تشغيل صوت الفوز النهائي مرة واحدة فقط
        if (!_finalWinSoundPlayed) {
          _finalWinSoundPlayed = true;
          _playSoundMultiFormat('win');
        }
        return WinnerDialog(
          resultText: resultText,
          resultColor: resultColor,
          winnerTeam: winnerTeam,
          winnerColor: winnerColor,
          winnerFontSize: winnerFontSize,
          isDraw: isDraw, // تفعيل شاشة التعادل
          showNextRound: game.roundNumber < game.totalRounds,
          onRestart: () async {
            _finalWinSoundPlayed = false;
            _roundWinSoundPlayed = false;
            try {
              final player = AudioPlayer();
              await player.play(AssetSource('sounds/start-game.mp3'),
                  volume: 1.0);
            } catch (e) {
              // تجاهل الأخطاء في تشغيل الصوت
            }
            if (game.roundNumber < game.totalRounds) {
              // بدء جولة جديدة فقط
              game.startNextRound();
            } else {
              // إعادة اللعبة بالكامل
              game.resetGame(resetScores: true);
            }
          },
        );
      }
      final q = game.currentQuestion!;
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: null,
          actions: [buildAppBarActions(game)],
          title: Text('الجولة ${game.roundNumber}',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white.withOpacity(0.85),
          foregroundColor: const Color(0xFF1E90FF),
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: SafeArea(
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: QuestionWidget(
                              question: q['question'],
                              letter: q['letter'],
                            ),
                          ),
                          if (!game
                              .answered) // شرط ظهور الزر فقط إذا لم تظهر الإجابة
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TextButton.icon(
                                icon: const Icon(Icons.visibility,
                                    color: Color(0xFF1E90FF)),
                                label: const Text(
                                  'إظهار الإجابة',
                                  style: TextStyle(
                                      color: Color(0xFF1E90FF),
                                      fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  game.selectOption(
                                      q['answer']); // كشف الإجابة مباشرة
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TimerBar(seconds: game.timer),
                      const SizedBox(height: 8),
                      // زر إيقاف/استئناف المؤقت
                      ElevatedButton.icon(
                        onPressed: game.answered
                            ? null
                            : isPaused
                                ? _resumeGame
                                : _pauseGame,
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                        label:
                            Text(isPaused ? 'استئناف المؤقت' : 'إيقاف المؤقت'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[50],
                          foregroundColor: Colors.blue[900],
                          minimumSize: const Size(120, 38),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (game.adminCanPickLetter && !game.isRoundOver)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: buildActionButton(
                      text: 'اختيار حرف جديد',
                      icon: Icons.edit,
                      onPressed: isPaused
                          ? null
                          : () async {
                              final available = GameProvider.allLetters
                                  .where(
                                      (l) => game.letterStatus[l] == Team.none)
                                  .toList();
                              final picked = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title:
                                      const Text('اختر حرفًا للجولة التالية'),
                                  content: SizedBox(
                                    width: 320,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: available
                                          .map((l) => buildActionButton(
                                                text: l,
                                                icon: Icons.edit,
                                                onPressed: () =>
                                                    Navigator.pop(context, l),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              );
                              if (picked != null) {
                                if (game.adminCanPickLetter &&
                                    !game.isRoundOver) {
                                  game.adminPickLetter(picked);
                                }
                              }
                            },
                    ),
                  ),
                // الكيبورد يأخذ كل المساحة المتاحة
                Container(
                  width: MediaQuery.of(context).size.width,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  color: Colors.transparent,
                  child: KeyboardGrid(
                    highlightLetter: q['letter'],
                    letterStatus: game.letterStatus,
                    onKeyPressed: (letter) => _handleKeyTap(context, letter),
                    keyWidth: 44, // حجم مناسب للموبايل
                    winnerPathLetters: game.winnerPathLetters.isNotEmpty
                        ? game.winnerPathLetters
                        : null,
                    hexKeyboardLayout: game.hexKeyboardLayout,
                    isWinnerPathFlashing: isWinnerPathFlashing,
                    winnerFlashValue: _winnerFlashController?.value ?? 0.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('الفريق الأخضر'),
                      selected: game.selectedTeam == Team.green,
                      selectedColor: const Color(0xFF00C97B),
                      backgroundColor: const Color(0xFFE0F2F1),
                      onSelected:
                          isPaused ? null : (v) => game.selectTeam(Team.green),
                      labelStyle: TextStyle(
                        color: game.selectedTeam == Team.green
                            ? Colors.white
                            : const Color(0xFF00C97B),
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('الفريق الأحمر'),
                      selected: game.selectedTeam == Team.red,
                      selectedColor: const Color(0xFFFF4C4C),
                      backgroundColor: const Color(0xFFFFEBEE),
                      onSelected:
                          isPaused ? null : (v) => game.selectTeam(Team.red),
                      labelStyle: TextStyle(
                        color: game.selectedTeam == Team.red
                            ? Colors.white
                            : const Color(0xFFFF4C4C),
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(q['options'].length, (i) {
                  final opt = q['options'][i];
                  final isSelected = game.selectedOption == opt;
                  final isCorrect = game.isCorrect == true && isSelected;
                  final isWrong = game.isCorrect == false && isSelected;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green[100]
                          : isWrong
                              ? Colors.red[100]
                              : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: isCorrect
                                ? Colors.green.withOpacity(0.3)
                                : isWrong
                                    ? Colors.red.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        opt,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCorrect
                              ? Colors.green[900]
                              : isWrong
                                  ? Colors.red[900]
                                  : const Color(0xFF222222),
                          fontSize: 18,
                        ),
                      ),
                      onTap: game.answered || game.selectedTeam == Team.none
                          ? null
                          : () async {
                              game.selectOption(opt);
                              final isCorrect =
                                  opt == game.currentQuestion?['answer'];
                              await _animateAnswerResult(
                                  correct: isCorrect,
                                  letter: game.currentQuestion?['letter']);
                              await _playSoundMultiFormat(
                                  isCorrect ? 'correct' : 'wrong');
                            },
                      trailing: isCorrect
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : isWrong
                              ? const Icon(Icons.cancel, color: Colors.red)
                              : null,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildActionButton(
                      text: '⏩ تخطي (أدمن)',
                      icon: Icons.admin_panel_settings,
                      onPressed: game.answered ? null : () => game.skip(),
                    ),
                    buildActionButton(
                      text: 'التالي (أدمن)',
                      icon: Icons.admin_panel_settings,
                      onPressed: game.answered ? game.nextQuestion : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AnimatedBuilder(
                        animation: _greenScoreController,
                        builder: (context, child) {
                          final scale = 1.0 +
                              0.18 *
                                  (_greenScoreController.status ==
                                              AnimationStatus.forward ||
                                          _greenScoreController.status ==
                                              AnimationStatus.reverse
                                      ? (1 - _greenScoreController.value)
                                      : 0);
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFF00C97B)),
                            const SizedBox(width: 6),
                            Text('${game.greenScore}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _redScoreController,
                        builder: (context, child) {
                          final scale = 1.0 +
                              0.18 *
                                  (_redScoreController.status ==
                                              AnimationStatus.forward ||
                                          _redScoreController.status ==
                                              AnimationStatus.reverse
                                      ? (1 - _redScoreController.value)
                                      : 0);
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFFFF4C4C)),
                            const SizedBox(width: 6),
                            Text('${game.redScore}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    });
  }
}
