import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

void showServerSettingsDialog(BuildContext context, {VoidCallback? onSaved}) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your computer\'s Wi-Fi IP (or 10.0.2.2 for emulator, 127.0.0.1 for adb reverse):',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Computer IP (e.g. 192.168.1.15)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Target: ${AppConfig.baseUrl}',
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
                        final res = await http
                            .get(url)
                            .timeout(const Duration(seconds: 4));
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
                  onSaved?.call();
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Server URL updated to ${AppConfig.baseUrl}'),
                      ),
                    );
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    ),
  );
}
