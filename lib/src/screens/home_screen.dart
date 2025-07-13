import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for Timer
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:hexagon/hexagon.dart';
import '../widgets/hex_keyboard_painter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// 1. Enum Team
enum Team { green, red, none }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- متغيرات الحالة ---
  bool isGameMode = false;
  String? currentLetter;
  Map<String, dynamic>? currentQuestion;
  bool showAnswer = false;
  String currentTeam = 'red'; // 'red' or 'green'
  int timerSeconds = 30;
  int remainingSeconds = 30;
  int totalRounds = 5;
  int currentRound = 1;
  int redScore = 0;
  int greenScore = 0;
  int redRounds = 0;
  int greenRounds = 0;
  late List<Map<String, dynamic>> questions;
  late Map<String, List<Map<String, dynamic>>> questionsByLetter;
  late Timer? timer;
  List<String> redTeam = [];
  List<String> greenTeam = [];
  bool _showSymbols = false;
  bool _isShift = false;
  void _toggleSymbols() => setState(() => _showSymbols = !_showSymbols);
  void _toggleShift() => setState(() => _isShift = !_isShift);
  String inputText = '';
  String activeTeam = 'red'; // الفريق النشط يدويًا

  // متغيرات أنيميشن الضغط لكل زر
  final Map<String, bool> _pressedKeys = {};
  String _keyboardPanel =
      'main'; // main, settings, games, questions, add_game, ...
  bool _isAdminLoggedIn = false;
  final TextEditingController _adminPassCtrl = TextEditingController();
  bool _adminPassError = false;
  bool _adminPassLoading = false;
  bool _isProcessing = false; // حماية من الضغط السريع المتكرر

  // متغيرات الإعدادات المؤقتة
  int? _settingsRounds;
  int? _settingsSeconds;

  // أضف GlobalKey للكيبورد السداسي
  final GlobalKey _hexKeyboardKey = GlobalKey();

  // أضف متغير للتحكم في وضع الكيبورد أثناء اللعبة
  bool showHexKeyboard = true;

  // متغيرات حالة التعديل على أسماء الفرق
  bool isEditingRed = false;
  bool isEditingGreen = false;

  // متحكمات نص دائمة
  late TextEditingController redCtrl;
  late TextEditingController greenCtrl;

  // خريطة ثابتة: الأرقام العربية إلى حروف استبدالية غير مستخدمة في اللوحة
  static const Map<String, String> numberToReplacement = {
    '٠': 'أ',
    '١': 'ث',
    '٢': 'ذ',
    '٣': 'ر',
    '٤': 'ز',
    '٥': 'ط',
    '٦': 'ظ',
    '٧': 'غ',
    '٨': 'خ',
    '٩': 'خ',
  };
  // حالة: ما تم استبداله من أرقام إلى حروف
  final Map<String, String> replacedNumbers = {};
  // حالة: مؤشر السؤال الحالي لكل حرف استبدالي
  final Map<String, int> replacementQuestionIndex = {};
  // حالة: مؤشر السؤال الحالي لكل حرف أصلي
  final Map<String, int> letterQuestionIndex = {};

  // 1. أضف GlobalKey أعلى الكلاس:
  final GlobalKey _keyboardScreenshotKey = GlobalKey();

  // حالة: الحروف/الأرقام التي تومض مؤقتًا عند الضغط
  Set<String> _flashingKeys = {};

  // متغيرات حالة جديدة
  String? _lastPressedKey;
  Map<String, String> _keyTeamColors = {};

  // ثابت الجيران السداسي (6 اتجاهات)
  static const List<List<List<int>>> hexNeighbors = [
    // حتى الصفوف الزوجية والفردية
    // [dy, dx] لكل اتجاه
    // 0: أعلى يسار، 1: أعلى يمين، 2: يمين، 3: أسفل يمين، 4: أسفل يسار، 5: يسار
    // الصف الزوجي
    [
      [-1, -1], // أعلى يسار
      [-1, 0], // أعلى يمين
      [0, 1], // يمين
      [1, 0], // أسفل يمين
      [1, -1], // أسفل يسار
      [0, -1], // يسار
    ],
    // الصف الفردي
    [
      [-1, 0], // أعلى يسار
      [-1, 1], // أعلى يمين
      [0, 1], // يمين
      [1, 1], // أسفل يمين
      [1, 0], // أسفل يسار
      [0, -1], // يسار
    ],
  ];

  @override
  void initState() {
    super.initState();
    questions = [];
    questionsByLetter = {};
    timer = null;
    _keyboardPanel = 'splash';
    redCtrl = TextEditingController();
    greenCtrl = TextEditingController();
    Future.delayed(const Duration(seconds: 1), () async {
      await _checkAdminLogin();
    });
    _loadQuestions();
  }

  @override
  void dispose() {
    timer?.cancel();
    _adminPassCtrl.dispose();
    redCtrl.dispose();
    greenCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuestionsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('questions', json.encode(questions));
  }

  Future<void> _loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    String? localData = prefs.getString('questions');
    if (localData != null) {
      final List<dynamic> jsonList = json.decode(localData);
      questions = jsonList.cast<Map<String, dynamic>>();
    } else {
      try {
        final String data =
            await rootBundle.loadString('assets/questions.json');
        final List<dynamic> jsonList = json.decode(data);
        questions = jsonList.cast<Map<String, dynamic>>();
      } catch (e) {
        questions = [];
      }
    }
    questionsByLetter = {};
    for (var q in questions) {
      final l = q['letter'];
      questionsByLetter.putIfAbsent(l, () => []).add(q);
    }
    setState(() {});
  }

  // دالة تحديث الأسئلة فوراً بعد التعديل
  void _updateQuestions() {
    _loadQuestions();
    // إعادة تعيين السؤال الحالي إذا لم يعد موجوداً
    if (currentQuestion != null) {
      final letter = currentQuestion!['letter'];
      final qs = questionsByLetter[letter];
      if (qs == null || qs.isEmpty) {
        setState(() {
          currentQuestion = null;
          inputText = 'تم حذف السؤال الحالي. اختر حرف آخر.';
          showAnswer = false;
        });
      }
    }
  }

  Future<void> _checkAdminLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isAdminLoggedIn') ?? false;
    setState(() {
      _isAdminLoggedIn = isLogged;
      _keyboardPanel = isLogged ? 'main' : 'password';
    });
  }

  Future<void> _handleAdminLogin() async {
    if (_adminPassLoading || _isProcessing) return; // حماية من الضغط المتكرر

    setState(() {
      _adminPassLoading = true;
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (_adminPassCtrl.text == 'admin1212') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdminLoggedIn', true);
      setState(() {
        _isAdminLoggedIn = true;
        _keyboardPanel = 'main';
        _adminPassError = false;
        _adminPassLoading = false;
        _isProcessing = false;
      });
    } else {
      setState(() {
        _adminPassError = true;
        _adminPassLoading = false;
        _isProcessing = false;
      });
    }
  }

  void _startGameMode() {
    setState(() {
      isGameMode = true;
      currentLetter = null;
      currentQuestion = null; // لا تعيّن أي سؤال تلقائياً
      showAnswer = false;
      currentTeam = 'red';
    });
  }

  // Panel لإدخال أسماء الفرق
  Widget _buildTeamsPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // IconButton(
            //   icon: const Icon(Icons.arrow_back),
            //   onPressed: () => setState(() => _keyboardPanel = 'main'),
            // ),
            // const SizedBox(width: 8),
            const Text('تسجيل التيمات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('الفريق الأحمر:',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.red),
              onPressed: () => setState(() => isEditingRed = !isEditingRed),
              tooltip: 'تعديل أسماء الفريق الأحمر',
            ),
          ],
        ),
        isEditingRed
            ? TextField(
                controller: redCtrl,
                decoration: const InputDecoration(hintText: 'مثال: أحمد,سارة'),
                onChanged: (val) => setState(() {
                  redTeam = redCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                }),
                onSubmitted: (_) => setState(() {
                  redTeam = redCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  isEditingRed = false;
                }),
              )
            : Text(redTeam.isNotEmpty ? redTeam.join('، ') : 'لاعبو الأحمر',
                style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('الفريق الأخضر:',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.green),
              onPressed: () => setState(() => isEditingGreen = !isEditingGreen),
              tooltip: 'تعديل أسماء الفريق الأخضر',
            ),
          ],
        ),
        isEditingGreen
            ? TextField(
                controller: greenCtrl,
                decoration: const InputDecoration(hintText: 'مثال: محمد,منى'),
                onChanged: (val) => setState(() {
                  greenTeam = greenCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                }),
                onSubmitted: (_) => setState(() {
                  greenTeam = greenCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  isEditingGreen = false;
                }),
              )
            : Text(greenTeam.isNotEmpty ? greenTeam.join('، ') : 'لاعبو الأخضر',
                style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (redTeam.length >= 2 && greenTeam.length >= 2)
              ? () {
                  setState(() {
                    _keyboardPanel = 'main';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تسجيل الفرق بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E90FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('بدء اللعبة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showSettingsDialog() {
    setState(() {
      _settingsRounds = totalRounds;
      _settingsSeconds = timerSeconds;
      _keyboardPanel = 'settings';
    });
  }

  void _nextRound() {
    setState(() {
      currentRound++;
      currentLetter = null;
      // عيّن أول سؤال متاح تلقائيًا في الجولة الجديدة
      if (questions.isNotEmpty) {
        currentQuestion = questions[0];
      } else {
        currentQuestion = null;
      }
      showAnswer = false;
      remainingSeconds = timerSeconds;
      currentTeam = currentRound % 2 == 1 ? 'red' : 'green';
      activeTeam = currentTeam;
      _isProcessing = false;
    });
  }

  void _switchTeamAndScore(String team) {
    setState(() {
      if (team == 'red') redScore++;
      if (team == 'green') greenScore++;
      _isProcessing = false;
    });
    if (redScore == (totalRounds / 2).ceil() ||
        greenScore == (totalRounds / 2).ceil()) {
      // فوز أحد التيمات
      _showWinnerDialog();
    } else if (currentRound < totalRounds) {
      _nextRound();
    } else {
      _showWinnerDialog();
    }
  }

  void _showWinnerDialog() {
    String winner = redScore > greenScore
        ? 'الفريق الأحمر'
        : greenScore > redScore
            ? 'الفريق الأخضر'
            : 'تعادل';
    Color winnerColor = redScore > greenScore
        ? Colors.red
        : greenScore > redScore
            ? Colors.green
            : const Color.fromARGB(255, 248, 14, 14);
    IconData winnerIcon = redScore > greenScore
        ? Icons.emoji_events
        : greenScore > redScore
            ? Icons.emoji_events
            : Icons.handshake;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(winnerIcon, color: winnerColor, size: 32),
            const SizedBox(width: 8),
            const Text('انتهت اللعبة!',
                style: TextStyle(color: const Color(0xFF1E90FF))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: winnerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: winnerColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'الفائز: $winner',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: winnerColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.circle, color: Colors.red, size: 24),
                          Text('$redScore',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('الأحمر',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      const Text('VS',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Column(
                        children: [
                          const Icon(Icons.circle,
                              color: Colors.green, size: 24),
                          Text('$greenScore',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('الأخضر',
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                isGameMode = false;
                redScore = 0;
                greenScore = 0;
                currentRound = 1;
                redTeam = [];
                greenTeam = [];
                currentLetter = null;
                currentQuestion = null;
                showAnswer = false;
                timer?.cancel();
                _isProcessing = false;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E90FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('إعادة اللعب',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGamePanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // شريط النقاط والجولات
        Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_score,
                            color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Text('الأحمر: $redScore',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E90FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF1E90FF).withOpacity(0.3)),
                      ),
                      child: Text('الجولة $currentRound من $totalRounds',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E90FF))),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.sports_score,
                            color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Text('الأخضر: $greenScore',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.settings, color: Color(0xFF1E90FF)),
                      onPressed: _showSettingsDialog,
                      tooltip: 'إعدادات اللعبة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.gamepad, color: Color(0xFF1E90FF)),
                      onPressed: () =>
                          setState(() => _keyboardPanel = 'game_settings'),
                      tooltip: 'إعدادات اللعبة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.question_answer,
                          color: Color(0xFF1E90FF)),
                      onPressed: () =>
                          setState(() => _keyboardPanel = 'questions'),
                      tooltip: 'إدارة الأسئلة',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // اختيار الفريق النشط
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => activeTeam = 'red'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      activeTeam == 'red' ? Colors.red : Colors.red[100],
                  foregroundColor:
                      activeTeam == 'red' ? Colors.white : Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 40),
                ),
                child: const Text('الفريق الأحمر',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => setState(() => activeTeam = 'green'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      activeTeam == 'green' ? Colors.green : Colors.green[100],
                  foregroundColor:
                      activeTeam == 'green' ? Colors.white : Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 40),
                ),
                child: const Text('الفريق الأخضر',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        // أسماء لاعبي التيمات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentTeam == 'red'
                          ? Colors.red[100]
                          : const Color.fromARGB(255, 255, 0, 0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.group, color: Colors.red, size: 18),
                        const SizedBox(width: 4),
                        Text(
                            redTeam.isNotEmpty
                                ? redTeam.join('، ')
                                : 'لاعبو الأحمر',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentTeam == 'green'
                          ? Colors.green[100]
                          : const Color.fromARGB(255, 225, 0, 0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.group, color: Colors.green, size: 18),
                        const SizedBox(width: 4),
                        Text(
                            greenTeam.isNotEmpty
                                ? greenTeam.join('، ')
                                : 'لاعبو الأخضر',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // التايمر والجولة الحالية
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('الوقت: $remainingSeconds',
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black)),
                  const SizedBox(width: 24),
                  Text(
                      'دور الفريق: ${currentTeam == 'red' ? 'الأحمر' : 'الأخضر'}',
                      style: TextStyle(
                          fontSize: 18,
                          color: currentTeam == 'red'
                              ? Colors.red
                              : Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: timer == null ? _startTimer : _stopTimer,
                    icon: Icon(timer == null ? Icons.play_arrow : Icons.pause),
                    label: Text(timer == null ? 'تشغيل' : 'إيقاف'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          timer == null ? Colors.green : Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _restartTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة تشغيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 36),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8), // قلل المارجن السفلي
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F0FF).withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: _buildPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_keyboardPanel) {
      case 'splash':
        return _buildSplashPanel();
      case 'password':
        return _buildPasswordPanel();
      case 'settings':
        return _buildSettingsPanel();
      case 'games':
        return _buildGamesPanel();
      case 'questions':
        return _buildQuestionsPanel();
      case 'add_game':
        return _buildAddGamePanel();
      case 'game_settings':
        return _buildGameSettingsPanel();
      default:
        List<Widget> children = [];

        if (isGameMode) {
          children.add(
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => showHexKeyboard = !showHexKeyboard),
                        icon: Icon(
                            showHexKeyboard ? Icons.keyboard : Icons.grid_view,
                            color: const Color(0xFF1E90FF),
                            size: 16),
                        label: Text(
                            showHexKeyboard ? 'لوحة كتابة' : 'لوحة اللعبة',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[50],
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _captureKeyboardScreenshot,
                        icon: const Icon(Icons.camera_alt,
                            color: Colors.orange, size: 16),
                        label: const Text('لقطة شاشة',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[50],
                          foregroundColor: Colors.orange[900],
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showSettingsDialog,
                        icon: const Icon(Icons.settings,
                            color: Color(0xFF1E90FF), size: 16),
                        label: const Text('إعدادات',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[50],
                          foregroundColor: Colors.green[700],
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => _keyboardPanel = 'questions'),
                        icon: const Icon(Icons.question_answer,
                            color: Color(0xFF1E90FF), size: 16),
                        label: const Text('الأسئلة',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[50],
                          foregroundColor: Colors.purple[700],
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                showHexKeyboard ? _buildHexKeyboard() : _buildKeyboard(),
              ],
            ),
          );
        } else {
          children.add(_buildKeyboard());
        }
        print('Building panel: $_keyboardPanel');
        print('Children count: ${children.length}');
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: children,
        );
    }
  }

  void _showGameMenu() {
    setState(() => _keyboardPanel = 'games');
  }

  List<String> customGames = ['تحدي الحروف المتقدم', 'لعبة الكلمات السريعة'];

  void _showAddGameDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة لعبة جديدة',
            style: TextStyle(color: const Color(0xFF1E90FF))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'اسم اللعبة',
                hintText: 'أدخل اسم اللعبة الجديدة',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
              onSubmitted: (_) {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    customGames.add(ctrl.text.trim());
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تمت إضافة لعبة: ${ctrl.text.trim()}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            // const Text(
            //   'ملاحظة: الألعاب المضافة ستظهر في قائمة الألعاب المتاحة',
            //   style: TextStyle(fontSize: 12, color: Colors.grey),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  customGames.add(ctrl.text.trim());
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تمت إضافة لعبة: ${ctrl.text.trim()}'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال اسم اللعبة'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E90FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String label) {
    final isPressed = _pressedKeys[label] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressedKeys[label] = true);
        },
        onTapUp: (_) {
          setState(() => _pressedKeys[label] = false);
          setState(() {
            inputText += label;
          });
        },
        onTapCancel: () {
          setState(() => _pressedKeys[label] = false);
        },
        child: AnimatedScale(
          scale: isPressed ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeInOut,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPressed
                  ? const Color(0xFF1E90FF).withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E90FF).withOpacity(0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E90FF)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    String? label,
    IconData? icon,
    VoidCallback? onTap,
    bool active = false,
    int flex = 1,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeInOut,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ??
                (active
                    ? const Color(0xFF1E90FF).withOpacity(0.15)
                    : Colors.white),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: icon != null
              ? Icon(icon,
                  color: color != null ? Colors.white : const Color(0xFF1E90FF),
                  size: 26)
              : Text(label ?? '',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
        ),
      ),
    );
  }

  // عند بناء صفوف الكيبورد:
  List<Widget> buildRow(List<String> chars, {double sidePadding = 0}) => [
        SizedBox(width: sidePadding),
        ...chars.map((l) => Expanded(child: _buildKeyButton(l))),
        SizedBox(width: sidePadding),
      ];

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: _buildSpecialKey(
            label: _showSymbols ? 'أبجد' : '؟123',
            onTap: _toggleSymbols,
            color: Colors.grey[200],
          ),
        ),
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildSpecialKey(
              label: 'مسافة',
              flex: 1,
              onTap: () {
                setState(() {
                  inputText += ' ';
                });
              },
              color: Colors.grey[100],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _buildSpecialKey(
            icon: Icons.sports_esports,
            onTap: _showGameMenu,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboard() {
    // الحروف العربية (صفوف كيبورد الموبايل)
    List<String> row1;
    List<String> row2;
    List<String> row3;

    if (_showSymbols) {
      // الأرقام والرموز
      row1 = ['١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '٠'];
      row2 = ['-', '/', ':', ';', '(', ')', '₪', '&', '@', '"', '.'];
      row3 = ['#', '+', '=', '*', '؟', '!', ',', '،', '؛', ':'];
    } else {
      // الحروف العربية
      row1 = ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح'];
      row2 = ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط'];
      row3 = ['ئ', 'ء', 'ؤ', 'ر', 'لا', 'ى', 'ة', 'و', 'ز', 'ظ'];
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TextBox
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E90FF).withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E90FF).withOpacity(0.07),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✍️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  if (currentQuestion != null)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => showAnswer = !showAnswer),
                      icon: Icon(
                          showAnswer ? Icons.visibility_off : Icons.visibility,
                          size: 14),
                      label: Text(showAnswer ? 'إخفاء الإجابة' : 'عرض الإجابة',
                          style: const TextStyle(fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBBDEFB),
                        foregroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        minimumSize: const Size(0, 22),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              SelectableText(
                inputText.isEmpty ? 'اضغط على الحروف لكتابة النص' : inputText,
                style: TextStyle(
                  fontSize: 13,
                  color: inputText.isEmpty ? Colors.grey : Colors.black87,
                  fontWeight:
                      inputText.isEmpty ? FontWeight.normal : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
                maxLines: 2,
              ),
              if (showAnswer && currentQuestion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: SelectableText(
                    'الإجابة: ${currentQuestion!['answer'] ?? 'إجابة غير متوفرة'}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              if (showAnswer && currentQuestion == null)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: SelectableText(
                    'اختر حرف أولاً',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        // صف 1
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...row1.map((l) => Expanded(child: _buildKeyButton(l))).toList(),
          ],
        ),
        const SizedBox(height: 8),
        // صف 2 مع تباعد جانبي
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 22),
            ...row2.map((l) => Expanded(child: _buildKeyButton(l))).toList(),
            const SizedBox(width: 22),
          ],
        ),
        const SizedBox(height: 8),
        // صف 3 مع أزرار خاصة
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpecialKey(
                icon: Icons.arrow_upward,
                onTap: _toggleShift,
                active: _isShift),
            ...row3.map((l) => Expanded(child: _buildKeyButton(l))).toList(),
            _buildSpecialKey(
                icon: Icons.backspace,
                onTap: () {
                  setState(() {
                    if (inputText.isNotEmpty) {
                      inputText = inputText.substring(0, inputText.length - 1);
                    }
                  });
                },
                color: Color(0xFF1E90FF)),
          ],
        ),
        const SizedBox(height: 8),
        // صف الأزرار الأخير
        _buildBottomRow(),
      ],
    );
  }

  void _exitGameMode() {
    timer?.cancel();
    setState(() {
      isGameMode = false;
      currentLetter = null;
      currentQuestion = null;
      showAnswer = false;
      redScore = 0;
      greenScore = 0;
      redRounds = 0;
      greenRounds = 0;
      currentRound = 1;
      redTeam = [];
      greenTeam = [];
      _isProcessing = false;
      _keyTeamColors.clear();
      _lastPressedKey = null;
      _flashingKeys.clear();
    });
  }

  void _pickLetter(String letter) {
    final qs = questionsByLetter[letter];
    if (qs == null || qs.isEmpty) {
      setState(() {
        currentLetter = letter;
        currentQuestion = null;
        showAnswer = false;
        inputText = 'لا يوجد سؤال لهذا الحرف.';
      });
      return;
    }
    final q = (qs..shuffle()).first; // اختيار عشوائي من الأسئلة لهذا الحرف
    timer?.cancel();
    setState(() {
      currentLetter = letter;
      currentQuestion = q;
      showAnswer = false;
      remainingSeconds = timerSeconds;
      final question = q['question'] ?? 'سؤال بدون نص';
      inputText = 'سؤال حرف $letter: ' + question;
    });
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        t.cancel();
        // عند انتهاء الوقت ينتقل الدور للفريق الآخر ويعرض سؤال جديد
        setState(() {
          currentTeam = currentTeam == 'red' ? 'green' : 'red';
          activeTeam = currentTeam;
          showAnswer = false;
          remainingSeconds = timerSeconds;

          // عرض سؤال جديد من نفس الحرف إذا كان متوفراً
          if (currentQuestion != null) {
            final letter = currentQuestion!['letter'];
            final qs = questionsByLetter[letter];
            if (qs != null && qs.length > 1) {
              // اختيار سؤال مختلف من نفس الحرف
              final currentQuestionText = currentQuestion!['question'];
              final differentQuestions = qs
                  .where((q) => q['question'] != currentQuestionText)
                  .toList();
              if (differentQuestions.isNotEmpty) {
                final newQuestion = differentQuestions[0];
                currentQuestion = newQuestion;
                inputText =
                    'سؤال حرف $letter: ' + (newQuestion['question'] ?? '');
              } else {
                inputText = 'انتهى الوقت! دور الفريق ' +
                    (currentTeam == 'red' ? 'الأحمر' : 'الأخضر') +
                    ': ' +
                    (currentQuestion!['question'] ?? 'سؤال بدون نص');
              }
            } else {
              inputText = 'انتهى الوقت! دور الفريق ' +
                  (currentTeam == 'red' ? 'الأحمر' : 'الأخضر') +
                  ': ' +
                  (currentQuestion!['question'] ?? 'سؤال بدون نص');
            }
          }
        });
        // إظهار تنبيه انتهاء الوقت
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('انتهى الوقت! دور الفريق ' +
                (currentTeam == 'red' ? 'الأحمر' : 'الأخضر')),
            backgroundColor: currentTeam == 'red' ? Colors.red : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  // دالة إيقاف المؤقت
  void _stopTimer() {
    timer?.cancel();
  }

  // دالة إعادة تشغيل المؤقت
  void _restartTimer() {
    _stopTimer();
    setState(() {
      remainingSeconds = timerSeconds;
    });
    _startTimer();
  }

  // دالة تعديل السؤال
  void _editQuestion(int i) {
    final q = questions[i];
    final editLetterCtrl = TextEditingController(text: q['letter']);
    final editQuestionCtrl = TextEditingController(text: q['question']);
    final editAnswerCtrl = TextEditingController(text: q['answer']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل السؤال',
            style: TextStyle(color: const Color(0xFF1E90FF))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editLetterCtrl,
              decoration: const InputDecoration(
                labelText: 'الحرف',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editQuestionCtrl,
              decoration: const InputDecoration(
                labelText: 'السؤال',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editAnswerCtrl,
              decoration: const InputDecoration(
                labelText: 'الإجابة',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (editLetterCtrl.text.isNotEmpty &&
                  editQuestionCtrl.text.isNotEmpty &&
                  editAnswerCtrl.text.isNotEmpty) {
                setState(() {
                  questions[i] = {
                    'letter': editLetterCtrl.text.trim(),
                    'question': editQuestionCtrl.text.trim(),
                    'answer': editAnswerCtrl.text.trim(),
                  };
                });
                _saveQuestionsToLocal();
                _updateQuestions();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تم تعديل السؤال بنجاح!'),
                    backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('يرجى ملء جميع الحقول'),
                    backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E90FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  // دالة تأكيد الحذف
  void _confirmDelete(int i) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text('هل أنت متأكد أنك تريد حذف هذا السؤال؟'),
            const SizedBox(height: 8),
            Text('الحرف: ${questions[i]['letter'] ?? 'غير محدد'}'),
            Text('السؤال: ${questions[i]['question'] ?? 'غير محدد'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                questions.removeAt(i);
              });
              _saveQuestionsToLocal();
              _updateQuestions();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('تم حذف السؤال بنجاح!'),
                backgroundColor: Colors.green,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // دالة إضافة سؤال جديد
  void _showAddQuestionDialog() {
    final letterCtrl = TextEditingController();
    final questionCtrl = TextEditingController();
    final answerCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة سؤال جديد',
            style: TextStyle(color: const Color(0xFF1E90FF))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: letterCtrl,
              decoration: const InputDecoration(
                labelText: 'الحرف',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: questionCtrl,
              decoration: const InputDecoration(
                labelText: 'السؤال',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerCtrl,
              decoration: const InputDecoration(
                labelText: 'الإجابة',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E90FF), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (letterCtrl.text.isNotEmpty &&
                  questionCtrl.text.isNotEmpty &&
                  answerCtrl.text.isNotEmpty) {
                setState(() {
                  questions.add({
                    'letter': letterCtrl.text.trim(),
                    'question': questionCtrl.text.trim(),
                    'answer': answerCtrl.text.trim(),
                  });
                });
                _saveQuestionsToLocal();
                _updateQuestions();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تمت إضافة السؤال بنجاح!'),
                    backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('يرجى ملء جميع الحقول'),
                    backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E90FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  // Panel الإعدادات
  Widget _buildSettingsPanel() {
    // استخدم المتغيرات المؤقتة
    int rounds = _settingsRounds ?? totalRounds;
    int seconds = _settingsSeconds ?? timerSeconds;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0FF).withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _keyboardPanel = 'main'),
                color: const Color(0xFF1E90FF),
              ),
              const SizedBox(width: 8),
              const Text('إعدادات اللعبة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1E90FF))),
            ],
          ),
          const SizedBox(height: 16),
          const Text('عدد الجولات:',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E90FF))),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: rounds.toDouble(),
                  min: 2,
                  max: 10,
                  divisions: 8,
                  label: '$rounds',
                  activeColor: const Color(0xFF1E90FF),
                  thumbColor: const Color(0xFF1E90FF),
                  onChanged: (v) => setState(() => _settingsRounds = v.round()),
                ),
              ),
              const SizedBox(width: 8),
              Text('$rounds',
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF1E90FF))),
            ],
          ),
          const SizedBox(height: 18),
          const Text('مدة كل سؤال (ثانية):',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E90FF))),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: seconds.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '$seconds',
                  activeColor: const Color(0xFF1E90FF),
                  thumbColor: const Color(0xFF1E90FF),
                  onChanged: (v) =>
                      setState(() => _settingsSeconds = v.round()),
                ),
              ),
              const SizedBox(width: 8),
              Text('$seconds',
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF1E90FF))),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 44),
              backgroundColor: const Color(0xFF1E90FF),
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              setState(() {
                totalRounds = _settingsRounds ?? totalRounds;
                timerSeconds = _settingsSeconds ?? timerSeconds;
                remainingSeconds = timerSeconds;
                _keyboardPanel = 'main';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حفظ الإعدادات بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.question_answer),
            label: const Text('إدارة الأسئلة'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 44),
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () => setState(() => _keyboardPanel = 'questions'),
          ),
        ],
      ),
    );
  }

  // Panel الألعاب (مثال)
  Widget _buildGamesPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _keyboardPanel = 'main'),
            ),
            const SizedBox(width: 8),
            const Text('قائمة الألعاب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 16),
        // لعبة تحدي الحروف الافتراضية
        ListTile(
          leading: const Icon(Icons.abc, color: Color(0xFF1E90FF)),
          title: const Text('تحدي الحروف',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onTap: () {
            setState(() => _keyboardPanel = 'main');
            _startGameMode();
          },
        ),
        const Divider(),
        // // الألعاب المخصصة
        // if (customGames.isEmpty)
        //   const Padding(
        //     padding: EdgeInsets.symmetric(vertical: 12),
        //     child: Text('لا توجد ألعاب مضافة بعد.',
        //         style: TextStyle(color: Colors.grey)),
        //   )
        // else
        ...customGames.map((game) => ListTile(
              leading: const Icon(Icons.videogame_asset, color: Colors.green),
              title: Text(game,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم اختيار لعبة: $game')),
                );
                // يمكن إضافة منطق خاص لكل لعبة هنا
              },
            )),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('إضافة لعبة جديدة'),
          onPressed: () => setState(() => _keyboardPanel = 'add_game'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.question_answer),
          label: const Text('إدارة الأسئلة'),
          onPressed: () => setState(() => _keyboardPanel = 'questions'),
        ),
      ],
    );
  }

  // Panel إدارة الأسئلة
  Widget _buildQuestionsPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _keyboardPanel = 'main'),
            ),
            const SizedBox(width: 8),
            const Text('إدارة الأسئلة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (questions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('لا توجد أسئلة مضافة بعد.',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  )
                else
                  ...questions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final q = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(
                            '${q['letter'] ?? 'حرف'} - ${q['question'] ?? 'سؤال بدون نص'}'),
                        subtitle: Text(
                            'الإجابة: ${q['answer'] ?? 'إجابة غير متوفرة'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editQuestion(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('إضافة سؤال جديد'),
          onPressed: () => _showAddQuestionDialog(),
        ),
      ],
    );
  }

  // Panel إضافة لعبة
  Widget _buildAddGamePanel() {
    final gameNameCtrl = TextEditingController();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _keyboardPanel = 'games'),
            ),
            const SizedBox(width: 8),
            const Text('إضافة لعبة جديدة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: gameNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم اللعبة',
              hintText: 'أدخل اسم اللعبة الجديدة',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              if (gameNameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  customGames.add(gameNameCtrl.text.trim());
                  _keyboardPanel = 'games';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('تمت إضافة لعبة: ${gameNameCtrl.text.trim()}')),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('إضافة اللعبة'),
          onPressed: () {
            if (gameNameCtrl.text.trim().isNotEmpty) {
              setState(() {
                customGames.add(gameNameCtrl.text.trim());
                _keyboardPanel = 'games';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إضافة لعبة: ${gameNameCtrl.text.trim()}'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('يرجى إدخال اسم اللعبة'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E90FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Text('أدخل كلمة مرور الأدمن',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E90FF))),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _adminPassCtrl,
            obscureText: true,
            keyboardType: TextInputType.text,
            enabled: !_adminPassLoading,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              errorText: _adminPassError ? 'كلمة المرور غير صحيحة' : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1E90FF), width: 2),
              ),
            ),
            onChanged: (_) {
              if (_adminPassError)
                setState(() {
                  _adminPassError = false;
                });
            },
            onSubmitted: (_) => _handleAdminLogin(),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _adminPassLoading ? null : _handleAdminLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E90FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _adminPassLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('دخول',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplashPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 40,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: Image.asset(
              'assets/icon/icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E90FF),
                  ),
                  child: const Icon(
                    Icons.keyboard,
                    size: 60,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
        // const SizedBox(height: 32),
        // const Text(
        //   "by KeyPlay Team",
        //   style: TextStyle(fontSize: 16, color: Colors.grey),
        // ),
      ],
    );
  }

  // تحديث _buildHexKeyboard ليستخدم HexKeyboardPainter فقط
  Widget _buildHexKeyboard() {
    double maxWidth = MediaQuery.of(context).size.width;
    final List<List<String?>> baseHexRows = [
      [null, null, null, null, null, null, null, null],
      [null, 'ب', 'ج', 'م', 'س', 'ق', '٨', null],
      [null, 'و', '٤', 'ت', '٧', 'ح', '٢', null],
      [null, 'ص', '١', 'ش', '٥', 'ف', 'د', null],
      [null, '٠', 'ع', 'ل', '٣', 'ي', '٦', null],
      [null, null, null, null, null, null, null, null],
    ];
    // اعرض الأرقام الأصلية، وإذا كان هناك استبدال مؤقت لهذا الزر، اعرض الحرف المستبدل
    final List<List<String?>> hexRows = List.generate(
      baseHexRows.length,
      (i) => List.generate(
        baseHexRows[i].length,
        (j) {
          final key = '$i-$j';
          if (replacedNumbers.containsKey(key)) {
            return replacedNumbers[key];
          }
          return baseHexRows[i][j];
        },
      ),
    );
    double hexRadius = ((maxWidth - 16) / (hexRows[0].length * sqrt(3))) * 0.85;
    Map<String, Color> letterColors = {};

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // صندوق النص وزر إظهار/إخفاء الإجابة
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E90FF).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E90FF).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✍️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  if (currentQuestion != null)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => showAnswer = !showAnswer),
                      icon: Icon(
                          showAnswer ? Icons.visibility_off : Icons.visibility,
                          size: 18),
                      label: Text(showAnswer ? 'إخفاء الإجابة' : 'عرض الإجابة',
                          style: const TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBBDEFB),
                        foregroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                inputText.isEmpty ? 'اضغط على الحروف لكتابة النص' : inputText,
                style: TextStyle(
                  fontSize: 18,
                  color: inputText.isEmpty ? Colors.grey : Colors.black87,
                  fontWeight:
                      inputText.isEmpty ? FontWeight.normal : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
                maxLines: 3,
              ),
              if (showAnswer && currentQuestion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: SelectableText(
                    'الإجابة: ${currentQuestion!['answer'] ?? 'إجابة غير متوفرة'}',
                    style: const TextStyle(
                        fontSize: 17,
                        color: Colors.green,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              if (showAnswer && currentQuestion == null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: SelectableText(
                    'اختر حرف أولاً',
                    style: const TextStyle(
                        fontSize: 17,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        // معلومات النقاط والجولات (الآن تحت TextBox)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E90FF).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E90FF).withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.circle, color: Colors.red, size: 18),
                      Text('$redScore',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red)),
                      const Text('الأحمر',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                  const Text('VS',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  Column(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 18),
                      Text('$greenScore',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      const Text('الأخضر',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_score, color: Colors.blue, size: 15),
                  const SizedBox(width: 4),
                  Text('الجولة $currentRound من $totalRounds',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                ],
              ),
            ],
          ),
        ),
        // الكيبورد السداسي الجديد
        GestureDetector(
          onTapDown: (details) {
            final localPosition = details.localPosition;
            final rows = hexRows.length;
            final cols = hexRows[0].length;
            final hexHeight = hexRadius * 2;
            final hexWidth = sqrt(3) * hexRadius;

            final row =
                ((localPosition.dy - hexRadius) / (hexHeight * 0.75)).round();
            final col =
                ((localPosition.dx - (row % 2 == 1 ? hexWidth / 2 : 0)) /
                        hexWidth)
                    .round();

            if (row >= 0 && row < rows && col >= 0 && col < cols) {
              final cell = baseHexRows[row][col];
              final key = '$row-$col';

              print('DEBUG: Tapped cell at $key with value: $cell');
              print(
                  'DEBUG: Is edge cell for red: ${isEdgeCell(row, col, 'red')}');
              print(
                  'DEBUG: Is edge cell for green: ${isEdgeCell(row, col, 'green')}');

              if (cell != null) {
                setState(() {
                  // إذا كان الزر رقمًا، استبدله بالحرف الاستبدالي بشكل دائم
                  if (numberToReplacement.containsKey(cell)) {
                    replacedNumbers[key] = numberToReplacement[cell]!;
                  }
                  _lastPressedKey = key;
                  _flashingKeys.add(key);
                });

                // تأثير الوميض
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted) {
                    setState(() {
                      _flashingKeys.remove(key);
                    });
                  }
                });

                // منطق استبدال الرقم بالحرف الاستبدالي للبحث
                String? searchKey = cell;
                if (numberToReplacement.containsKey(cell)) {
                  searchKey = numberToReplacement[cell]!;
                }

                if (searchKey != null) {
                  final qs = questionsByLetter[searchKey];
                  if (qs != null && qs.isNotEmpty) {
                    final q = (qs..shuffle()).first;
                    setState(() {
                      currentQuestion = q;
                      inputText =
                          'سؤال حرف $searchKey: ' + (q['question'] ?? '');
                      showAnswer = false;
                      remainingSeconds = timerSeconds;
                    });
                    _startTimer();
                  } else {
                    setState(() {
                      currentQuestion = null;
                      inputText = 'لا يوجد سؤال للحرف $searchKey.';
                      showAnswer = false;
                    });
                  }
                }
              }
            }
          },
          child: HexKeyboardPainter(
            layout: hexRows,
            hexRadius: hexRadius,
            letterColors: letterColors,
            flashingKeys: _flashingKeys,
            selectedHexKey: _lastPressedKey,
            keyTeamColors: _keyTeamColors,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: (_lastPressedKey == null || currentRound > totalRounds)
                  ? null
                  : () {
                      setState(() {
                        if (_lastPressedKey != null) {
                          _keyTeamColors[_lastPressedKey!] = "red";
                          print('DEBUG: Colored $_lastPressedKey as red');
                        }
                      });
                      print('DEBUG _keyTeamColors:');
                      _keyTeamColors.forEach((k, v) => print('  $k: $v'));
                      print('DEBUG: Last pressed key: $_lastPressedKey');
                      _checkTeamWin('red');
                    },
              icon: const Icon(Icons.add, color: Colors.red),
              label:
                  const Text("لون للأحمر", style: TextStyle(color: Colors.red)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                minimumSize: const Size(120, 40),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: (_lastPressedKey == null || currentRound > totalRounds)
                  ? null
                  : () {
                      setState(() {
                        if (_lastPressedKey != null) {
                          _keyTeamColors[_lastPressedKey!] = "green";
                        }
                      });
                      print('DEBUG _keyTeamColors:');
                      _keyTeamColors.forEach((k, v) => print('  $k: $v'));
                      print('DEBUG: Last pressed key: $_lastPressedKey');
                      _checkTeamWin('green');
                    },
              icon: const Icon(Icons.add, color: Colors.green),
              label: const Text("لون للأخضر",
                  style: TextStyle(color: Colors.green)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[50],
                foregroundColor: Colors.green,
                minimumSize: const Size(120, 40),
              ),
            ),
          ],
        ),
        // بعد TextBox مباشرة في _buildHexKeyboard:
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // عداد الوقت
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.blue, size: 16),
                    const SizedBox(width: 2),
                    Text('$remainingSeconds',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // زر إيقاف/استئناف المؤقت
              SizedBox(
                width: 90,
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (timer == null) {
                        _startTimer();
                      } else {
                        timer?.cancel();
                        timer = null;
                      }
                    });
                  },
                  icon: Icon(
                    timer == null && remainingSeconds == timerSeconds
                        ? Icons.play_arrow
                        : timer == null
                            ? Icons.play_arrow
                            : Icons.pause,
                    size: 15,
                    color: Colors.blue,
                  ),
                  label: Text(
                    timer == null && remainingSeconds == timerSeconds
                        ? 'تشغيل'
                        : timer == null
                            ? 'استئناف'
                            : 'إيقاف',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // زر إعادة المؤقت فقط
              SizedBox(
                width: 90,
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _restartTimer();
                  },
                  icon:
                      const Icon(Icons.refresh, size: 15, color: Colors.orange),
                  label: const Text('إعادة الوقت',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[50],
                    foregroundColor: Colors.orange[900],
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // زر إعادة تحميل اللعبة بالكامل
              SizedBox(
                width: 90,
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isGameMode = false;
                      redScore = 0;
                      greenScore = 0;
                      currentRound = 1;
                      redTeam = [];
                      greenTeam = [];
                      currentLetter = null;
                      currentQuestion = null;
                      showAnswer = false;
                      timer?.cancel();
                      remainingSeconds = timerSeconds;
                      _isProcessing = false;
                      _keyTeamColors.clear();
                      _lastPressedKey = null;
                      replacedNumbers.clear();
                      inputText = '';
                    });
                  },
                  icon: const Icon(Icons.restart_alt,
                      size: 15, color: Colors.red),
                  label: const Text('إعادة اللعبة',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[900],
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // دالة التقاط صورة الكيبورد السداسي
  Future<void> _captureHexKeyboard() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('التقاط صورة غير مدعوم على الويب'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      RenderRepaintBoundary boundary = _hexKeyboardKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        // يمكنك استخدام مكتبة image_gallery_saver أو share لمشاركة الصورة أو حفظها
        // مثال: await ImageGallerySaver.saveImage(pngBytes);
        // أو: await Share.shareFiles([filePath]);
        // أضف منطق الحفظ أو المشاركة حسب الحاجة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التقاط صورة الكيبورد السداسي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('فشل في تحويل الصورة');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التقاط الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Panel إعدادات اللعبة
  Widget _buildGameSettingsPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _keyboardPanel = 'main'),
            ),
            const SizedBox(width: 8),
            const Text('إعدادات اللعبة',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF1E90FF))),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة بدء اللعبة'),
          onPressed: () {
            setState(() {
              isGameMode = false;
              currentLetter = null;
              currentQuestion = null;
              showAnswer = false;
              redScore = 0;
              greenScore = 0;
              currentRound = 1;
              redTeam = [];
              greenTeam = [];
              _keyboardPanel = 'main';
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إعادة بدء اللعبة'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[100],
            foregroundColor: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.exit_to_app),
          label: const Text('خروج من اللعبة'),
          onPressed: () {
            setState(() {
              isGameMode = false;
              _keyboardPanel = 'main';
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم الخروج من اللعبة'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[100],
            foregroundColor: Colors.red[900],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('التقاط صورة'),
          onPressed: _captureHexKeyboard,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[100],
            foregroundColor: Colors.green[900],
          ),
        ),
      ],
    );
  }

  // 4. أضف دالة الالتقاط في الكلاس:
  Future<void> _captureKeyboardScreenshot() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('التقاط صورة غير مدعوم على الويب'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // التقاط صورة للكيبورد السداسي إذا كان في وضع اللعبة
      RenderRepaintBoundary boundary;
      if (isGameMode && showHexKeyboard) {
        boundary = _hexKeyboardKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
      } else {
        boundary = _keyboardScreenshotKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
      }

      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();

        // عرض خيارات حفظ ومشاركة الصورة
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حفظ لقطة الشاشة'),
            content: const Text('اختر كيفية حفظ أو مشاركة الصورة:'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _saveToGallery(pngBytes);
                },
                child: const Text('حفظ في المعرض'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _shareImage(pngBytes);
                },
                child: const Text('مشاركة'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('فشل في تحويل الصورة');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التقاط الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة حفظ الصورة في معرض الصور
  Future<void> _saveToGallery(Uint8List pngBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/keyboard_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الصورة في مجلد التطبيق'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة مشاركة الصورة
  Future<void> _shareImage(Uint8List pngBytes) async {
    try {
      await Share.shareXFiles(
        [XFile.fromData(pngBytes)],
        text: 'لقطة شاشة من كيبورد التحدي - ${DateTime.now().toString()}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء مشاركة الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // في منطق onTap للأرقام:
  void onKeyboardKeyTap(String key) {
    String letter = key;
    if (numberToReplacement.containsKey(key)) {
      letter = numberToReplacement[key]!;
    }
    final qs = questionsByLetter[letter];
    if (qs != null && qs.isNotEmpty) {
      final q = (qs..shuffle()).first;
      setState(() {
        currentQuestion = q;
        inputText = 'سؤال حرف $letter: ' + (q['question'] ?? '');
        showAnswer = false;
        remainingSeconds = timerSeconds;
      });
      _startTimer();
    } else {
      setState(() {
        currentQuestion = null;
        inputText = 'لا يوجد سؤال لهذا الحرف.';
        showAnswer = false;
      });
    }
  }

  // دالة مساعدة لمعرفة ما إذا كانت الخلية على الحافة
  bool isEdgeCell(int row, int col, String teamColor) {
    if (teamColor == 'red') {
      // الأحمر: الحواف اليسرى (col=1) واليمنى (col=6)
      return col == 1 || col == 6;
    } else if (teamColor == 'green') {
      // الأخضر: الحواف العلوية (row=1) والسفلية (row=4)
      return row == 1 || row == 4;
    }
    return false;
  }

  // 2. دالة اكتشاف المسار المتصل (BFS)
  bool checkTeamWinPath(String teamColor) {
    // الشبكة السداسية الفعلية: 6 صفوف (0-5) و 8 أعمدة (0-7)
    // الخلايا الفعلية: من الصف 1-4 والعمود 1-6
    final rows = 6;
    final cols = 8;
    Set<String> visited = {};
    List<List<int>> queue = [];

    if (teamColor == 'red') {
      // الأحمر: من أي خلية في العمود 1 إلى أي خلية في العمود 6
      for (int row = 1; row <= 4; row++) {
        String key = '$row-1';
        if (_keyTeamColors[key] == 'red') {
          queue.add([row, 1]);
          visited.add(key);
        }
      }
    } else if (teamColor == 'green') {
      // الأخضر: من أي خلية في الصف 1 إلى أي خلية في الصف 4
      for (int col = 1; col <= 6; col++) {
        String key = '1-$col';
        if (_keyTeamColors[key] == 'green') {
          queue.add([1, col]);
          visited.add(key);
        }
      }
    }

    while (queue.isNotEmpty) {
      final pos = queue.removeAt(0);
      int row = pos[0];
      int col = pos[1];
      String key = '$row-$col';
      // شرط الفوز: الوصول لأي خلية على الحافة المقابلة
      if (teamColor == 'red' && col == 6 && _keyTeamColors[key] == 'red') {
        return true;
      }
      if (teamColor == 'green' && row == 4 && _keyTeamColors[key] == 'green') {
        return true;
      }
      int parity = row % 2;
      for (var dir in hexNeighbors[parity]) {
        int newRow = row + dir[0];
        int newCol = col + dir[1];
        String nKey = '$newRow-$newCol';
        if (newRow >= 1 && newRow <= 4 && newCol >= 1 && newCol <= 6) {
          if (!visited.contains(nKey) && _keyTeamColors[nKey] == teamColor) {
            queue.add([newRow, newCol]);
            visited.add(nKey);
          }
        }
      }
    }
    return false;
  }

  // 3. دالة فحص فوز الفريق
  void _checkTeamWin(String teamColor) {
    print('Checking win for $teamColor ...');
    print('Current colored cells:');
    _keyTeamColors.forEach((k, v) => print('  $k: $v'));

    // تحقق من انتهاء الجولات أولاً
    if (currentRound > totalRounds) {
      // اللعبة انتهت، اعرض رسالة تنبيه
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهت اللعبة! اضغط زر إعادة اللعب للبدء من جديد'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (checkTeamWinPath(teamColor)) {
      print('Team $teamColor WON!');

      setState(() {
        // زد النقطة للفريق الفائز
        if (teamColor == 'red') redScore++;
        if (teamColor == 'green') greenScore++;
        // زد رقم الجولة
        currentRound++;
      });

      // إذا انتهت الجولات الآن، اعرض النتيجة النهائية
      if (currentRound > totalRounds) {
        String finalWinner = redScore > greenScore
            ? 'red'
            : greenScore > redScore
                ? 'green'
                : 'draw';
        _showFinalWinnerDialog(finalWinner);
      } else {
        // إذا لم تنته الجولات، اعرض فوز الجولة
        _showRoundWinnerDialog(teamColor);
        resetHexKeyboard();
      }
    }
  }

  // 4. دالة إعادة تهيئة الكيبورد السداسي:
  void resetHexKeyboard() {
    setState(() {
      _keyTeamColors.clear();
      _lastPressedKey = null;
      replacedNumbers.clear(); // أفرغ الاستبدالات عند إعادة تهيئة الكيبورد
      // يمكن إعادة تعيين متغيرات أخرى إذا لزم الأمر
    });
  }

  // 5. دالة عرض فوز الفريق في الجولة
  void _showRoundWinnerDialog(String teamColor) {
    String winner = teamColor == 'red' ? 'الفريق الأحمر' : 'الفريق الأخضر';
    Color winnerColor = teamColor == 'red' ? Colors.red : Colors.green;
    bool isLastRound = currentRound >= totalRounds;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        titlePadding:
            const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 0),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: winnerColor, size: 26),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                isLastRound
                    ? 'انتهت اللعبة! $winner فاز!'
                    : 'مبروك! $winner فاز في هذه الجولة!',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مبروك للفريق ${teamColor == 'red' ? 'الأحمر' : 'الأخضر'}!',
              style: TextStyle(
                  fontSize: 13,
                  color: winnerColor,
                  fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              'الجولة $currentRound من $totalRounds',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            if (isLastRound) ...[
              const SizedBox(height: 6),
              Text(
                'النقاط النهائية: الأحمر $redScore - الأخضر $greenScore',
                style: const TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // 6. دالة عرض الفائز النهائي
  void _showFinalWinnerDialog(String teamColor) {
    bool isDraw = teamColor == 'draw';
    String winner = isDraw
        ? 'تعادل'
        : (teamColor == 'red' ? 'الفريق الأحمر' : 'الفريق الأخضر');
    Color winnerColor =
        isDraw ? Colors.grey : (teamColor == 'red' ? Colors.red : Colors.green);
    IconData winnerIcon = isDraw ? Icons.emoji_events : Icons.emoji_events;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(winnerIcon, color: winnerColor, size: 32),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isDraw
                    ? 'انتهت اللعبة بالتعادل!'
                    : 'مبروك! $winner فاز باللعبة!',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDraw) ...[
              const Text('انتهت اللعبة بالتعادل!'),
              const SizedBox(height: 8),
              Text('النقاط النهائية: الأحمر $redScore - الأخضر $greenScore'),
            ] else ...[
              Text('مبروك للفريق ${teamColor == 'red' ? 'الأحمر' : 'الأخضر'}!'),
              const SizedBox(height: 8),
              Text('فاز بثلاث جولات من أصل خمسة'),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetAllGameState();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E90FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('إعادة اللعب',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _resetAllGameState() {
    setState(() {
      isGameMode = false;
      redScore = 0;
      greenScore = 0;
      currentRound = 1;
      redRounds = 0;
      greenRounds = 0;
      currentTeam = 'red';
      activeTeam = 'red';
      currentLetter = null;
      currentQuestion = null;
      showAnswer = false;
      timer?.cancel();
      timer = null;
      remainingSeconds = timerSeconds;
      redTeam = [];
      greenTeam = [];
      replacedNumbers.clear();
      inputText = '';
      _keyTeamColors.clear();
      _lastPressedKey = null;
      _flashingKeys.clear();
      redCtrl.text = '';
      greenCtrl.text = '';
      _keyboardPanel = 'main';
    });
  }
}

// Widget لرسم سداسي بسيط
class _HexagonCell extends StatelessWidget {
  final double size;
  final Color color;
  final Color borderColor;
  final Widget? child;
  const _HexagonCell({
    required this.size,
    required this.color,
    required this.borderColor,
    this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexagonPainter(color: color, borderColor: borderColor),
        child: child,
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _HexagonPainter({required this.color, required this.borderColor});
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final double h = sqrt(3) * r;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = pi / 3 * i - pi / 6;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Widget لرسم نصف سداسي بالطول (يمين أو شمال)
class _HalfHexagonCell extends StatelessWidget {
  final double size;
  final Color color;
  final String direction; // 'left', 'right', 'top', 'bottom'
  const _HalfHexagonCell(
      {required this.size,
      required this.color,
      required this.direction,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HalfHexagonPainter(color: color, direction: direction),
      ),
    );
  }
}

class _HalfHexagonPainter extends CustomPainter {
  final Color color;
  final String direction;
  _HalfHexagonPainter({required this.color, required this.direction});
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final double h = sqrt(3) * r;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    if (direction == 'left') {
      // نصف سداسي بالطول من اليسار
      path.moveTo(center.dx, 0);
      path.lineTo(size.width, h / 4);
      path.lineTo(size.width, size.height - h / 4);
      path.lineTo(center.dx, size.height);
      path.lineTo(center.dx, 0);
    } else if (direction == 'right') {
      // نصف سداسي بالطول من اليمين
      path.moveTo(center.dx, 0);
      path.lineTo(0, h / 4);
      path.lineTo(0, size.height - h / 4);
      path.lineTo(center.dx, size.height);
      path.lineTo(center.dx, 0);
    } else if (direction == 'top') {
      // نصف سداسي أفقي من الأعلى (أخضر) - غطِ كامل الارتفاع
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width - r, size.height / 2);
      path.lineTo(r, size.height / 2);
      path.close();
    } else if (direction == 'bottom') {
      // نصف سداسي أفقي من الأسفل (أخضر) - غطِ كامل الارتفاع
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(size.width - r, size.height / 2);
      path.lineTo(r, size.height / 2);
      path.close();
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
