import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'question_storage.dart';

enum Team { green, red, none }

class GameProvider extends ChangeNotifier {
  List<Map<String, dynamic>> allQuestions = [];
  List<Map<String, dynamic>> currentQuestions = [];
  List<Map<String, dynamic>> skippedQuestions = [];
  int currentIndex = 0;
  int timer = 20;
  Timer? _timer;
  Team selectedTeam = Team.none;
  Map<String, Team> letterStatus = {};
  bool answered = false;
  String? selectedOption;
  bool? isCorrect;
  bool isGameOver = false;
  Map<String, List<Map<String, dynamic>>> questionsByLetter = {};

  int greenScore = 0;
  int redScore = 0;
  int roundNumber = 1;
  bool isRoundOver = false;
  bool adminCanPickLetter = false;
  bool showWinnerAnimation = false;
  Team winnerTeam = Team.none;
  int totalRounds = 2;
  int questionTimerSeconds = 20;

  void setTotalRounds(int rounds) {
    totalRounds = rounds;
    notifyListeners();
  }

  void setQuestionTimerSeconds(int seconds) {
    if (seconds < 5) seconds = 5;
    questionTimerSeconds = seconds;
    notifyListeners();
  }

  // خريطة جيران كل خلية في الشبكة السداسية (حسب توزيع generateRandomHexKeyboard)
  static const List<List<List<List<int>>>> hexNeighbors = [
    // الصف 0
    [
      [],
      [],
      [
        [0, 2],
        [1, 1],
        [1, 2]
      ],
      [
        [0, 3],
        [1, 2],
        [1, 3]
      ],
      [
        [0, 4],
        [1, 3],
        [1, 4]
      ],
      [
        [0, 5],
        [1, 4],
        [1, 5]
      ],
      [],
      []
    ],
    // الصف 1
    [
      [],
      [
        [0, 2],
        [1, 2],
        [2, 0]
      ],
      [
        [0, 2],
        [1, 1],
        [1, 3],
        [2, 1]
      ],
      [
        [0, 3],
        [1, 2],
        [1, 4],
        [2, 2]
      ],
      [
        [0, 4],
        [1, 3],
        [1, 5],
        [2, 3]
      ],
      [
        [0, 5],
        [1, 4],
        [1, 6],
        [2, 4]
      ],
      [
        [0, 6],
        [1, 5],
        [2, 5]
      ],
      []
    ],
    // الصف 2
    [
      [
        [1, 1],
        [2, 1],
        [3, 1]
      ],
      [
        [1, 2],
        [2, 0],
        [2, 2],
        [3, 2]
      ],
      [
        [1, 3],
        [2, 1],
        [2, 3],
        [3, 3]
      ],
      [
        [1, 4],
        [2, 2],
        [2, 4],
        [3, 4]
      ],
      [
        [1, 5],
        [2, 3],
        [2, 5],
        [3, 5]
      ],
      [
        [1, 6],
        [2, 4],
        [3, 6]
      ],
      [
        [2, 5],
        [3, 6],
        [3, 7]
      ],
      [
        [2, 6],
        [3, 7]
      ]
    ],
    // الصف 3
    [
      [],
      [
        [2, 0],
        [3, 2],
        [4, 2]
      ],
      [
        [2, 1],
        [3, 1],
        [3, 3],
        [4, 3]
      ],
      [
        [2, 2],
        [3, 2],
        [3, 4],
        [4, 4]
      ],
      [
        [2, 3],
        [3, 3],
        [3, 5],
        [4, 5]
      ],
      [
        [2, 4],
        [3, 4],
        [3, 6],
        [4, 6]
      ],
      [
        [2, 5],
        [3, 5],
        [4, 7]
      ],
      []
    ],
    // الصف 4
    [
      [],
      [],
      [
        [3, 1],
        [4, 3]
      ],
      [
        [3, 2],
        [4, 2],
        [4, 4]
      ],
      [
        [3, 3],
        [4, 3],
        [4, 5]
      ],
      [
        [3, 4],
        [4, 4],
        [4, 6]
      ],
      [],
      []
    ],
  ];

  List<String> winnerPathLetters = [];

  List<List<String?>>? _hexKeyboardLayout;

  List<List<String?>> get hexKeyboardLayout =>
      _hexKeyboardLayout ??= generateRandomHexKeyboard();

  void resetHexKeyboard() {
    // إعادة تعيين لوحة المفاتيح السداسية
    _hexKeyboardLayout = generateRandomHexKeyboard();
  }

