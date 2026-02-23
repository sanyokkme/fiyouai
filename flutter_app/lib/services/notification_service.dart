import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    print("🔔 [NotificationService] Start Init...");

    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final bool? initialized = await notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print("🔔 Notification clicked payload: ${response.payload}");
      },
    );

    print("🔔 [NotificationService] Initialized: $initialized");

    // Automatically apply schedules on init based on saved preferences
    await updateSchedules();
  }

  // Define fixed IDs for different notification types
  static const int _waterId1 = 101;
  static const int _waterId2 = 102;
  static const int _waterId3 = 103;
  static const int _waterId4 = 104;

  static const int _mealBreakfastId = 201;
  static const int _mealLunchId = 202;
  static const int _mealDinnerId = 203;

  static const int _vitaminId = 301;
  static const int _exerciseId = 401;

  Future<void> updateSchedules() async {
    final prefs = await SharedPreferences.getInstance();

    final bool water = prefs.getBool('notifications_water') ?? true;
    final bool meal = prefs.getBool('notifications_meal') ?? true;
    final bool vitamin = prefs.getBool('notifications_vitamin') ?? true;
    final bool exercise = prefs.getBool('notifications_exercise') ?? false;

    // Water (Reminders multiple times a day)
    if (water) {
      await scheduleDailyNotification(
        id: _waterId1,
        title: 'Час пити воду!',
        body: 'Склянка води додасть енергії.',
        hour: 9,
        minute: 30,
      );
      await scheduleDailyNotification(
        id: _waterId2,
        title: 'Водний баланс',
        body: 'Не забувай пити воду протягом дня.',
        hour: 13,
        minute: 0,
      );
      await scheduleDailyNotification(
        id: _waterId3,
        title: 'Час пити воду!',
        body: 'Твій організм потребує зволоження.',
        hour: 16,
        minute: 30,
      );
      await scheduleDailyNotification(
        id: _waterId4,
        title: 'Водний баланс',
        body: 'Випий ще трохи води до кінця дня.',
        hour: 20,
        minute: 0,
      );
    } else {
      await _cancel([_waterId1, _waterId2, _waterId3, _waterId4]);
    }

    // Meals
    if (meal) {
      await scheduleDailyNotification(
        id: _mealBreakfastId,
        title: 'Сніданок',
        body: 'Час смачно і корисно поснідати!',
        hour: 8,
        minute: 30,
      );
      await scheduleDailyNotification(
        id: _mealLunchId,
        title: 'Обід',
        body: 'Час підкріпитися і відновити сили.',
        hour: 13,
        minute: 30,
      );
      await scheduleDailyNotification(
        id: _mealDinnerId,
        title: 'Вечеря',
        body: 'Легка вечеря — запорука гарного сну.',
        hour: 19,
        minute: 0,
      );
    } else {
      await _cancel([_mealBreakfastId, _mealLunchId, _mealDinnerId]);
    }

    // Vitamins
    if (vitamin) {
      await scheduleDailyNotification(
        id: _vitaminId,
        title: 'Вітаміни',
        body: 'Не забудь прийняти свої щоденні вітаміни.',
        hour: 10,
        minute: 0,
      );
    } else {
      await _cancel([_vitaminId]);
    }

    // Exercise
    if (exercise) {
      await scheduleDailyNotification(
        id: _exerciseId,
        title: 'Тренування',
        body: 'Час розім\'ятися! 15 хвилин активності покращать твій настрій.',
        hour: 18,
        minute: 0,
      );
    } else {
      await _cancel([_exerciseId]);
    }
  }

  Future<void> _cancel(List<int> ids) async {
    for (int id in ids) {
      await notificationsPlugin.cancel(id);
    }
  }

  Future<void> requestPermissions() async {
    print("🔔 [NotificationService] Requesting Permissions...");

    if (Platform.isIOS) {
      final bool? result = await notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      print("🔔 [NotificationService] iOS Permission Result: $result");
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? granted = await androidImplementation
          ?.requestNotificationsPermission();
      print("🔔 [NotificationService] Android Permission Result: $granted");
    }
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    print("🔔 [NotificationService] Showing Instant Notification");
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      iOS: iosDetails,
      android: AndroidNotificationDetails('test_ch', 'Test'),
    );

    await notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final scheduledTime = _nextInstanceOfTime(hour, minute);
      print("🔔 Scheduled: $title at $scheduledTime");

      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails('vitamin_ch', 'Vitamins'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print("🔔 Error scheduling notification: $e");
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
