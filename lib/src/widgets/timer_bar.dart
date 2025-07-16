import 'package:flutter/material.dart';

class TimerBar extends StatelessWidget {
  final int seconds;
  const TimerBar({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 18,
          width: (seconds / 10) * MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: seconds > 3 ? const Color(0xFF1E90FF) : Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              '$seconds ثانية',
              style: const TextStyle(
                color: Color(0xFF222222),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 