import 'package:flutter/material.dart';

class QuestionWidget extends StatelessWidget {
  final String question;
  final String letter;
  const QuestionWidget({super.key, required this.question, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          question,
          style: const TextStyle(
            color: Color(0xFF1E90FF),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'الحرف المستهدف: $letter',
          style: const TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
} 