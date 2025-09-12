import 'package:math_expressions/math_expressions.dart';
import 'calculator_home.dart';

class CalculatorLogic {
  static void handleButton(String btn, _CalculatorHomeState state) {
    if (btn == '=') {
      try {
        Parser p = Parser();
        Expression exp = p.parse(
            state._expression.replaceAll('×', '*').replaceAll('÷', '/'));
        ContextModel cm = ContextModel();
        double eval = exp.evaluate(EvaluationType.REAL, cm);

        String formattedResult =
            eval % 1 == 0 ? eval.toInt().toString() : eval.toString();

        state._result = formattedResult;
        state._history.insert(0, "${state._expression} = $formattedResult");
      } catch (_) {
        state._result = "Error";
      }
    } else if (btn == 'C') {
      state._expression = "";
      state._result = "0";
    } else if (btn == 'DEL') {
      if (state._expression.isNotEmpty) {
        state._expression =
            state._expression.substring(0, state._expression.length - 1);
      }
      if (state._expression.isEmpty) state._result = "0";
    } else if (btn == 'M+') {
      state._memory = double.tryParse(state._result) ?? 0;
    } else if (btn == 'MR') {
      state._expression += state._memory.toString();
    } else {
      state._expression += btn;
    }
  }
}
