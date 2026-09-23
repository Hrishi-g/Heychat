import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/auth_service.dart';
import '../services/avatar_cache_service.dart';
import '../widgets/cached_avatar.dart';
import 'chat_detail_screen.dart';
import 'full_screen_image_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _imageChannel =
      MethodChannel('com.example.my_first_app/image_picker');

  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;
  UserModel? _userProfile;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  String? _normalizeGender(String? val) {
    if (val == null) return null;
    final upper = val.trim().toUpperCase();
    if (upper == 'MALE') return 'MALE';
    if (upper == 'FEMALE') return 'FEMALE';
    if (upper == 'OTHER') return 'OTHER';
    return null;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _authService.getProfile();
      if (!mounted) return;

      if (profile != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.updateProfileData(
          name: profile.name,
          imgUrl: profile.imgUrl,
        );
        setState(() {
          _userProfile = profile;
          _nameController.text = profile.name;
          _dobController.text = profile.dob ?? '';
          _selectedGender = _normalizeGender(profile.gender);
          _isLoading = false;
        });
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final fallbackNo = authProvider.currentMblNo ?? '';
        setState(() {
          _userProfile = UserModel(
            mblNo: fallbackNo,
            name: fallbackNo,
          );
          _nameController.text = fallbackNo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load profile from server.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_userProfile == null) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = UserModel(
        mblNo: _userProfile!.mblNo,
        name: newName,
        email: _userProfile!.email,
        imgUrl: _userProfile!.imgUrl,
        gender: _selectedGender,
        dob: _dobController.text.trim().isEmpty
            ? null
            : _dobController.text.trim(),
      );

      final result = await _authService.updateProfile(updated);
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        if (result != null) {
          _userProfile = result;
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          authProvider.updateProfileData(
            name: result.name,
            imgUrl: result.imgUrl,
          );
          final chatProvider =
              Provider.of<ChatProvider>(context, listen: false);
          chatProvider.updateChatUserInfo(
            result.mblNo,
            name: result.name,
            imgUrl: result.imgUrl,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Color(0xFF25D366),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1930),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppConfig.brandDark,
              onPrimary: Colors.white,
              onSurface: AppConfig.brandDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final dynamic result = await _imageChannel.invokeMethod('pickImage');
      if (result != null && result is Map) {
        final Uint8List? bytes = result['bytes'] as Uint8List?;
        final String ext = (result['ext'] as String?) ?? 'jpg';
        if (bytes != null && bytes.isNotEmpty) {
          await _uploadAvatarBytes(bytes, ext);
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: ${e.message}')),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'App rebuild required: Native Android gallery picker needs a full app restart (stop the app and run "flutter run"). Or choose an Avatar Preset below!',
            ),
            duration: Duration(seconds: 6),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (errStr.contains('MissingPluginException')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'App rebuild required: Native Android gallery picker needs a full app restart (stop the app and run "flutter run"). Or choose an Avatar Preset below!',
              ),
              duration: Duration(seconds: 6),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
    }
  }

  Future<void> _uploadAvatarBytes(List<int> bytes, String ext) async {
    setState(() => _isUploadingAvatar = true);

    try {
      // 1. Fetch Cloudflare R2 presigned URL from backend
      final presignInfo = await _authService.getPresignedUrl(ext);
      if (presignInfo == null) {
        throw Exception('Failed to generate presigned upload URL from server');
      }

      final uploadUrl = presignInfo['uploadUrl']!;
      final filePublicUrl = presignInfo['filePublicUrl']!;

      // 2. Upload image binary directly to Cloudflare R2
      final uploadResult = await _authService.uploadImageToPresignedUrl(
        uploadUrl: uploadUrl,
        imageBytes: bytes,
        fileExtension: ext,
      );

      if (uploadResult['success'] != true) {
        final statusCode = uploadResult['statusCode'];
        final errBody = uploadResult['body'] ?? '';
        if (uploadUrl.contains("account.r2.cloudflarestorage.com")) {
          throw Exception(
              'Backend Cloudflare R2 credentials are not configured! Please set CLOUDFLARE_R2_* in backend .env');
        }
        throw Exception(
            'Cloudflare R2 rejected upload (HTTP $statusCode): $errBody');
      }

      // Cache the compressed image bytes locally so it loads instantly with no network request
      await AvatarCacheService.instance.saveBytesToCache(filePublicUrl, bytes);

      // 3. Save the new public URL in the user profile on backend
      final updated = UserModel(
        mblNo: _userProfile!.mblNo,
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : _userProfile!.name,
        email: _userProfile!.email,
        imgUrl: filePublicUrl,
        gender: _selectedGender,
        dob: _dobController.text.trim().isEmpty
            ? null
            : _dobController.text.trim(),
      );

      final saved = await _authService.updateProfile(updated);
      if (!mounted) return;

      setState(() {
        _isUploadingAvatar = false;
        if (saved != null) {
          _userProfile = saved;
        } else {
          _userProfile = updated;
        }
      });

      // Update AuthProvider and ChatProvider immediately
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.updateProfileData(
        name: _userProfile?.name,
        imgUrl: filePublicUrl,
      );

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (_userProfile?.mblNo != null) {
        chatProvider.updateChatUserInfo(
          _userProfile!.mblNo,
          name: _userProfile!.name,
          imgUrl: filePublicUrl,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully!'),
          backgroundColor: Color(0xFF25D366),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    }
  }

  void _showAvatarOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.brandDark,
                      ),
                    ),
                    if (_userProfile?.imgUrl != null &&
                        _userProfile!.imgUrl!.isNotEmpty)
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove Photo',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final updated = UserModel(
                            mblNo: _userProfile!.mblNo,
                            name: _nameController.text.trim(),
                            imgUrl: '',
                            gender: _selectedGender,
                            dob: _dobController.text.trim(),
                          );
                          final res = await _authService.updateProfile(updated);
                          if (mounted && res != null) {
                            setState(() => _userProfile = res);
                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            authProvider.updateProfileData(
                              name: res.name,
                              imgUrl: '',
                            );
                            final chatProvider = Provider.of<ChatProvider>(
                                context,
                                listen: false);
                            chatProvider.updateChatUserInfo(
                              res.mblNo,
                              name: res.name,
                              imgUrl: '',
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_userProfile?.imgUrl != null &&
                    _userProfile!.imgUrl!.isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.fullscreen_rounded,
                          color: Colors.purple.shade700),
                    ),
                    title: const Text('View Full Photo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Pinch & zoom photo full screen'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageScreen(
                            imageUrl: _userProfile!.imgUrl,
                            userName: _userProfile!.name,
                            phoneNumber: _userProfile!.mblNo,
                            showChatButton: false,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConfig.brandLimeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: AppConfig.brandDark),
                  ),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pick photo & upload to Cloudflare R2'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.face_rounded, color: Colors.blue.shade700),
                  ),
                  title: const Text('Choose an Avatar Preset',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select from cartoon avatars'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAvatarPresetsDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAvatarPresetsDialog() {
    final seed = _userProfile?.mblNo ?? 'user';
    final presets = [
      'https://api.dicebear.com/7.x/bottts/png?seed=$seed',
      'https://api.dicebear.com/7.x/adventurer/png?seed=$seed',
      'https://api.dicebear.com/7.x/avataaars/png?seed=$seed',
      'https://api.dicebear.com/7.x/lorelei/png?seed=$seed',
      'https://api.dicebear.com/7.x/pixel-art/png?seed=$seed',
      'https://api.dicebear.com/7.x/notionists/png?seed=$seed',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Select Avatar Preset',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: presets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final url = presets[index];
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(dialogCtx);
                    setState(() => _isUploadingAvatar = true);
                    try {
                      final resp = await http.get(Uri.parse(url));
                      if (resp.statusCode == 200) {
                        await _uploadAvatarBytes(resp.bodyBytes, 'png');
                      }
                    } catch (e) {
                      setState(() => _isUploadingAvatar = false);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final displayMblNo =
        _userProfile?.mblNo ?? authProvider.currentMblNo ?? 'User';
    final initial = (_nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()[0]
            : (displayMblNo.isNotEmpty ? displayMblNo[0] : '?'))
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppConfig.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppConfig.brandDark,
        elevation: 0.5,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConfig.brandDark,
                      ),
                    )
                  : const Icon(Icons.check, color: AppConfig.brandDark),
              tooltip: 'Save Profile',
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppConfig.brandDark),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // 1. Avatar Section
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _showAvatarOptionsSheet,
                    child: Stack(
                      children: [
                        CachedAvatar(
                          imgUrl: _userProfile?.imgUrl,
                          name: _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()
                              : displayMblNo,
                          radius: 54,
                          fontSize: 44,
                          backgroundColor: AppConfig.brandDark,
                        ),
                        if (_isUploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppConfig.brandLime,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: AppConfig.brandDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed:
                        _isUploadingAvatar ? null : _showAvatarOptionsSheet,
                    icon: const Icon(Icons.edit,
                        size: 14, color: AppConfig.brandDark),
                    label: const Text(
                      'Change Photo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConfig.brandDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _nameController.text.trim().isNotEmpty
                        ? _nameController.text.trim()
                        : displayMblNo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.brandDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    displayMblNo,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 2. Profile Details Card
                Container(
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
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.brandDark,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          prefixIcon:
                              const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppConfig.brandDark,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Phone Number Field (Read-only)
                      TextField(
                        controller: TextEditingController(text: displayMblNo),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon:
                              const Icon(Icons.phone_outlined, size: 20),
                          helperText: 'Phone number is linked to your account',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _normalizeGender(_selectedGender),
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon:
                              const Icon(Icons.transgender_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'MALE', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'FEMALE', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedGender = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth Field
                      TextField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_outlined,
                                size: 18),
                            onPressed: _pickDate,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Quick Action: Chat With Yourself (Notes)
                Container(
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
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppConfig.brandLimeLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppConfig.brandDark,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Message Yourself (Notes)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppConfig.brandDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Send notes, links, and media to your own number',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            contactMblNo: displayMblNo,
                            contactName: 'You (Notes)',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.brandDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
