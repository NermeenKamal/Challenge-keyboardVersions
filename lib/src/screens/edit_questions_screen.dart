import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game_provider.dart';
import '../question_storage.dart';

class EditQuestionsScreen extends StatefulWidget {
  const EditQuestionsScreen({super.key});

  @override
  State<EditQuestionsScreen> createState() => _EditQuestionsScreenState();
}

class _EditQuestionsScreenState extends State<EditQuestionsScreen> {
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> filteredQuestions = [];
  bool loading = true;
  String search = '';
  String sortBy = 'letter';
  int? lastEditedIdx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    questions = await QuestionStorage.loadQuestionsFromLocal();
    _applyFilterSort();
    setState(() => loading = false);
  }

  void _applyFilterSort() {
    filteredQuestions = questions.where((q) {
      if (search.isEmpty) return true;
      if (search.length == 1) {
        // بحث بحرف فقط
        return q['letter'].toString() == search;
      } else {
        // بحث نصي في السؤال
        return q['question'].toString().contains(search);
      }
    }).toList();
    filteredQuestions.sort((a, b) => sortBy == 'letter'
        ? a['letter'].compareTo(b['letter'])
        : a['question'].compareTo(b['question']));
  }

  Future<void> _editQuestion(int idx) async {
    final q = filteredQuestions[idx];
    final ctrlQ = TextEditingController(text: q['question']);
    final ctrls =
        List.generate(4, (i) => TextEditingController(text: q['options'][i]));
    int correct = q['options'].indexOf(q['answer']);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل السؤال (${q['letter']})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlQ,
                decoration: const InputDecoration(labelText: 'نص السؤال'),
              ),
              ...List.generate(
                  4,
                  (i) => ListTile(
                        leading: Radio<int>(
                          value: i,
                          groupValue: correct,
                          onChanged: (v) => setState(() => correct = v!),
                          activeColor: Colors.green,
                        ),
                        title: TextField(
                          controller: ctrls[i],
                          decoration:
                              InputDecoration(labelText: 'اختيار ${i + 1}'),
                        ),
                        tileColor: correct == i ? Colors.green[50] : null,
                      )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final opts = ctrls.map((c) => c.text).toList();
              Navigator.pop(context, {
                'question': ctrlQ.text,
                'options': opts,
                'answer': opts[correct],
              });
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null) {
      final origIdx = questions.indexWhere((qq) =>
          qq['question'] == q['question'] && qq['letter'] == q['letter']);
      setState(() {
        questions[origIdx]['question'] = result['question'];
        questions[origIdx]['options'] = result['options'];
        questions[origIdx]['answer'] = result['answer'];
        lastEditedIdx = origIdx;
        _applyFilterSort();
      });
      await QuestionStorage.saveQuestionsToLocal(questions);
      await Provider.of<GameProvider>(context, listen: false).loadQuestions();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تحديث السؤال!')));
    }
  }

  Future<void> _deleteQuestion(int idx) async {
    final q = filteredQuestions[idx];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل تريد حذف هذا السؤال نهائياً؟\n${q['letter']} - ${q['question']}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirm == true) {
      final origIdx = questions.indexWhere((qq) =>
          qq['question'] == q['question'] && qq['letter'] == q['letter']);
      setState(() {
        questions.removeAt(origIdx);
        lastEditedIdx = null;
        _applyFilterSort();
      });
      await QuestionStorage.saveQuestionsToLocal(questions);
      await Provider.of<GameProvider>(context, listen: false).loadQuestions();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف السؤال!')));
    }
  }

  Future<void> _addQuestion() async {
    final ctrlQ = TextEditingController();
    final ctrls = List.generate(4, (i) => TextEditingController());
    int correct = 0;
    String letter = '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة سؤال جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'الحرف'),
                onChanged: (v) => letter = v,
              ),
              TextField(
                controller: ctrlQ,
                decoration: const InputDecoration(labelText: 'نص السؤال'),
              ),
              ...List.generate(
                  4,
                  (i) => ListTile(
                        leading: Radio<int>(
                          value: i,
                          groupValue: correct,
                          onChanged: (v) => setState(() => correct = v!),
                          activeColor: Colors.green,
                        ),
                        title: TextField(
                          controller: ctrls[i],
                          decoration:
                              InputDecoration(labelText: 'اختيار ${i + 1}'),
                        ),
                        tileColor: correct == i ? Colors.green[50] : null,
                      )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final opts = ctrls.map((c) => c.text).toList();
              Navigator.pop(context, {
                'letter': letter,
                'question': ctrlQ.text,
                'options': opts,
                'answer': opts[correct],
              });
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        questions.add(result);
        lastEditedIdx = questions.length - 1;
        _applyFilterSort();
      });
      await QuestionStorage.saveQuestionsToLocal(questions);
      await Provider.of<GameProvider>(context, listen: false).loadQuestions();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تمت إضافة السؤال!')));
    }
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
        title: const Text('تعديل الأسئلة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة سؤال جديد',
            onPressed: _addQuestion,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'بحث عن سؤال أو حرف',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) {
                            setState(() {
                              search = v;
                              _applyFilterSort();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: sortBy,
                        items: const [
                          DropdownMenuItem(
                              value: 'letter', child: Text('ترتيب بالحرف')),
                          DropdownMenuItem(
                              value: 'question', child: Text('ترتيب بالسؤال')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            sortBy = v!;
                            _applyFilterSort();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredQuestions.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final q = filteredQuestions[i];
                      final origIdx = questions.indexWhere((qq) =>
                          qq['question'] == q['question'] &&
                          qq['letter'] == q['letter']);
                      return ListTile(
                        tileColor:
                            lastEditedIdx == origIdx ? Colors.yellow[50] : null,
                        title: Text('${q['letter']} - ${q['question']}'),
                        subtitle: Text('الإجابة: ${q['answer']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editQuestion(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteQuestion(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
