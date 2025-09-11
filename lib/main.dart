import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key});

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Calculator",
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: CalculatorPage(toggleTheme: _toggleTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CalculatorPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const CalculatorPage({super.key, required this.toggleTheme});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expression = "";
  String _result = "0";
  final List<String> _history = [];
  double _memory = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.clear();
      _history.addAll(prefs.getStringList('calc_history') ?? []);
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('calc_history', _history);
  }

  void _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('calc_history');
    setState(() {
      _history.clear();
    });
  }

  void _onPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == "C") {
        _expression = "";
        _result = "0";
      } else if (value == "=") {
        _calculate();
      } else {
        _expression += value;
      }
    });
  }

  void _calculate() {
    try {
      Parser p = Parser();
      Expression exp = p.parse(_expression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      setState(() {
        _result = eval.toString();
        _history.insert(0, "$_expression = $_result");
        if (_history.length > 10) _history.removeLast();
      });
      _saveHistory();
      _expression = "";
    } catch (e) {
      setState(() {
        _result = "Error";
      });
    }
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _result));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Result copied to clipboard")),
    );
  }

  void _memoryAction(String action) {
    double current = double.tryParse(_result) ?? 0;
    setState(() {
      if (action == "M+") {
        _memory += current;
      } else if (action == "M-") {
        _memory -= current;
      } else if (action == "MR") {
        _expression += _memory.toString();
      } else if (action == "MC") {
        _memory = 0;
      }
    });
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text("Calculation History",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No history yet"),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_history[index]),
                      );
                    },
                  ),
                ),
              TextButton(
                onPressed: _clearHistory,
                child: const Text("Clear History"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton(String value,
      {Color? color, VoidCallback? onTap, double flex = 1}) {
    return Expanded(
      flex: flex.toInt(),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: onTap ?? () => _onPressed(value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color ?? Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(children: [
          _buildButton("7"),
          _buildButton("8"),
          _buildButton("9"),
          _buildButton("/", color: Colors.orange),
        ]),
        Row(children: [
          _buildButton("4"),
          _buildButton("5"),
          _buildButton("6"),
          _buildButton("*", color: Colors.orange),
        ]),
        Row(children: [
          _buildButton("1"),
          _buildButton("2"),
          _buildButton("3"),
          _buildButton("-", color: Colors.orange),
        ]),
        Row(children: [
          _buildButton("0"),
          _buildButton("."),
          _buildButton("C", color: Colors.red),
          _buildButton("+", color: Colors.orange),
        ]),
        Row(children: [
          _buildButton("=", color: Colors.green, flex: 2),
        ]),
        Row(children: [
          _buildButton("M+", onTap: () => _memoryAction("M+")),
          _buildButton("M-", onTap: () => _memoryAction("M-")),
          _buildButton("MR", onTap: () => _memoryAction("MR")),
          _buildButton("MC", onTap: () => _memoryAction("MC")),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calculator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Center(
                  child: Text("Scientific Tools",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              ListTile(
                title: const Text("sin()"),
                onTap: () => setState(() => _expression += "sin("),
              ),
              ListTile(
                title: const Text("cos()"),
                onTap: () => setState(() => _expression += "cos("),
              ),
              ListTile(
                title: const Text("tan()"),
                onTap: () => setState(() => _expression += "tan("),
              ),
              ListTile(
                title: const Text("log()"),
                onTap: () => setState(() => _expression += "log("),
              ),
              ListTile(
                title: const Text("^ (power)"),
                onTap: () => setState(() => _expression += "^"),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: _copyResult,
              child: Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_expression,
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.right),
                    const SizedBox(height: 10),
                    Text(_result,
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right),
                  ],
                ),
              ),
            ),
          ),
          _buildKeypad(),
        ],
      ),
    );
  }
}
