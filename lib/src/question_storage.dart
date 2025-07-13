import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

class QuestionStorage {
  static const String _boxName = 'questionsBox';

  // التأكد من وجود الأسئلة في Hive، وإن لم توجد يتم نسخها من الأصول
  static Future<void> ensureLocalQuestionsExist() async {
    final box = Hive.box(_boxName);
    if (box.isEmpty) {
      final data = await rootBundle.loadString('assets/questions.json');
      final list = json.decode(data) as List;
      await box.put('questions', list);
    }
  }

  // تحميل الأسئلة من Hive
  static Future<List<Map<String, dynamic>>> loadQuestionsFromLocal() async {
    await ensureLocalQuestionsExist();
    final box = Hive.box(_boxName);
    final list = box.get('questions', defaultValue: []) as List;
    return List<Map<String, dynamic>>.from(list);
  }

  // حفظ الأسئلة إلى Hive
  static Future<void> saveQuestionsToLocal(
      List<Map<String, dynamic>> questions) async {
    final box = Hive.box(_boxName);
    await box.put('questions', questions);
  }

  // إعادة ضبط الأسئلة الافتراضية من الأصول
  static Future<void> resetQuestionsToDefault() async {
    final box = Hive.box(_boxName);
    final data = await rootBundle.loadString('assets/questions.json');
    final list = json.decode(data) as List;
    await box.put('questions', list);
  }

  // إضافة سؤال جديد
  static Future<void> addQuestion(Map<String, dynamic> question) async {
    final questions = await loadQuestionsFromLocal();
    questions.add(question);
    await saveQuestionsToLocal(questions);
  }
}
