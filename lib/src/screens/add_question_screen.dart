import 'package:flutter/material.dart';
import '../question_storage.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  String letter = '';
  String question = '';
  List<String> options = ['', '', '', ''];
  int correctIndex = 0;

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
        title: const Text('إضافة سؤال جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'الحرف'),
                maxLength: 1,
                validator: (v) => v == null || v.isEmpty ? 'أدخل الحرف' : null,
                onSaved: (v) => letter = v!.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'نص السؤال'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'أدخل نص السؤال' : null,
                onSaved: (v) => question = v!,
              ),
              const SizedBox(height: 16),
              ...List.generate(
                  4,
                  (i) => ListTile(
                        leading: Radio<int>(
                          value: i,
                          groupValue: correctIndex,
                          onChanged: (v) => setState(() => correctIndex = v!),
                        ),
                        title: TextFormField(
                          decoration:
                              InputDecoration(labelText: 'اختيار ${i + 1}'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'أدخل الاختيار' : null,
                          onSaved: (v) => options[i] = v!,
                        ),
                      )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    final newQuestion = {
                      'letter': letter,
                      'question': question,
                      'options': options,
                      'answer': options[correctIndex],
                    };

                    // إضافة السؤال للتخزين المحلي
                    await QuestionStorage.addQuestion(newQuestion);

                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ السؤال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
