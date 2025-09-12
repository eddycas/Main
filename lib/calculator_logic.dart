import 'package:math_expressions/math_expressions.dart';
import 'calculator_home.dart';

class CalculatorLogic {
  static void handleButton(String btn, CalculatorHomeState state) {
    if (btn == '=') {
      try {
        Parser p = Parser();
        Expression exp = p.parse(
            state.expression.replaceAll('×', '*').replaceAll('÷', '/'));
        ContextModel cm = ContextModel();
        double eval = exp.evaluate(EvaluationType.REAL, cm);

        state.result = eval % 1 == 0 ? eval.toInt().toString() : eval.toString();
        state.history.insert(0, "${state.expression} = ${state.result}");
      } catch (_) {
        state.result = "Error";
      }
    } else if (btn == 'C') {
      state.expression = "";
      state.result = "0";
    } else if (btn == 'DEL') {
      if (state.expression.isNotEmpty) {
        state.expression = state.expression.substring(0, state.expression.length - 1);
      }
      if (state.expression.isEmpty) state.result = "0";
    } else if (btn == 'M+') {
      state.memory = double.tryParse(state.result) ?? 0;
    } else if (btn == 'MR') {
      state.expression += state.memory.toString();
    } else {
      state.expression += btn;
    }
  }
}
