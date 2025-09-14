import 'package:flutter/material.dart';

class CalculatorKeypad extends StatelessWidget {
  final void Function(String) onPressed;
  final ThemeMode themeMode;

  const CalculatorKeypad({super.key, required this.onPressed, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
      ['C', 'DEL']
    ];

    Color getButtonColor(String btn) => themeMode == ThemeMode.light ? Colors.white : Colors.grey[850]!;

    Color getTextColor(String btn) {
      if (btn == 'DEL') return Colors.red;
      if (['+', '-', '×', '÷', '='].contains(btn)) return Colors.blue;
      return themeMode == ThemeMode.light ? Colors.black : Colors.white;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons.map((row) {
        return Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((btn) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ElevatedButton(
                    onPressed: () => onPressed(btn),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: getButtonColor(btn),
                      foregroundColor: getTextColor(btn),
                      shadowColor: Colors.black54,
                      elevation: 5,
                      padding: const EdgeInsets.all(26),
                    ),
                    child: Text(btn, style: TextStyle(fontSize: 32, color: getTextColor(btn))),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
