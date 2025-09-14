import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class UserActivityLogger {
  static final List<String> _activityBuffer = [];
  static const int _maxBufferSize = 50;
  
  static Future<void> logUserActivity(String activityType, String details, [String value = '']) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '$timestamp|$activityType|$details|$value';
    
    _activityBuffer.add(logEntry);
    
    if (_activityBuffer.length >= _maxBufferSize) {
      await _flushBufferToFile();
    }
    
    await _saveToSharedPreferences(logEntry);
  }
  
  static Future<void> _flushBufferToFile() async {
    if (_activityBuffer.isEmpty) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_activity.log');
      
      final content = _activityBuffer.join('\n') + '\n';
      await file.writeAsString(content, mode: FileMode.append);
      
      _activityBuffer.clear();
    } catch (e) {
      print('Error writing to activity file: $e');
    }
  }
  
  static Future<void> _saveToSharedPreferences(String logEntry) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList('user_activities') ?? [];
    activities.add(logEntry);
    await prefs.setStringList('user_activities', activities.take(1000).toList());
  }

  static Future<File> generatePdfReport() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActivities = prefs.getStringList('user_activities') ?? [];
    final allActivities = [..._activityBuffer, ...savedActivities];

    // Organize activities by type
    final Map<String, List<Map<String, String>>> organizedActivities = {
      'Ads Shown': [],
      'Ads Clicked': [],
      'Ads Watched': [],
      'Calculations': [],
      'Premium Activities': [],
      'Other': [],
    };

    for (final activity in allActivities) {
      final parts = activity.split('|');
      if (parts.length == 4) {
        final timestamp = parts[0];
        final type = parts[1];
        final details = parts[2];
        final value = parts[3];

        final activityMap = {
          'timestamp': DateTime.parse(timestamp).toString(),
          'details': details,
          'value': value
        };

        if (type == 'ad_impression') {
          organizedActivities['Ads Shown']!.add(activityMap);
        } else if (type == 'ad_click') {
          organizedActivities['Ads Clicked']!.add(activityMap);
        } else if (type.contains('ad_watch') || type.contains('reward')) {
          organizedActivities['Ads Watched']!.add(activityMap);
        } else if (type == 'calculation') {
          organizedActivities['Calculations']!.add(activityMap);
        } else if (type.contains('premium')) {
          organizedActivities['Premium Activities']!.add(activityMap);
        } else {
          organizedActivities['Other']!.add(activityMap);
        }
      }
    }

    // Create PDF
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: 'QuickCalc Activity Report'),
              pw.SizedBox(height: 20),
              
              for (final category in organizedActivities.entries)
                if (category.value.isNotEmpty) ...[
                  pw.Header(level: 1, text: category.key),
                  pw.ListView.builder(
                    itemCount: category.value.length,
                    itemBuilder: (context, index) {
                      final activity = category.value[index];
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          '• ${activity['timestamp']!.substring(0, 16)} - ${activity['details']} ${activity['value']!.isNotEmpty ? '(${activity['value']})' : ''}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                  pw.SizedBox(height: 16),
                ]
            ],
          );
        },
      ),
    );

    // Save PDF to file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/quickcalc_activity_report.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }

  static Future<void> sharePdfReport() async {
    try {
      final file = await generatePdfReport();
      await Share.shareXFiles([XFile(file.path)],
        text: 'My QuickCalc Activity Report',
        subject: 'QuickCalc Activity PDF Report'
      );
    } catch (e) {
      print('Error sharing PDF report: $e');
      rethrow;
    }
  }

  static Future<void> clearUserActivityData() async {
    _activityBuffer.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_activities');
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_activity.log');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing activity file: $e');
    }
  }
}
