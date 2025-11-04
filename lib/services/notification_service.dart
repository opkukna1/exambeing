import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; // TimeOfDay ke liye

class NotificationService {
  // Singleton pattern (taaki poore app mein ek hi instance rahe)
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() {
    return _instance;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Service ko initialize (shuru) karna
  Future<void> initialize() async {
    // 1. Timezone database ko initialize karo
    tz.initializeTimeZones();
    // Apne local time zone ko set karo (India ke liye)
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (e) {
      debugPrint("Could not set local location: $e");
      // Fallback ya default time zone
      tz.setLocalLocation(tz.local);
    }


    // 2. Android ke liye settings
    // Aapke project mein @mipmap/launcher_icon hai (AndroidManifest.xml ke hisaab se)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon'); 

    // 3. iOS ke liye settings (agar zaroori ho)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Dono ko initialize karo
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 5. Notification channel banao (Android 8+ ke liye zaroori)
     await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  // Android 13+ par notification permission maangna
  Future<void> requestNotificationPermissions() async {
    final plugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        
    await plugin?.requestNotificationsPermission();
  }

  // Notification channel ki details
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'timetable_channel', // id
    'Timetable Notifications', // title
    description: 'Channel for study timetable reminders.',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  // Helper function: Agla din (jaise Monday) kab aayega
  tz.TZDateTime _nextInstanceOfDay(int day, TimeOfDay time) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      tz.TZDateTime.now(tz.local).year,
      tz.TZDateTime.now(tz.local).month,
      tz.TZDateTime.now(tz.local).day,
      time.hour,
      time.minute,
    );

    // Agar aaj ka time nikal gaya hai, to agle din se shuru karo
    // Ya agar aaj woh din nahi hai
    while (scheduledDate.weekday != day || scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Day of the week mapping (sqflite se match):
    // 1 = Monday, 2 = Tuesday, ..., 7 = Sunday (DateTime.monday, etc.)
    
    return scheduledDate;
  }

  // Asli function: Hafte mein repeat hone waala notification schedule karna
  Future<void> scheduleWeeklyNotification({
    required int id, // Har notification ki unique ID (taaki hum use cancel kar sakein)
    required String title, // Subject Name
    required String body, // Time (From - To)
    required int day, // Din (1-7, Monday-Sunday)
    required TimeOfDay time, // Kis time par
  }) async {
    
    final tz.TZDateTime scheduledDateTime = _nextInstanceOfDay(day, time);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDateTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/launcher_icon', // Notification icon
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Har hafte repeat karo
    );
  }

  // Notification ko ID se cancel karna
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
