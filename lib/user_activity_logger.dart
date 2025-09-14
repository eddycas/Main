import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class UserActivityLogger {
  static final List<String> _activityBuffer = [];
  static const int _maxBufferSize = 50;
  
  // Log user activity (calculations, ads they saw, etc.)
  static Future<void> logUserActivity(String activityType, String details, [String value = '']) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '$timestamp|$activityType|$details|$value';
    
    _activityBuffer.add(logEntry);
    
    // Write to buffer and periodically save to file
    if (_activityBuffer.length >= _maxBufferSize) {
      await _flushBufferToFile();
    }
    
    // Also save to SharedPreferences for immediate persistence
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
    // Keep only last 1000 activities to prevent storage bloat
    await prefs.setStringList('user_activities', activities.take(1000).toList());
  }
  
  // Generate downloadable file for USER
  static Future<File> generateUserActivityFile() async {
    // Get all activities from buffer and persisted storage
    final prefs = await SharedPreferences.getInstance();
    final savedActivities = prefs.getStringList('user_activities') ?? [];
    
    final allActivities = [..._activityBuffer, ...savedActivities];
    
    // Create CSV content
    final csvContent = StringBuffer();
    csvContent.writeln('Timestamp,Activity Type,Details,Value');
    
    for (final activity in allActivities) {
      final parts = activity.split('|');
      if (parts.length == 4) {
        csvContent.writeln('"${parts[0]}","${parts[1]}","${parts[2]}","${parts[3]}"');
      }
    }
    
    // Save to temporary file for sharing
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/my_quickcalc_activity.csv');
    await tempFile.writeAsString(csvContent.toString());
    
    return tempFile;
  }
  
  // Let user share/download their file
  static Future<void> shareUserActivityFile() async {
    try {
      final file = await generateUserActivityFile();
      await Share.shareFiles([file.path], 
        text: 'My QuickCalc Activity Log',
        subject: 'QuickCalc Activity Export'
      );
    } catch (e) {
      print('Error sharing activity file: $e');
    }
  }
  
  // Clear user activity data
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
