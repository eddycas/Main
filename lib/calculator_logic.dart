import 'dart:math';
import 'package:math_expressions/math_expressions.dart';
import 'home.dart';
import 'user_activity_logger.dart';
import 'developer_analytics.dart';

class CalculatorLogic {
  static void handleButton(String btn, CalculatorHomeState state) {
    if (btn == '=') {
      try {
        if (state.expression.isEmpty) return;
        String exp = state.expression.replaceAll('×', '*').replaceAll('÷', '/');
        Parser p = Parser();
        Expression expression = p.parse(exp);
        ContextModel cm = ContextModel();
        double eval = expression.evaluate(EvaluationType.REAL, cm);
        state.result = eval % 1 == 0 ? eval.toInt().toString() : eval.toString();

        if (state.lastCalculationSuccessful) {
          state.history.insert(0, "${state.expression} = ${state.result}");
          if (state.history.length > 10) state.history.removeLast();
        }

        UserActivityLogger.logUserActivity('calculation', state.expression, state.result);
        DeveloperAnalytics.trackCalculationStats(_getOperationType(state.expression), _getDigitCount(state.expression));

        state.expression = "";
        state.lastCalculationSuccessful = true;
        state.saveHistory();
      } catch (_) {
        state.result = "Error";
        state.lastCalculationSuccessful = false;
        UserActivityLogger.logUserActivity('error', 'calculation', state.expression);
      }
    } else if (btn == 'C') {
      state.expression = "";
      state.result = "0";
      UserActivityLogger.logUserActivity('action', 'clear', '');
    } else if (btn == 'DEL') {
      if (state.expression.isNotEmpty) {
        state.expression = state.expression.substring(0, state.expression.length - 1);
      }
      if (state.expression.isEmpty) state.result = "0";
      UserActivityLogger.logUserActivity('action', 'delete', '');
    } else if (btn == 'M+') {
      state.memory = double.tryParse(state.result) ?? 0;
      UserActivityLogger.logUserActivity('memory', 'add', state.result);
    } else if (btn == 'M-') {
      state.memory -= double.tryParse(state.result) ?? 0;
      UserActivityLogger.logUserActivity('memory', 'subtract', state.result);
    } else if (btn == 'MR') {
      state.expression += state.memory.toString();
      UserActivityLogger.logUserActivity('memory', 'recall', state.memory.toString());
    } else if (btn == 'MC') {
      state.memory = 0;
      UserActivityLogger.logUserActivity('memory', 'clear', '');
    } else {
      state.expression += btn;
      state.result = state.expression;
    }
  }

  static String _getOperationType(String expression) {
    if (expression.contains('+')) return 'addition';
    if (expression.contains('-')) return 'subtraction';
    if (expression.contains('*') || expression.contains('×')) return 'multiplication';
    if (expression.contains('/') || expression.contains('÷')) return 'division';
    return 'other';
  }

  static int _getDigitCount(String expression) {
    final digitsOnly = expression.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length;
  }

  static double calculateScientific(String function, double value) {
    switch (function) {
      case 'SIN':
        return sin(value * pi / 180);
      case 'COS':
        return cos(value * pi / 180);
      case 'TAN':
        return tan(value * pi / 180);
      case 'LOG2':
        return log(value) / log(2);
      case 'LOG10':
        return log(value) / log(10);
      case 'LOG25':
        return log(value) / log(25);
      default:
        return value;
    }
  }
}
