import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/google_drive_service.dart';
import 'home_screen.dart';

class RestoreBackupScreen extends StatefulWidget {
  final String phone;

  const RestoreBackupScreen({
    super.key,
    required this.phone,
  });

  @override
  State<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends State<RestoreBackupScreen> {
  final _driveService = GoogleDriveService.instance;
  GoogleDriveBackupInfo? _backupInfo;
  bool _isChecking = true;
  bool _isRestoring = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _checkForBackup();
  }

  Future<void> _checkForBackup() async {
    setState(() {
      _isChecking = true;
      _statusText = 'Searching Google Drive for backups...';
    });

    try {
      // Try silent or interactive sign in to check Google Drive
      final user =
          await _driveService.signInSilently() ?? await _driveService.signIn();
      if (user != null) {
        final info = await _driveService.getBackupMetadata();
        if (mounted) {
          setState(() {
            _backupInfo = info;
            _isChecking = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isRestoring = true;
      _statusText = 'Downloading and restoring chat backup...';
    });

    try {
      final success = await _driveService.restoreBackup();
      if (!mounted) return;

      if (success) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        if (authProvider.currentMblNo != null) {
          await chatProvider.init(authProvider.currentMblNo!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chats and media restored successfully!'),
            backgroundColor: Color(0xFF25D366),
          ),
        );
        _proceedToHome();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Restore failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _proceedToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final googleAccount = _driveService.currentUser;

    return Scaffold(
      backgroundColor: AppConfig.lightBg,
      appBar: AppBar(
        title: const Text(
          'Restore Backup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppConfig.brandDark,
        elevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // Header Cloud Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_download_rounded,
                  size: 48,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Restore your chat history',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.brandDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'Restore your messages and media from Google Drive so you don\'t lose your chat history.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Status / Backup Info Card
              if (_isChecking)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: AppConfig.brandDark,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText ?? 'Checking for Google Drive backup...',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppConfig.brandDark,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_backupInfo != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.5),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF25D366), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Backup Found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppConfig.brandDark,
                                  ),
                                ),
                                if (googleAccount != null)
                                  Text(
                                    googleAccount.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${DateFormat('MMM dd, yyyy · hh:mm a').format(_backupInfo!.modifiedTime)}',
                            style: const TextStyle(
                                fontSize: 13, color: AppConfig.brandDark),
                          ),
                          Text(
                            'Size: ${_formatBytes(_backupInfo!.sizeInBytes)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          color: Colors.grey.shade400, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'No cloud backup found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.brandDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We couldn\'t find any previous backup associated with your Google Account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Action Buttons
              if (_isRestoring)
                const Column(
                  children: [
                    CircularProgressIndicator(color: AppConfig.brandDark),
                    SizedBox(height: 12),
                    Text('Restoring your chat history...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                )
              else if (_backupInfo != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _handleRestore,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text(
                      'RESTORE CHATS',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: _proceedToHome,
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _checkForBackup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.brandDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'CHECK GOOGLE DRIVE',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: _proceedToHome,
                    child: const Text(
                      'SKIP & CONTINUE TO APP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
