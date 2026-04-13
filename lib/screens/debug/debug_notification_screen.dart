import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/battery_optimization.dart';
import 'package:timezone/timezone.dart' as tz;

class DebugNotificationScreen extends StatefulWidget {
  const DebugNotificationScreen({super.key});

  @override
  State<DebugNotificationScreen> createState() => _DebugNotificationScreenState();
}

class _DebugNotificationScreenState extends State<DebugNotificationScreen> {
  bool _isBatteryIgnored = false;
  bool _canExactAlarm = false;
  List<Map<String, dynamic>> _mirrorLog = [];
  Map<int, String> _questionMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    
    final battery = await isIgnoringBatteryOptimizations();
    
    // Check exact alarm status directly from the plugin implementation
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;

    final mirror = await NotificationService.instance.getMirrorLog();
    
    // Load question texts so the IDs in the log make sense
    final allQuestions = await DatabaseHelper.instance.getAllQuestions();
    final qMap = {for (var q in allQuestions) q.id!: q.question};

    if (mounted) {
      setState(() {
        _isBatteryIgnored = battery;
        _canExactAlarm = exact;
        _mirrorLog = mirror;
        _questionMap = qMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debugger'),
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('System Permissions'),
              _buildStatusSection(),
              const SizedBox(height: 24),
              _buildSectionHeader('Mirror Log (App Logic View)'),
              _buildMirrorList(theme),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await NotificationService.instance.sendTestNotification();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test alarm set for 1 second from now! 🔔')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Fire Immediate Test Notification'),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1, color: Colors.grey)),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Column(
        children: [
          _StatusRow(label: 'Battery Opt. Whitelisted', value: _isBatteryIgnored),
          const Divider(height: 1),
          _StatusRow(label: 'Exact Alarm Allowed', value: _canExactAlarm),
        ],
      ),
    );
  }

  Widget _buildMirrorList(ThemeData theme) {
    if (_mirrorLog.isEmpty) {
      return const Text('No mirror history found.');
    }
    return Column(
      children: _mirrorLog.map((item) {
        final time = DateTime.parse(item['time']).toLocal();
        final qId = item['id'] as int;
        final qText = _questionMap[qId] ?? 'Deleted Question';
        final isFuture = time.isAfter(DateTime.now());

        return Card(
          child: ListTile(
            dense: true,
            leading: Icon(isFuture ? Icons.event_available : Icons.event_busy, 
              color: isFuture ? theme.colorScheme.primary : Colors.grey),
            title: Text(DateFormat('EEE, MMM dd — HH:mm').format(time)),
            subtitle: Text('Q#$qId: $qText'),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool value;
  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Icon(
        value ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: value ? Colors.green : Colors.red,
      ),
    );
  }
}
