import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int rounds;
  late int seconds;

  @override
  void initState() {
    super.initState();
    final game = Provider.of<GameProvider>(context, listen: false);
    rounds = game.totalRounds;
    seconds = game.questionTimerSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('الإعدادات'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('عدد الجولات:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: rounds.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$rounds',
                    onChanged: (v) => setState(() => rounds = v.round()),
                  ),
                ),
                SizedBox(width: 12),
                Text('$rounds', style: TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('مدة كل سؤال (ثانية):',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: seconds.toDouble(),
                    min: 5, // الحد الأدنى 5 ثواني
                    max: 60,
                    divisions: 11,
                    label: '$seconds',
                    onChanged: (v) => setState(() => seconds =
                        v.round() < 5 ? 5 : v.round()), // لا يسمح بأقل من 5
                  ),
                ),
                SizedBox(width: 12),
                Text('$seconds', style: TextStyle(fontSize: 18)),
              ],
            ),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text('حفظ'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(160, 48),
                  textStyle:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final game =
                      Provider.of<GameProvider>(context, listen: false);
                  game.setTotalRounds(rounds);
                  game.setQuestionTimerSeconds(seconds);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('إضافة لعبة جديدة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(180, 48),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  String? gameName;
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('إضافة لعبة جديدة'),
                        content: TextField(
                          autofocus: true,
                          decoration: InputDecoration(hintText: 'اسم اللعبة'),
                          onChanged: (v) => gameName = v,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (gameName != null &&
                                  gameName!.trim().isNotEmpty) {
                                Navigator.pop(context);
                                // يمكنك لاحقًا حفظ الاسم في قائمة أو قاعدة بيانات
                              }
                            },
                            child: Text('حفظ'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
