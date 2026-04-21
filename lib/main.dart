import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

part 'main.g.dart';

@HiveType(typeId: 0)
class WaterRecord {
  @HiveField(0)
  final int amount;
  @HiveField(1)
  final DateTime time;
  WaterRecord(this.amount, this.time);
}

@HiveType(typeId: 1)
class UserSettings {
  @HiveField(0)
  int dailyGoal;
  @HiveField(1)
  int reminderInterval;
  UserSettings({this.dailyGoal = 2000, this.reminderInterval = 2});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(WaterRecordAdapter());
  Hive.registerAdapter(UserSettingsAdapter());
  await Hive.openBox<WaterRecord>('records');
  await Hive.openBox<UserSettings>('settings');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '喝水记录',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<WaterRecord> recordsBox;
  late Box<UserSettings> settingsBox;
  late UserSettings settings;
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<WaterRecord>('records');
    settingsBox = Hive.box<UserSettings>('settings');
    settings = settingsBox.get('settings') ?? UserSettings();
    _initNotifications();
  }

  void _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await notificationsPlugin.initialize(initSettings);
  }

  int get _todayTotal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return recordsBox.values
        .where((r) => r.time.isAfter(today))
        .fold(0, (sum, r) => sum + r.amount);
  }

  void _addWater(int amount) {
    recordsBox.add(WaterRecord(amount, DateTime.now()));
    setState(() {});
  }

  void _showTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'water_reminder',
      '喝水提醒',
      channelDescription: '定时提醒喝水',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await notificationsPlugin.show(0, '该喝水啦 💧', '保持好习惯', details);
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage(settings: settings)),
    );
    if (result != null) setState(() => settings = result);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_todayTotal / settings.dailyGoal).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('喝水记录'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 22,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_todayTotal', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      Text('/ ${settings.dailyGoal} ml', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
                textStyle: const TextStyle(fontSize: 26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _addWater(250),
              child: const Text('喝了一杯 (250ml)'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _showTestNotification, child: const Text('测试提醒')),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    recordsBox.values.where((r) => r.time.isAfter(today)).forEach((r) => r.delete());
                    setState(() {});
                  },
                  child: const Text('重置今日'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final UserSettings settings;
  const SettingsPage({super.key, required this.settings});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: widget.settings.dailyGoal.toString());
  }

  void _saveSettings() {
    widget.settings.dailyGoal = (int.tryParse(_goalController.text) ?? 2000).clamp(500, 5000);
    Hive.box<UserSettings>('settings').put('settings', widget.settings);
    Navigator.pop(context, widget.settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '每日饮水目标 (ml)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _saveSettings, child: const Text('保存设置')),
          ],
        ),
      ),
    );
  }
}