  // فوز الأحمر: من أول عمود (يسار) إلى آخر عمود (يمين)
  // فوز الأخضر: من أول صف (أعلى) إلى آخر صف (أسفل)
  List<String> checkConnectedPathWithLetters(Team team) {
    final grid = hexKeyboardLayout;
    final colorGrid = List.generate(5, (i) => List<String?>.filled(8, null));
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter != null && letterStatus[letter] == team) {
          colorGrid[r][c] = team == Team.red ? 'R' : 'G';
        }
      }
    }
    Set<String> visited = {};
    List<String> path = [];
    bool found = false;
    void dfs(int r, int c) {
      if (visited.contains('$r,$c')) return;
      visited.add('$r,$c');
      final letter = grid[r][c];
      if (letter != null) path.add(letter);
      if (team == Team.red && c == 7) found = true; // الأحمر: وصل للعمود الأخير
      if (team == Team.green && r == 4) found = true; // الأخضر: وصل للصف الأخير
      for (final n in hexNeighbors[r][c]) {
        final nr = n[0], nc = n[1];
        if (nr >= 0 &&
            nr < 5 &&
            nc >= 0 &&
            nc < 8 &&
            colorGrid[nr][nc] == (team == Team.red ? 'R' : 'G')) {
          dfs(nr, nc);
        }
      }
    }

    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        if (colorGrid[r][0] == 'R') {
          // الأحمر يبدأ من العمود الأول فقط
          path.clear();
          dfs(r, 0);
          if (found) break;
        }
      }
    }
    if (team == Team.green) {
      for (int c = 0; c < 8; c++) {
        if (colorGrid[0][c] == 'G') {
          // الأخضر يبدأ من الصف الأول فقط
          path.clear();
          dfs(0, c);
          if (found) break;
        }
      }
    }
    return found ? List<String>.from(path) : [];
  }

  // BFS: إيجاد أي مسار متصل للفريق من البداية للنهاية مع دعم حرف إضافي وdebug
  List<String> findConnectedPathBFS(Team team, {String? extraLetter}) {
    debugPrint('findConnectedPathBFS: team=$team, extraLetter=$extraLetter');
    final grid = hexKeyboardLayout;
    final colorGrid = List.generate(5, (i) => List<String?>.filled(8, null));
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter != null && letterStatus[letter] == team) {
          colorGrid[r][c] = team == Team.red ? 'R' : 'G';
        }
      }
    }
    if (extraLetter != null) {
      outer:
      for (int r = 0; r < 5; r++) {
        for (int c = 0; c < 8; c++) {
          if (grid[r][c] == extraLetter) {
            colorGrid[r][c] = team == Team.red ? 'R' : 'G';
            break outer;
          }
        }
      }
    }
    debugPrint(
        'colorGrid: ' + colorGrid.map((row) => row.join(",")).join(" | "));
    // BFS
    final queue = <List<dynamic>>[]; // [r, c, path]
    final visited = <String>{};
    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        if (colorGrid[r][0] == 'R') {
          queue.add([r, 0, <String>[]]);
          visited.add('$r,0');
        }
      }
      while (queue.isNotEmpty) {
        final curr = queue.removeAt(0);
        final r = curr[0], c = curr[1];
        final path = List<String>.from(curr[2]);
        final letter = grid[r][c];
        if (letter == null) continue;
        final newPath = List<String>.from(path)..add(letter);
        if (c == 7) {
          debugPrint(
              'findConnectedPathBFS: found path for red: ' + newPath.join(","));
          return newPath;
        }
        for (final n in hexNeighbors[r][c]) {
          final nr = n[0], nc = n[1];
          if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
            if (colorGrid[nr][nc] == 'R') {
              final key = '$nr,$nc';
              if (!visited.contains(key)) {
                visited.add(key);
                queue.add([nr, nc, newPath]);
              }
            }
          }
        }
      }
    } else {
      for (int c = 0; c < 8; c++) {
        if (colorGrid[0][c] == 'G') {
          queue.add([0, c, <String>[]]);
          visited.add('0,$c');
        }
      }
      while (queue.isNotEmpty) {
        final curr = queue.removeAt(0);
        final r = curr[0], c = curr[1];
        final path = List<String>.from(curr[2]);
        final letter = grid[r][c];
        if (letter == null) continue;
        final newPath = List<String>.from(path)..add(letter);
        if (r == 4) {
          debugPrint('findConnectedPathBFS: found path for green: ' +
              newPath.join(","));
          return newPath;
        }
        for (final n in hexNeighbors[r][c]) {
          final nr = n[0], nc = n[1];
          if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
            if (colorGrid[nr][nc] == 'G') {
              final key = '$nr,$nc';
              if (!visited.contains(key)) {
                visited.add(key);
                queue.add([nr, nc, newPath]);
              }
            }
          }
        }
      }
    }
    debugPrint('findConnectedPathBFS: no path found for team=$team');
    return [];
  }

  // دالة: تحقق إذا كان هناك خط متصل (أفقياً أو رأسياً أو قطرياً أو سداسياً) بطول minLength أو أكثر لأي فريق
  bool checkAnyLineWin(Team team, {int minLength = 4}) {
    final grid = hexKeyboardLayout;
    final colorGrid = List.generate(5, (i) => List<String?>.filled(8, null));
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter != null && letterStatus[letter] == team) {
          colorGrid[r][c] = team == Team.red ? 'R' : 'G';
        }
      }
    }
    // لكل خلية مملوكة للفريق، ابحث عن أطول خط متصل منها
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        if (colorGrid[r][c] == (team == Team.red ? 'R' : 'G')) {
          Set<String> visited = {};
          int maxLen = dfsLineLength(r, c, colorGrid, team, visited);
          if (maxLen >= minLength) return true;
        }
      }
    }
    return false;
  }

  // دالة مساعدة: تعيد طول أطول خط متصل من خلية معينة
  int dfsLineLength(int r, int c, List<List<String?>> colorGrid, Team team,
      Set<String> visited) {
    String key = '$r,$c';
    if (visited.contains(key)) return 0;
    visited = Set<String>.from(visited); // نسخة جديدة لكل فرع
    visited.add(key);
    int maxLen = 1;
    for (final n in hexNeighbors[r][c]) {
      int nr = n[0], nc = n[1];
      if (nr >= 0 &&
          nr < 5 &&
          nc >= 0 &&
          nc < 8 &&
          colorGrid[nr][nc] == (team == Team.red ? 'R' : 'G')) {
        maxLen =
            max(maxLen, 1 + dfsLineLength(nr, nc, colorGrid, team, visited));
      }
    }
    return maxLen;
  }

  // دالة تولد جميع المسارات الثابتة الممكنة (rows, columns, diagonals) بطول 4 خلايا أو أكثر
  static List<List<List<int>>> generateAllWinningPatterns({int minLength = 4}) {
    List<List<List<int>>> patterns = [];
    int rows = 5;
    int cols = 8;

    // أفقية (rows)
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c <= cols - minLength; c++) {
        List<List<int>> pattern = [];
        for (int k = 0; k < minLength; k++) {
          pattern.add([r, c + k]);
        }
        patterns.add(pattern);
      }
    }

    // رأسية (columns)
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r <= rows - minLength; r++) {
        List<List<int>> pattern = [];
        for (int k = 0; k < minLength; k++) {
          pattern.add([r + k, c]);
        }
        patterns.add(pattern);
      }
    }

    // قطري (يمين-أسفل)
    for (int r = 0; r <= rows - minLength; r++) {
      for (int c = 0; c <= cols - minLength; c++) {
        List<List<int>> pattern = [];
        for (int k = 0; k < minLength; k++) {
          pattern.add([r + k, c + k]);
        }
        patterns.add(pattern);
      }
    }

    // قطري (يسار-أسفل)
    for (int r = 0; r <= rows - minLength; r++) {
      for (int c = minLength - 1; c < cols; c++) {
        List<List<int>> pattern = [];
        for (int k = 0; k < minLength; k++) {
          pattern.add([r + k, c - k]);
        }
        patterns.add(pattern);
      }
    }

    // خطوط سداسية إضافية (جيران سداسيين)
    // خطوط "zigzag" يمين-أسفل
    for (int r = 0; r <= rows - minLength; r++) {
      for (int c = 0; c <= cols - minLength; c++) {
        List<List<int>> pattern = [];
        for (int k = 0; k < minLength; k++) {
          pattern.add([r + k, c + (k % 2 == 0 ? k : k - 1)]);
        }
        patterns.add(pattern);
      }
    }
    // خطوط "zigzag" يسار-أسفل
    for (int r = 0; r <= rows - minLength; r++) {
      for (int c = minLength - 1; c < cols; c++) {
        List<List<int>> pattern = [];
        for (int k = 0; k < minLength; k++) {
          pattern.add([r + k, c - (k % 2 == 0 ? k : k - 1)]);
        }
        patterns.add(pattern);
      }
    }

    return patterns;
  }

  // استخدم الدالة لتوليد مئات المسارات تلقائيًا
  static final List<List<List<int>>> predefinedWinningPatterns =
      generateAllWinningPatterns(minLength: 4);

  bool checkPredefinedWin(Team team, {String? lastLetter}) {
    final grid = hexKeyboardLayout;
    for (final pattern in predefinedWinningPatterns) {
      // إذا لم يكن المسار يحتوي على الحرف الأخير، تجاهله
      if (lastLetter != null) {
        bool contains = false;
        for (final pos in pattern) {
          int r = pos[0], c = pos[1];
          final letter = grid[r][c];
          if (letter == lastLetter) {
            contains = true;
            break;
          }
        }
        if (!contains) continue;
      }
      bool allOwned = true;
      for (final pos in pattern) {
        int r = pos[0], c = pos[1];
        final letter = grid[r][c];
        if (letter == null || letterStatus[letter] != team) {
          allOwned = false;
          break;
        }
      }
      if (allOwned) return true;
    }
    return false;
  }

  // عدل منطق checkConnectedPathAndScore ليستخدم القاعدة الجديدة
  void checkConnectedPathAndScore({String? lastLetter}) {
    debugPrint('checkConnectedPathAndScore entered. Last letter: $lastLetter');
    // حماية: لا تعلن فوز أو تزيد السكور إذا كانت الجولة منتهية
    if (isRoundOver) {
      debugPrint('checkConnectedPathAndScore: round already over, skipping.');
      return;
    }
    // 1) فوز الأحمر بمسار متصل حقيقي من اليسار لليمين
    final redPath = findConnectedPathBFS(Team.red);
    if (redPath.isNotEmpty) {
      redScore++;
      winnerTeam = Team.red;
      winnerPathLetters = redPath;
      showWinnerAnimation = true;
      isRoundOver = false;
      adminCanPickLetter = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        showWinnerAnimation = false;
        isRoundOver = true;
        adminCanPickLetter = true;
        notifyListeners();
      });
      debugPrint(
          'Connected path win: Red! Red score incremented to: $redScore');
      return;
    }
    // 2) فوز الأحمر بنمط ثابت (predefined pattern)
    if (checkPredefinedWin(Team.red, lastLetter: lastLetter)) {
      redScore++;
      winnerTeam = Team.red;
      // اجلب الحروف الفائزة في النمط
      winnerPathLetters =
          getWinningPatternLetters(Team.red, lastLetter: lastLetter);
      showWinnerAnimation = true;
      isRoundOver = false;
      adminCanPickLetter = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        showWinnerAnimation = false;
        isRoundOver = true;
        adminCanPickLetter = true;
        notifyListeners();
      });
      debugPrint(
          'Predefined pattern win: Red! Red score incremented to: $redScore');
      return;
    }
    // 3) فوز الأحمر بخط متصل (أي اتجاه) بطول 4 أو أكثر
    final redLine = getAnyLineWinLetters(Team.red, minLength: 4);
    if (redLine.isNotEmpty) {
      redScore++;
      winnerTeam = Team.red;
      winnerPathLetters = redLine;
      showWinnerAnimation = true;
      isRoundOver = false;
      adminCanPickLetter = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        showWinnerAnimation = false;
        isRoundOver = true;
        adminCanPickLetter = true;
        notifyListeners();
      });
      debugPrint('Line win: Red! Red score incremented to: $redScore');
      return;
    }
    // 1) فوز الأخضر بمسار متصل حقيقي من الأعلى للأسفل
    final greenPath = findConnectedPathBFS(Team.green);
    if (greenPath.isNotEmpty) {
      greenScore++;
      winnerTeam = Team.green;
      winnerPathLetters = greenPath;
      showWinnerAnimation = true;
      isRoundOver = false;
      adminCanPickLetter = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        showWinnerAnimation = false;
        isRoundOver = true;
        adminCanPickLetter = true;
        notifyListeners();
      });
      debugPrint(
          'Connected path win: Green! Green score incremented to: $greenScore');
      return;
    }
    // 2) فوز الأخضر بنمط ثابت (predefined pattern)
    if (checkPredefinedWin(Team.green, lastLetter: lastLetter)) {
      greenScore++;
      winnerTeam = Team.green;
      winnerPathLetters =
          getWinningPatternLetters(Team.green, lastLetter: lastLetter);
      showWinnerAnimation = true;
      isRoundOver = false;
      adminCanPickLetter = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        showWinnerAnimation = false;
        isRoundOver = true;
        adminCanPickLetter = true;
        notifyListeners();
      });
      debugPrint(
          'Predefined pattern win: Green! Green score incremented to: $greenScore');
      return;
    }
    // 3) فوز الأخضر بخط متصل (أي اتجاه) بطول 4 أو أكثر
    final greenLine = getAnyLineWinLetters(Team.green, minLength: 4);
    if (greenLine.isNotEmpty) {
      greenScore++;
      winnerTeam = Team.green;
      winnerPathLetters = greenLine;
      showWinnerAnimation = true;
      isRoundOver = false;
      adminCanPickLetter = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        showWinnerAnimation = false;
        isRoundOver = true;
        adminCanPickLetter = true;
        notifyListeners();
      });
      debugPrint('Line win: Green! Green score incremented to: $greenScore');
      return;
    }
    // لا يوجد فوز
    winnerTeam = Team.none;
    winnerPathLetters = [];
    debugPrint('No winner by any win logic this round.');
    notifyListeners();
  }

  // دالة مساعدة: تعيد الحروف الفائزة في أول نمط ثابت للفريق
  List<String> getWinningPatternLetters(Team team, {String? lastLetter}) {
    for (final pattern in predefinedWinningPatterns) {
      bool allOwned = true;
      List<String> letters = [];
      for (final pos in pattern) {
        final r = pos[0], c = pos[1];
        final letter = hexKeyboardLayout[r][c];
        if (letter == null || letterStatus[letter] != team) {
          allOwned = false;
          break;
        }
        letters.add(letter);
      }
      if (allOwned) return letters;
    }
    return [];
  }

  // دالة مساعدة: تعيد الحروف في أطول خط متصل للفريق بطول minLength أو أكثر
  List<String> getAnyLineWinLetters(Team team, {int minLength = 4}) {
    final grid = hexKeyboardLayout;
    final colorGrid = List.generate(5, (i) => List<String?>.filled(8, null));
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter != null && letterStatus[letter] == team) {
          colorGrid[r][c] = team == Team.red ? 'R' : 'G';
        }
      }
    }
    List<String> bestLine = [];
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        if (colorGrid[r][c] == (team == Team.red ? 'R' : 'G')) {
          Set<String> visited = {};
          List<String> line = dfsCollectLine(r, c, colorGrid, team, visited);
          if (line.length >= minLength && line.length > bestLine.length) {
            bestLine = line;
          }
        }
      }
    }
    return bestLine;
  }

  // دالة مساعدة: تجمع الحروف في خط متصل من خلية معينة
  List<String> dfsCollectLine(int r, int c, List<List<String?>> colorGrid,
      Team team, Set<String> visited) {
    String key = '$r,$c';
    if (visited.contains(key)) return [];
    visited = Set<String>.from(visited); // نسخة جديدة لكل فرع
    visited.add(key);
    List<String> line = [hexKeyboardLayout[r][c]!];
    for (final n in hexNeighbors[r][c]) {
      int nr = n[0], nc = n[1];
      if (nr >= 0 &&
          nr < 5 &&
          nc >= 0 &&
          nc < 8 &&
          colorGrid[nr][nc] == (team == Team.red ? 'R' : 'G')) {
        line.addAll(dfsCollectLine(nr, nc, colorGrid, team, visited));
      }
    }
    return line;
  }

  GameProvider() {
    loadQuestions();
  }

  static const List<String> allLetters = [
    'ا',
    'ب',
    'ت',
    'ث',
    'ج',
    'ح',
    'خ',
    'د',
    'ذ',
    'ر',
    'ز',
    'س',
    'ش',
    'ص',
    'ض',
    'ط',
    'ظ',
    'ع',
    'غ',
    'ف',
    'ق',
    'ك',
    'ل',
    'م',
    'ن',
    'هـ',
    'و',
    'ي'
  ];

  List<List<String?>> generateRandomHexKeyboard(
      {List<String>? preferredLetters}) {
    final letters = List<String>.from(allLetters);
    if (preferredLetters != null && preferredLetters.isNotEmpty) {
      letters.removeWhere((l) => preferredLetters.contains(l));
      letters.insertAll(0, preferredLetters);
    } else {
      letters.shuffle(Random());
    }
    // تحقق من التكرار قبل بناء الشبكة
    final tempList = List<String>.from(letters);
    final tempSet = tempList.toSet();
    if (tempList.length != tempSet.length) {
      return generateRandomHexKeyboard();
    }
    // شبكة كاملة 5x8، كل صف 8 عناصر (حتى الزوايا)
    // تأكد أن كل صف يحتوي على 8 عناصر بالضبط (حتى الصفوف الأولى والأخيرة)
    return [
      [
        null,
        null,
        letters[0],
        letters[1],
        letters[2],
        letters[3],
        null,
        null
      ], // 8 عناصر
      [
        null,
        letters[4],
        letters[5],
        letters[6],
        letters[7],
        letters[8],
        letters[9],
        null
      ], // 8 عناصر
      [
        letters[10],
        letters[11],
        letters[12],
        letters[13],
        letters[14],
        letters[15],
        letters[16],
        letters[17]
      ], // 8 عناصر
      [
        null,
        letters[18],
        letters[19],
        letters[20],
        letters[21],
        letters[22],
        letters[23],
        null
      ], // 8 عناصر
      [
        null,
        null,
        letters[24],
        letters[25],
        letters[26],
        letters[27],
        null,
        null
      ], // 8 عناصر
    ];
  }

  Future<void> loadQuestions() async {
    allQuestions = await QuestionStorage.loadQuestionsFromLocal();
    // بناء قائمة الأسئلة لكل حرف
    questionsByLetter = {};
    for (var q in allQuestions) {
      final letter = q['letter'];
      questionsByLetter.putIfAbsent(letter, () => []).add(q);
    }
    // اختيار حروف مفضلة (منتصف اللوحة أو غير مملوكة)
    final preferred = allLetters
        .where((l) => letterStatus[l] == null || letterStatus[l] == Team.none)
        .toList();
    currentQuestions = [];
    questionsByLetter.forEach((letter, qs) {
      qs.shuffle();
      final question = qs.first;
      // خلط الخيارات لكل سؤال
      final options = List<String>.from(question['options']);
      final correctAnswer = question['answer'];
      options.shuffle();
      // إنشاء سؤال جديد مع خيارات مختلطة
      final shuffledQuestion = Map<String, dynamic>.from(question);
      shuffledQuestion['options'] = options;
      shuffledQuestion['answer'] = correctAnswer; // الإجابة الصحيحة تبقى كما هي
      currentQuestions.add(shuffledQuestion);
    });
    skippedQuestions = [];
    for (var q in currentQuestions) {
      letterStatus[q['letter']] = Team.none;
    }
    currentIndex = 0;
    isGameOver = false;
    selectedTeam = Team.none;
    notifyListeners();
    startTimer();
  }

  // دالة جديدة لإعادة اللعبة بالكامل بدون تصفير النقاط
  Future<void> resetGame({bool resetScores = false}) async {
    if (resetScores) {
      greenScore = 0;
      redScore = 0;
    }
    roundNumber = 1;
    isRoundOver = false;
    isGameOver = false;
    winnerTeam = Team.none;
    winnerPathLetters = [];
    showWinnerAnimation = false;
    adminCanPickLetter = false;
    await loadQuestions();
  }

  Future<void> addQuestionToLocal(Map<String, dynamic> newQ) async {
    await QuestionStorage.ensureLocalQuestionsExist();
    final questions = await QuestionStorage.loadQuestionsFromLocal();
    questions.add(newQ);
    await QuestionStorage.saveQuestionsToLocal(questions);
    // أعد تحميل الأسئلة في اللعبة إذا أردت
    await loadQuestions();
  }

  Map<String, dynamic>? get currentQuestion =>
      (currentIndex < currentQuestions.length)
          ? currentQuestions[currentIndex]
          : null;

  void startTimer() {
    timer = questionTimerSeconds;
    answered = false;
    selectedOption = null;
    isCorrect = null;
    selectedTeam = Team.none;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timer > 0) {
        timer--;
        notifyListeners();
      } else {
        t.cancel();
        skip(auto: true);
      }
    });
  }

  void selectTeam(Team team) {
    if (answered) return;
    selectedTeam = team;
    notifyListeners();
  }

  // في selectOption: مرر الحرف الأخير عند التحقق من الفوز
  void selectOption(String option) {
    if (answered || selectedTeam == Team.none) return;
    selectedOption = option;
    isCorrect = option == currentQuestion?['answer'];
    answered = true;
    if (isCorrect == true) {
      // زيادة النقاط مباشرة مع كل إجابة صحيحة
      if (selectedTeam == Team.green) {
        greenScore++;
        letterStatus[currentQuestion?['letter']] = Team.green;
      } else if (selectedTeam == Team.red) {
        redScore++;
        letterStatus[currentQuestion?['letter']] = Team.red;
      }
      notifyListeners();
      // مرر الحرف الأخير
      checkConnectedPathAndScore(lastLetter: currentQuestion?['letter']);
      // --- فحص إذا لم يعد هناك أي إمكانية للفوز ---
      if (!_canAnyTeamWin()) {
        isGameOver = true;
        notifyListeners();
        return;
      }
      // --- نهاية الفحص ---
    }
    _timer?.cancel();
    notifyListeners();
  }

  // دالة جديدة: هل يمكن لأي فريق تكوين صف أو عمود أو قطر؟
  bool _canAnyTeamWin() {
    // إذا كان هناك أي طريق متاح للفوز لأي فريق، أرجع true
    return _canTeamWin(Team.red) || _canTeamWin(Team.green);
  }

  bool _canTeamWin(Team team) {
    final grid =
        hexKeyboardLayout; // استخدم الشبكة الحالية بدلاً من توليد جديدة
    final colorGrid = List.generate(5, (i) => List<String?>.filled(8, null));
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter != null && letterStatus[letter] == team) {
          colorGrid[r][c] = team == Team.red ? 'R' : 'G';
        }
      }
    }
    // نبحث عن أي مسار محتمل (غير مكتمل بعد) من البداية للنهاية
    Set<String> visited = {};
    bool found = false;
    void dfs(int r, int c) {
      if (visited.contains('$r,$c')) return;
      visited.add('$r,$c');
      final letter = grid[r][c];
      // إذا كانت الخلية فارغة أو ملونة للفريق الآخر، لا تكمل
      if (letter == null ||
          (letterStatus[letter] != Team.none && letterStatus[letter] != team))
        return;
      if (team == Team.red && c == 7) found = true;
      if (team == Team.green && r == 4) found = true;
      for (final n in hexNeighbors[r][c]) {
        final nr = n[0], nc = n[1];
        if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
          dfs(nr, nc);
        }
      }
    }

    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        if (grid[r][0] != null &&
            (letterStatus[grid[r][0]] == Team.none ||
                letterStatus[grid[r][0]] == team)) {
          visited.clear();
          dfs(r, 0);
          if (found) break;
        }
      }
    }
    if (team == Team.green) {
      for (int c = 0; c < 8; c++) {
        if (grid[0][c] != null &&
            (letterStatus[grid[0][c]] == Team.none ||
                letterStatus[grid[0][c]] == team)) {
          visited.clear();
          dfs(0, c);
          if (found) break;
        }
      }
    }
    return found;
  }

  /// تقترح الحروف الحرجة للفريق (التي تقربه من الفوز أو متجاورة لمساره)
  List<String> suggestCriticalLetters(Team team) {
    final grid = hexKeyboardLayout;
    final Set<String> result = {};
    // 1. ابحث عن الحروف المجاورة لمسار الفريق الحالي
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter == null) continue;
        if (letterStatus[letter] == team) {
          // أضف كل الجيران غير المملوكين لأي فريق
          for (final n in hexNeighbors[r][c]) {
            final nr = n[0], nc = n[1];
            if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
              final neigh = grid[nr][nc];
              if (neigh != null && letterStatus[neigh] == Team.none) {
                result.add(neigh);
              }
            }
          }
        }
      }
    }
    // 2. إذا لم يوجد أي حرف مجاور لمسار الفريق، اقترح أي حرف متاح
    if (result.isEmpty) {
      for (int r = 0; r < 5; r++) {
        for (int c = 0; c < 8; c++) {
          final letter = grid[r][c];
          if (letter != null && letterStatus[letter] == Team.none) {
            result.add(letter);
          }
        }
      }
    }
    return result.toList();
  }

  void skip({bool auto = false}) {
    if (answered) return;
    answered = true;
    _timer?.cancel();
    // إذا كان skip تلقائي أو يدوي، أضف للسكيب
    if (currentQuestion != null) {
      skippedQuestions.add(currentQuestion!);
    }
    notifyListeners();
  }

  void nextQuestion() {
    if (currentIndex < currentQuestions.length - 1) {
      currentIndex++;
      answered = false;
      selectedTeam = Team.none;
      startTimer();
      notifyListeners();
    } else if (skippedQuestions.isNotEmpty) {
      // إذا انتهت الأسئلة الأساسية، نبدأ بالأسئلة التي تم تخطيها
      currentQuestions = [];
      for (var question in skippedQuestions) {
        // خلط الخيارات مرة أخرى للأسئلة المخطوفة
        final options = List<String>.from(question['options']);
        final correctAnswer = question['answer'];
        options.shuffle();
        final shuffledQuestion = Map<String, dynamic>.from(question);
        shuffledQuestion['options'] = options;
        shuffledQuestion['answer'] = correctAnswer;
        currentQuestions.add(shuffledQuestion);
      }
      skippedQuestions = [];
      currentIndex = 0;
      answered = false;
      selectedTeam = Team.none;
      startTimer();
      notifyListeners();
    } else {
      isGameOver = true;
      notifyListeners();
    }
  }

  void startNextRound() {
    if (roundNumber >= totalRounds) {
      isGameOver = true;
      notifyListeners();
      return;
    }
    isGameOver = false; // إصلاح: إعادة اللعبة لوضع التشغيل عند بدء جولة جديدة
    roundNumber++;
    isRoundOver = false;
    adminCanPickLetter = false;
    winnerPathLetters = [];
    winnerTeam = Team.none;
    answered = false;
    selectedTeam = Team.none;
    selectedOption = null;
    isCorrect = null;
    // لا تعيد توزيع الأسئلة هنا!
    resetHexKeyboard();
    startTimer();
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
  }

  int _minStepsToWin(Team team, String candidateLetter) {
    // انسخ الشبكة الحالية
    final grid = hexKeyboardLayout;
    final Map<String, Team> tempStatus = Map<String, Team>.from(letterStatus);
    tempStatus[candidateLetter] = team;
    // BFS لإيجاد أقصر مسار للفوز
    final queue = <List<int>>[];
    final visited = <String>{};
    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        final letter = grid[r][0];
        if (letter != null &&
            (tempStatus[letter] == Team.none || tempStatus[letter] == team)) {
          queue.add([r, 0, 0]); // r, c, steps
          visited.add('$r,0');
        }
      }
    } else {
      for (int c = 0; c < 8; c++) {
        final letter = grid[0][c];
        if (letter != null &&
            (tempStatus[letter] == Team.none || tempStatus[letter] == team)) {
          queue.add([0, c, 0]);
          visited.add('0,$c');
        }
      }
    }
    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final r = curr[0], c = curr[1], steps = curr[2];
      final letter = grid[r][c];
      if (letter == null) continue;
      if (team == Team.red && c == 7) return steps;
      if (team == Team.green && r == 4) return steps;
      for (final n in hexNeighbors[r][c]) {
        final nr = n[0], nc = n[1];
        if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
          final neigh = grid[nr][nc];
          if (neigh != null &&
              (tempStatus[neigh] == Team.none || tempStatus[neigh] == team)) {
            final key = '$nr,$nc';
            if (!visited.contains(key)) {
              visited.add(key);
              queue.add([nr, nc, steps + 1]);
            }
          }
        }
      }
    }
    return 99; // لا يوجد طريق للفوز
  }

  // دالة: هل اختيار هذا الحرف يؤدي للفوز الفوري؟
  bool _isImmediateWin(Team team, String candidateLetter) {
    final grid = hexKeyboardLayout;
    final Map<String, Team> tempStatus = Map<String, Team>.from(letterStatus);
    tempStatus[candidateLetter] = team;
    // BFS
    final queue = <List<int>>[];
    final visited = <String>{};
    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        final letter = grid[r][0];
        if (letter != null &&
            (tempStatus[letter] == Team.none || tempStatus[letter] == team)) {
          queue.add([r, 0]);
          visited.add('$r,0');
        }
      }
    } else {
      for (int c = 0; c < 8; c++) {
        final letter = grid[0][c];
        if (letter != null &&
            (tempStatus[letter] == Team.none || tempStatus[letter] == team)) {
          queue.add([0, c]);
          visited.add('0,$c');
        }
      }
    }
    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final r = curr[0], c = curr[1];
      final letter = grid[r][c];
      if (letter == null) continue;
      if (team == Team.red && c == 7) return true;
      if (team == Team.green && r == 4) return true;
      for (final n in hexNeighbors[r][c]) {
        final nr = n[0], nc = n[1];
        if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
          final neigh = grid[nr][nc];
          if (neigh != null &&
              (tempStatus[neigh] == Team.none || tempStatus[neigh] == team)) {
            final key = '$nr,$nc';
            if (!visited.contains(key)) {
              visited.add(key);
              queue.add([nr, nc]);
            }
          }
        }
      }
    }
    return false;
  }

  // دالة: كم عدد حروف الفريق الحالي في أقصر مسار للفوز إذا اختير هذا الحرف
  int _countTeamLettersInPath(Team team, String candidateLetter) {
    final grid = hexKeyboardLayout;
    final Map<String, Team> tempStatus = Map<String, Team>.from(letterStatus);
    tempStatus[candidateLetter] = team;
    // BFS مع تتبع المسار
    final queue = <List<dynamic>>[]; // [r, c, steps, path]
    final visited = <String>{};
    int maxCount = 0;
    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        final letter = grid[r][0];
        if (letter != null &&
            (tempStatus[letter] == Team.none || tempStatus[letter] == team)) {
          queue.add([r, 0, 0, <String>[]]);
          visited.add('$r,0');
        }
      }
    } else {
      for (int c = 0; c < 8; c++) {
        final letter = grid[0][c];
        if (letter != null &&
            (tempStatus[letter] == Team.none || tempStatus[letter] == team)) {
          queue.add([0, c, 0, <String>[]]);
          visited.add('0,$c');
        }
      }
    }
    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final r = curr[0], c = curr[1], steps = curr[2];
      final path = List<String>.from(curr[3]);
      final letter = grid[r][c];
      if (letter == null) continue;
      final newPath = List<String>.from(path)..add(letter);
      if ((team == Team.red && c == 7) || (team == Team.green && r == 4)) {
        final count = newPath.where((l) => tempStatus[l] == team).length;
        if (count > maxCount) maxCount = count;
        continue;
      }
      for (final n in hexNeighbors[r][c]) {
        final nr = n[0], nc = n[1];
        if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
          final neigh = grid[nr][nc];
          if (neigh != null &&
              (tempStatus[neigh] == Team.none || tempStatus[neigh] == team)) {
            final key = '$nr,$nc';
            if (!visited.contains(key)) {
              visited.add(key);
              queue.add([nr, nc, steps + 1, newPath]);
            }
          }
        }
      }
    }
    return maxCount;
  }

  // دالة: كم عدد المسارات الممكنة للفوز بعد اختيار هذا الحرف
  int _countWinningPaths(Team team, String candidateLetter) {
    final grid = hexKeyboardLayout;
    final Map<String, Team> tempStatus = Map<String, Team>.from(letterStatus);
    tempStatus[candidateLetter] = team;
    int count = 0;
    // BFS من كل نقطة بداية
    if (team == Team.red) {
      for (int r = 0; r < 5; r++) {
        final visited = <String>{};
        final queue = <List<int>>[];
        if (grid[r][0] != null &&
            (tempStatus[grid[r][0]] == Team.none ||
                tempStatus[grid[r][0]] == team)) {
          queue.add([r, 0]);
          visited.add('$r,0');
        }
        while (queue.isNotEmpty) {
          final curr = queue.removeAt(0);
          final cr = curr[0], cc = curr[1];
          if (cc == 7) {
            count++;
            break;
          }
          for (final n in hexNeighbors[cr][cc]) {
            final nr = n[0], nc = n[1];
            if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
              final neigh = grid[nr][nc];
              if (neigh != null &&
                  (tempStatus[neigh] == Team.none ||
                      tempStatus[neigh] == team)) {
                final key = '$nr,$nc';
                if (!visited.contains(key)) {
                  visited.add(key);
                  queue.add([nr, nc]);
                }
              }
            }
          }
        }
      }
    } else {
      for (int c = 0; c < 8; c++) {
        final visited = <String>{};
        final queue = <List<int>>[];
        if (grid[0][c] != null &&
            (tempStatus[grid[0][c]] == Team.none ||
                tempStatus[grid[0][c]] == team)) {
          queue.add([0, c]);
          visited.add('0,$c');
        }
        while (queue.isNotEmpty) {
          final curr = queue.removeAt(0);
          final cr = curr[0], cc = curr[1];
          if (cr == 4) {
            count++;
            break;
          }
          for (final n in hexNeighbors[cr][cc]) {
            final nr = n[0], nc = n[1];
            if (nr >= 0 && nr < 5 && nc >= 0 && nc < 8) {
              final neigh = grid[nr][nc];
              if (neigh != null &&
                  (tempStatus[neigh] == Team.none ||
                      tempStatus[neigh] == team)) {
                final key = '$nr,$nc';
                if (!visited.contains(key)) {
                  visited.add(key);
                  queue.add([nr, nc]);
                }
              }
            }
          }
        }
      }
    }
    return count;
  }

  // دالة: هل الفريق الآخر قريب من الفوز (خطوة واحدة)
  String? _blockOpponentIfCritical(Team team) {
    final opponent = team == Team.red ? Team.green : Team.red;
    final grid = hexKeyboardLayout;
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 8; c++) {
        final letter = grid[r][c];
        if (letter == null || letterStatus[letter] != Team.none) continue;
        // جرب لو الفريق الآخر أخذ هذا الحرف، هل سيفوز؟
        if (_isImmediateWin(opponent, letter)) {
          return letter;
        }
      }
    }
    return null;
  }

  void adminPickLetter([String? letter]) {
    if (!isRoundOver || !adminCanPickLetter) return;
    final team = selectedTeam == Team.none ? Team.red : selectedTeam;
    final criticalLetters = suggestCriticalLetters(team);
    String? chosenLetter = letter;
    // 1. الفوز الفوري
    for (final l in criticalLetters) {
      if (_isImmediateWin(team, l)) {
        chosenLetter = l;
        break;
      }
    }
    // 2. إذا لم يوجد فوز فوري
    if (chosenLetter == null ||
        !criticalLetters.contains(chosenLetter) ||
        currentQuestions.indexWhere((q) => q['letter'] == chosenLetter) == -1) {
      // 3. الهجوم: اختر الحرف الذي يفتح أكبر عدد من المسارات الممكنة للفوز (forks)
      int maxPaths = -1;
      List<String> bestLetters = [];
      for (final l in criticalLetters) {
        final paths = _countWinningPaths(team, l);
        if (paths > maxPaths) {
          maxPaths = paths;
          bestLetters = [l];
        } else if (paths == maxPaths) {
          bestLetters.add(l);
        }
      }
      if (bestLetters.isNotEmpty && maxPaths > 0) {
        chosenLetter = bestLetters[Random().nextInt(bestLetters.length)];
      } else if (criticalLetters.isNotEmpty) {
        // fallback: أقصر طريق للفوز
        int minSteps = 99;
        List<String> bestLetters2 = [];
        for (final l in criticalLetters) {
          final steps = _minStepsToWin(team, l);
          if (steps < minSteps) {
            minSteps = steps;
            bestLetters2 = [l];
          } else if (steps == minSteps) {
            bestLetters2.add(l);
          }
        }
        if (bestLetters2.isNotEmpty) {
          chosenLetter = bestLetters2[Random().nextInt(bestLetters2.length)];
        } else {
          chosenLetter = criticalLetters.first;
        }
      } else {
        chosenLetter = currentQuestions.firstWhere(
            (q) => letterStatus[q['letter']] == Team.none)['letter'];
      }
    }
    final q = currentQuestions.firstWhere((q) => q['letter'] == chosenLetter,
        orElse: () => null as Map<String, dynamic>);
    if (q != null) {
      currentIndex = currentQuestions.indexOf(q);
      answered = false;
      selectedTeam = Team.none;
      selectedOption = null;
      isCorrect = null;
      winnerPathLetters = [];
      isRoundOver = false;
      adminCanPickLetter = false;
      roundNumber++;
      // تصفير تلوين الحروف فقط (النقاط محفوظة)
      for (var l in letterStatus.keys) {
        letterStatus[l] = Team.none;
      }
      // إعادة توزيع الشبكة
      resetHexKeyboard();
      notifyListeners();
      startTimer();
    }
  }

  // عند نهاية الجولة، إذا انتهت الجولات أعلن الفائز النهائي
  bool get isFinalRoundOver => roundNumber > totalRounds;

  Future<void> triggerWinnerAnimation(Team team) async {
    showWinnerAnimation = true;
    winnerTeam = team;
    notifyListeners();
    // تشغيل صوت الفوز (كل الامتدادات)
    await _playWinSound();
    await Future.delayed(const Duration(seconds: 2));
    showWinnerAnimation = false;
    notifyListeners();
    // انتقل للجولة التالية أو منطقك الخاص
    startNextRound();
  }

  Future<void> _playWinSound() async {
    final formats = ['mp3', 'ogg', 'wav', 'm4a'];
    for (final ext in formats) {
      try {
        // استخدم أي منطق صوتي مناسب لديك هنا
        // AudioPlayer().play(AssetSource('sounds/win.$ext'));
        break;
      } catch (e) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
