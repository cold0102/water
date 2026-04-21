import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

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
  int _todayTotal = 0;
  int _dailyGoal = 2000;
  List<Map<String, dynamic>> _todayRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('lastDate') ?? '';
    
    if (savedDate != today) {
      _todayTotal = 0;
      _todayRecords = [];
      await prefs.setString('lastDate', today);
    } else {
      _todayTotal = prefs.getInt('todayTotal') ?? 0;
      final recordsJson = prefs.getString('todayRecords') ?? '[]';
      _todayRecords = List<Map<String, dynamic>>.from(jsonDecode(recordsJson));
    }
    
    _dailyGoal = prefs.getInt('dailyGoal') ?? 2000;
    setState(() {});
  }

  Future<void> _addWater(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    _todayTotal += amount;
    _todayRecords.add({'amount': amount, 'time': TimeOfDay.now().format(context)});
    
    await prefs.setInt('todayTotal', _todayTotal);
    await prefs.setString('todayRecords', jsonEncode(_todayRecords));
    setState(() {});
  }

  Future<void> _resetToday() async {
    final prefs = await SharedPreferences.getInstance();
    _todayTotal = 0;
    _todayRecords = [];
    await prefs.setInt('todayTotal', 0);
    await prefs.setString('todayRecords', jsonEncode([]));
    setState(() {});
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage(currentGoal: _dailyGoal)),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      _dailyGoal = result;
      await prefs.setInt('dailyGoal', _dailyGoal);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_todayTotal / _dailyGoal).clamp(0.0, 1.0);
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
                      Text('/ $_dailyGoal ml', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
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
            ElevatedButton(onPressed: _resetToday, child: const Text('重置今日')),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final int currentGoal;
  const SettingsPage({super.key, required this.currentGoal});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: widget.currentGoal.toString());
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
            ElevatedButton(
              onPressed: () {
                final newGoal = int.tryParse(_goalController.text) ?? 2000;
                Navigator.pop(context, newGoal.clamp(500, 5000));
              },
              child: const Text('保存设置'),
            ),
          ],
        ),
      ),
    );
  }
}
