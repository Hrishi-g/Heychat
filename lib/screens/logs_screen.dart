import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedFilter = 'ALL';

  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'HTTP':
        return Colors.blue.shade700;
      case 'WS':
        return Colors.purple;
      case 'INFO':
        return Colors.teal;
      default:
        return Colors.grey.shade800;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'ERROR':
        return Icons.error_outline;
      case 'HTTP':
        return Icons.http;
      case 'WS':
        return Icons.swap_calls;
      case 'INFO':
        return Icons.info_outline;
      default:
        return Icons.article_outlined;
    }
  }

  void _copyLogs(BuildContext context) {
    final text = LogService.exportText();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to copy')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _showLogDetailDialog(BuildContext context, LogEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getLevelIcon(entry.level),
                color: _getLevelColor(entry.level)),
            const SizedBox(width: 8),
            Text(entry.level,
                style: TextStyle(color: _getLevelColor(entry.level))),
            const Spacer(),
            Text(entry.formattedTime,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                entry.message,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (entry.details != null && entry.details!.isNotEmpty) ...[
                const Divider(height: 20),
                const Text('Details:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    entry.details!,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.black87),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: AppConfig.host);
    String? testResult;
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_tethering, color: AppConfig.brandDark),
                SizedBox(width: 8),
                Text('Server IP Settings',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the Wi-Fi IP address of the computer running your backend:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Host IP (e.g. 192.168.1.15 or 10.0.2.2)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.computer),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current URL: ${AppConfig.baseUrl}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: testResult!.startsWith('SUCCESS')
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isTesting
                    ? null
                    : () async {
                        setDialogState(() {
                          isTesting = true;
                          testResult = 'Testing connection...';
                        });
                        try {
                          final testHost = controller.text.trim();
                          final url = Uri.parse(
                              'https://heychat-latest.onrender.com/actuator/health');
                          final res = await http.get(url).timeout(
                                const Duration(seconds: 4),
                              );
                          setDialogState(() {
                            isTesting = false;
                            testResult =
                                'SUCCESS: Reached backend! [${res.statusCode}]';
                          });
                        } catch (e) {
                          setDialogState(() {
                            isTesting = false;
                            testResult = 'FAILED: Could not reach host ($e)';
                          });
                        }
                      },
                child: isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('TEST PING'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.brandLime,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final newHost = controller.text.trim();
                  if (newHost.isNotEmpty) {
                    await AppConfig.setHost(newHost);
                    setState(() {});
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Server URL updated to ${AppConfig.baseUrl}')),
                      );
                    }
                  }
                },
                child: const Text('SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Device Logs',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppConfig.brandDark,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering, color: AppConfig.brandDark),
            tooltip: 'Server IP Settings',
            onPressed: () => _showServerConfigDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AppConfig.brandDark),
            tooltip: 'Copy All Logs',
            onPressed: () => _copyLogs(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppConfig.brandDark),
            tooltip: 'Clear Logs',
            onPressed: () {
              LogService.clear();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: ['ALL', 'ERROR', 'HTTP', 'WS', 'INFO'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppConfig.brandLime.withValues(alpha: 0.35),
                    checkmarkColor: Colors.black,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Logs list
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: LogService.logsNotifier,
              builder: (context, allLogs, _) {
                final filteredLogs = _selectedFilter == 'ALL'
                    ? allLogs
                    : allLogs.where((l) => l.level == _selectedFilter).toList();

                if (filteredLogs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No logs captured yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = filteredLogs[index];
                    final color = _getLevelColor(entry.level);

                    return ListTile(
                      dense: true,
                      onTap: () => _showLogDetailDialog(context, entry),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.level,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      title: Text(
                        entry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: entry.details != null
                          ? Text(
                              entry.details!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            )
                          : null,
                      trailing: Text(
                        entry.formattedTime,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
