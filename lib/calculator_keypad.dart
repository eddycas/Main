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

    return Container(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: buttons.map((row) {
          return Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((btn) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(3.0),
                    child: Material(
                      shape: const CircleBorder(),
                      elevation: 5,
                      color: getButtonColor(btn),
                      child: InkWell(
                        onTap: () => onPressed(btn),
                        customBorder: const CircleBorder(),
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            btn,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: getTextColor(btn),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
