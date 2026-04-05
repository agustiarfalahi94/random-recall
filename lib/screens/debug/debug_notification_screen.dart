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
  List<PendingNotificationRequest> _pendingRequests = [];
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
    final pending = await NotificationService.instance.getPendingRequests();
    
    // Load question texts so the IDs in the log make sense
    final allQuestions = await DatabaseHelper.instance.getAllQuestions();
    final qMap = {for (var q in allQuestions) q.id!: q.question};

    if (mounted) {
      setState(() {
        _isBatteryIgnored = battery;
        _canExactAlarm = exact;
        _mirrorLog = mirror;
        _pendingRequests = pending;
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
              _buildSectionHeader('System Alarms (Android View)'),
              _buildPendingList(theme),
              const SizedBox(height: 24),
              _buildSectionHeader('Mirror Log (App Logic View)'),
              _buildMirrorList(theme),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => NotificationService.instance.sendTestNotification(),
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

  Widget _buildPendingList(ThemeData theme) {
    if (_pendingRequests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No active alarms in the OS.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      );
    }
    return Column(
      children: _pendingRequests.map((req) => Card(
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.alarm, size: 20),
          title: Text(req.title ?? 'No Title'),
          subtitle: Text('Android ID: ${req.id}'),
        ),
      )).toList(),
    );
  }

  Widget _buildMirrorList(ThemeData theme) {
    if (_mirrorLog.isEmpty) {
      return const Text('No mirror history found.');
    }
    return Column(
      children: _mirrorLog.map((item) {
        final time = DateTime.parse(item['time']);
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
