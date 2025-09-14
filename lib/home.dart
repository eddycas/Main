// ADD THESE IMPORTS
import 'user_activity_logger.dart';
import 'developer_analytics.dart';
import 'package:share_plus/share_plus.dart';

// IN THE CalculatorHomeState CLASS, ADD THESE METHODS:
void _exportUserActivity() async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing your activity export...')),
    );
    
    await UserActivityLogger.shareUserActivityFile();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error exporting: $e')),
    );
  }
}

void _clearUserActivity() async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear Activity Data'),
      content: const Text('This will delete all your activity history. This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            UserActivityLogger.clearUserActivityData();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Activity data cleared')),
            );
          },
          child: const Text('Clear', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

// UPDATE THE AppBar actions to include export:
AppBar(
  title: const Text("QuickCalc"),
  actions: [
    // Export button - NEW
    IconButton(
      icon: const Icon(Icons.history),
      onPressed: _exportUserActivity,
      tooltip: 'Export my activity',
    ),
    IconButton(
      icon: const Icon(Icons.color_lens),
      onPressed: widget.toggleTheme,
      tooltip: 'Toggle theme',
    ),
    IconButton(
      icon: const Icon(Icons.star),
      onPressed: () => setState(() => rightPanelOpen = !rightPanelOpen),
      tooltip: 'Premium',
    ),
    // Settings menu for clear data - NEW
    PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'clear_activity') {
          _clearUserActivity();
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'clear_activity',
          child: Text('Clear My Activity Data'),
        ),
      ],
    ),
  ],
),
