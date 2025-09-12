import 'package:flutter/material.dart';

class CalculatorKeypad extends StatelessWidget {
  final void Function(String) onPressed;
  const CalculatorKeypad({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
      ['C', 'DEL', 'M+', 'MR']
    ];

    return Column(
      children: buttons.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((btn) {
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: ElevatedButton(
                onPressed: () => onPressed(btn),
                child: Text(btn),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
