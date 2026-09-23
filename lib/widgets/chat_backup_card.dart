import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/google_drive_service.dart';

class ChatBackupCard extends StatefulWidget {
  const ChatBackupCard({super.key});

  @override
  State<ChatBackupCard> createState() => _ChatBackupCardState();
}

class _ChatBackupCardState extends State<ChatBackupCard> {
  final _driveService = GoogleDriveService.instance;
  GoogleDriveBackupInfo? _backupInfo;
  bool _isLoadingInfo = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkBackupInfo();
  }

  Future<void> _checkBackupInfo() async {
    setState(() => _isLoadingInfo = true);
    try {
      final info = await _driveService.getBackupMetadata();
      if (mounted) {
        setState(() {
          _backupInfo = info;
          _isLoadingInfo = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingInfo = false);
      }
    }
  }

  Future<void> _handleBackup() async {
    setState(() {
      _isBackingUp = true;
      _statusMessage = null;
    });

    try {
      final success = await _driveService.uploadBackup();
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Chat database successfully backed up to Google Drive!'),
            backgroundColor: Color(0xFF25D366),
          ),
        );
        await _checkBackupInfo();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Backup failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Chat Backup?'),
        content: const Text(
          'This will replace your current local chats with the backup stored in your Google Drive. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.brandDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRestoring = true;
      _statusMessage = null;
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
            content: Text('Chat backup restored successfully!'),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Restore failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final googleUser = _driveService.currentUser;

    return Container(
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.cloud_upload_outlined,
                    color: Colors.blue.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Drive Chat Backup',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.brandDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      googleUser != null
                          ? 'Account: ${googleUser.email}'
                          : 'Free cloud backup for your messages',
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
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Backup Info Status
          if (_isLoadingInfo)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Checking Google Drive backup...',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )
          else if (_backupInfo != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF25D366), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last Backup: ${DateFormat('MMM dd, yyyy · hh:mm a').format(_backupInfo!.modifiedTime)} (${_formatBytes(_backupInfo!.sizeInBytes)})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppConfig.brandDark,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No cloud backup found on Google Drive yet.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons: Backup Now & Restore
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (_isBackingUp || _isRestoring) ? null : _handleBackup,
                  icon: _isBackingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.backup_outlined, size: 18),
                  label: Text(_isBackingUp ? 'Backing Up...' : 'Back Up Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.brandDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (_isBackingUp || _isRestoring || _backupInfo == null)
                          ? null
                          : _handleRestore,
                  icon: _isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppConfig.brandDark,
                          ),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 18),
                  label: Text(_isRestoring ? 'Restoring...' : 'Restore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConfig.brandDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppConfig.brandDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
