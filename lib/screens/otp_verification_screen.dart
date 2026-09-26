import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/log_service.dart';
import '../widgets/server_settings_dialog.dart';
import 'login_screen.dart';
import 'logs_screen.dart';
import 'restore_backup_screen.dart';

String extractErrorMessage(String body) {
  if (body.trim().isEmpty) return 'An error occurred. Please try again.';
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final msg = decoded['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) {
        final lower = msg.toLowerCase();
        if (lower == 'unauthorized' ||
            lower == 'bad credentials' ||
            lower.contains('unauthorized')) {
          return 'Invalid credentials. Please check your phone number and password.';
        }
        return msg;
      }
      final err = decoded['error']?.toString().trim();
      if (err != null && err.isNotEmpty) {
        final lower = err.toLowerCase();
        if (lower == 'unauthorized' ||
            lower == 'bad credentials' ||
            lower.contains('unauthorized')) {
          return 'Invalid credentials. Please check your phone number and password.';
        }
        return err;
      }
    }
  } catch (_) {}
  final raw = body.trim();
  final lower = raw.toLowerCase();
  if (lower == 'unauthorized' ||
      lower == 'bad credentials' ||
      lower.contains('unauthorized')) {
    return 'Invalid credentials. Please check your phone number and password.';
  }
  return raw;
}

class OtpSession {
  final String phone;
  final String email;
  final String? fullName;
  final String? password;
  String? verificationToken;
  DateTime expiryTime;
  final int totalSeconds;

  OtpSession({
    required this.phone,
    required this.email,
    this.fullName,
    this.password,
    this.verificationToken,
    required this.expiryTime,
    this.totalSeconds = 300,
  });

  bool isValid([String? pass]) {
    if (pass != null && password != null && pass != password) {
      return false;
    }
    return expiryTime.difference(DateTime.now()).inSeconds > 5;
  }

  int get remainingSeconds {
    final diff = expiryTime.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

class OtpVerificationScreen extends StatelessWidget {
  // Static registry of active sessions managed entirely by OtpVerificationScreen
  static final Map<String, OtpSession> _sessions = {};

  static void clearSession(String phone) {
    _sessions.remove(phone);
  }

  static String _extractEmail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['email'] != null) {
        return decoded['email'].toString().trim();
      }
    } catch (_) {}
    final match =
        RegExp(r'Email:\s*([^\s,]+)', caseSensitive: false).firstMatch(body);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return '';
  }

  static int _extractTtl(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['ttl'] != null) {
        return int.tryParse(decoded['ttl'].toString()) ?? 300;
      }
    } catch (_) {}
    final match = RegExp(r'OTP_ACTIVE:(\d+)').firstMatch(body);
    if (match != null && match.group(1) != null) {
      return int.tryParse(match.group(1)!) ?? 300;
    }
    return 300;
  }

  static String? _extractVerificationToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> &&
          decoded['verificationToken'] != null) {
        return decoded['verificationToken'].toString();
      }
    } catch (_) {}
    return null;
  }

  /// Handles Login OTP: resumes active session without hitting backend if still valid.
  static Future<String?> startLoginOtp({
    required BuildContext context,
    required String phone,
    required String pass,
    required AuthService authService,
  }) async {
    final session = _sessions[phone];
    if (session != null && session.isValid(pass)) {
      // Resume directly without backend API call!
      _pushLoginScreen(context, session, pass, authService);
      return null;
    }

    try {
      final res = await authService.login(phone, pass);
      if (res.statusCode == 200) {
        if (!context.mounted) return null;
        final email = _extractEmail(res.body);
        final ttl = _extractTtl(res.body);
        final token = _extractVerificationToken(res.body);
        final newSession = OtpSession(
          phone: phone,
          email: email,
          password: pass,
          verificationToken: token,
          expiryTime: DateTime.now().add(Duration(seconds: ttl)),
          totalSeconds: 300,
        );
        _sessions[phone] = newSession;
        _pushLoginScreen(context, newSession, pass, authService);
        return null;
      } else {
        return extractErrorMessage(res.body);
      }
    } catch (e) {
      return e.toString().contains('SocketException')
          ? 'Cannot connect to server. Please check your network/server.'
          : e.toString();
    }
  }

  static void _pushLoginScreen(
    BuildContext context,
    OtpSession session,
    String pass,
    AuthService authService,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => OtpVerificationScreen(
          email: session.email,
          phone: session.phone,
          fullName: null, // Login mode: email only
          initialTtlSeconds: session.remainingSeconds,
          totalTtlSeconds: session.totalSeconds,
          onConfirmOtp: (otp) async {
            final res = await authService.verifyOtp(session.phone, otp,
                verificationToken: session.verificationToken);
            if (res.statusCode == 200) return null;
            return extractErrorMessage(res.body);
          },
          onResendOtp: () async {
            final res = await authService.login(session.phone, pass);
            if (res.statusCode == 200) {
              session.verificationToken = _extractVerificationToken(res.body) ??
                  session.verificationToken;
              session.expiryTime =
                  DateTime.now().add(const Duration(seconds: 300));
              return null;
            }
            return extractErrorMessage(res.body);
          },
          onSuccess: () async {
            _sessions.remove(session.phone);
            await Provider.of<AuthProvider>(context, listen: false)
                .setLoggedIn(session.phone);
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => RestoreBackupScreen(phone: session.phone),
              ),
              (route) => false,
            );
          },
          bottomPromptText: "Wrong number or password? ",
          bottomActionText: "Change",
          onBottomActionTap: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  /// Handles Signup OTP: resumes active session without hitting backend if still valid.
  static Future<String?> startSignupOtp({
    required BuildContext context,
    required String name,
    required String phone,
    required String email,
    required String pass,
    required String confirmPass,
    required String gender,
    required String dob,
    required AuthService authService,
    required void Function(String message) onAlreadyRegistered,
  }) async {
    final session = _sessions[phone];
    if (session != null && session.isValid(pass)) {
      // Resume directly without backend API call!
      _pushSignupScreen(
        context: context,
        session: session,
        name: name,
        pass: pass,
        confirmPass: confirmPass,
        gender: gender,
        dob: dob,
        authService: authService,
      );
      return null;
    }

    try {
      final res = await authService.signUp(
        name: name,
        mblNo: phone,
        email: email,
        pass: pass,
        confirmPass: confirmPass,
        gender: gender,
        dob: dob,
      );

      if (res.statusCode == 200) {
        if (!context.mounted) return null;
        final ttl = _extractTtl(res.body);
        final emailFromResp = _extractEmail(res.body);
        final token = _extractVerificationToken(res.body);
        final newSession = OtpSession(
          phone: phone,
          email: emailFromResp.isNotEmpty ? emailFromResp : email,
          fullName: name,
          password: pass,
          verificationToken: token,
          expiryTime: DateTime.now().add(Duration(seconds: ttl)),
          totalSeconds: 300,
        );
        _sessions[phone] = newSession;
        _pushSignupScreen(
          context: context,
          session: newSession,
          name: name,
          pass: pass,
          confirmPass: confirmPass,
          gender: gender,
          dob: dob,
          authService: authService,
        );
        return null;
      } else {
        final msg = extractErrorMessage(res.body);
        final lowerBody = res.body.toLowerCase();
        final lowerMsg = msg.toLowerCase();
        if (res.statusCode == 409 ||
            lowerBody.contains('already') ||
            lowerBody.contains('exists') ||
            lowerMsg.contains('already') ||
            lowerMsg.contains('registered')) {
          onAlreadyRegistered(msg);
          return null;
        }
        return msg;
      }
    } catch (e) {
      return e.toString().contains('SocketException')
          ? 'Cannot connect to server. Please check your network/server.'
          : e.toString();
    }
  }

  static void _pushSignupScreen({
    required BuildContext context,
    required OtpSession session,
    required String name,
    required String pass,
    required String confirmPass,
    required String gender,
    required String dob,
    required AuthService authService,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => OtpVerificationScreen(
          email: session.email,
          phone: session.phone,
          fullName: name,
          initialTtlSeconds: session.remainingSeconds,
          totalTtlSeconds: session.totalSeconds,
          onConfirmOtp: (otp) async {
            final res = await authService.verifySignup(session.phone, otp,
                verificationToken: session.verificationToken);
            if (res.statusCode == 200) return null;
            return extractErrorMessage(res.body);
          },
          onResendOtp: () async {
            final res = await authService.signUp(
              name: name,
              mblNo: session.phone,
              email: session.email,
              pass: pass,
              confirmPass: confirmPass,
              gender: gender,
              dob: dob,
            );
            if (res.statusCode == 200) {
              session.verificationToken = _extractVerificationToken(res.body) ??
                  session.verificationToken;
              session.expiryTime =
                  DateTime.now().add(const Duration(seconds: 300));
              return null;
            }
            return extractErrorMessage(res.body);
          },
          onSuccess: () {
            _sessions.remove(session.phone);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration successful! Please login.'),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          bottomPromptText: "Already have an account? ",
          bottomActionText: "Login",
          onBottomActionTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
    );
  }

  final String email;
  final String phone;
  final String? fullName; // When null/empty, only email is shown (Login mode).
  final int initialTtlSeconds;
  final int totalTtlSeconds;
  final Future<String?> Function(String otp) onConfirmOtp;
  final Future<String?> Function() onResendOtp;
  final VoidCallback onSuccess;
  final String? bottomPromptText;
  final String? bottomActionText;
  final VoidCallback? onBottomActionTap;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phone,
    this.fullName,
    this.initialTtlSeconds = 300,
    this.totalTtlSeconds = 300,
    required this.onConfirmOtp,
    required this.onResendOtp,
    required this.onSuccess,
    this.bottomPromptText,
    this.bottomActionText,
    this.onBottomActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify OTP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppConfig.brandDark,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Server IP Settings',
            onPressed: () {
              showServerSettingsDialog(context, onSaved: () {});
            },
          ),
          if (LogService.isEnabled)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'App Device Logs',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Text(
            'By continuing, you agree to our Terms of Service & Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: OtpVerificationWidget(
            email: email,
            phone: phone,
            fullName: fullName,
            initialTtlSeconds: initialTtlSeconds,
            totalTtlSeconds: totalTtlSeconds,
            onConfirmOtp: onConfirmOtp,
            onResendOtp: onResendOtp,
            onSuccess: onSuccess,
            bottomPromptText: bottomPromptText,
            bottomActionText: bottomActionText,
            onBottomActionTap: onBottomActionTap,
          ),
        ),
      ),
    );
  }
}

class OtpVerificationWidget extends StatefulWidget {
  final String email;
  final String phone;
  final String? fullName;
  final int initialTtlSeconds;
  final int totalTtlSeconds;
  final Future<String?> Function(String otp) onConfirmOtp;
  final Future<String?> Function() onResendOtp;
  final VoidCallback onSuccess;
  final String? bottomPromptText;
  final String? bottomActionText;
  final VoidCallback? onBottomActionTap;

  const OtpVerificationWidget({
    super.key,
    required this.email,
    required this.phone,
    this.fullName,
    this.initialTtlSeconds = 300,
    this.totalTtlSeconds = 300,
    required this.onConfirmOtp,
    required this.onResendOtp,
    required this.onSuccess,
    this.bottomPromptText,
    this.bottomActionText,
    this.onBottomActionTap,
  });

  @override
  State<OtpVerificationWidget> createState() => _OtpVerificationWidgetState();
}

class _OtpVerificationWidgetState extends State<OtpVerificationWidget> {
  static const int defaultTotalSeconds = 300;
  final _otpController = TextEditingController();
  late int _resendSeconds;
  late int _totalSeconds;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _canResend => _resendSeconds == 0;

  String get _formattedTime {
    final m = (_resendSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _timerProgress {
    if (_totalSeconds <= 0) return 0.0;
    return (_resendSeconds / _totalSeconds).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.totalTtlSeconds > 0
        ? widget.totalTtlSeconds
        : defaultTotalSeconds;
    if (widget.initialTtlSeconds > _totalSeconds) {
      _totalSeconds = widget.initialTtlSeconds;
    }
    _resendSeconds =
        widget.initialTtlSeconds > 0 ? widget.initialTtlSeconds : _totalSeconds;
    _startTimer(_resendSeconds);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _resendSeconds = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _handleResend() async {
    if (!_canResend || _isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final error = await widget.onResendOtp();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (error == null) {
        setState(() {
          _totalSeconds = defaultTotalSeconds;
        });
        _startTimer(defaultTotalSeconds);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New OTP sent successfully!')),
        );
      } else {
        setState(() {
          _errorMessage = error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().contains('SocketException')
            ? 'Cannot connect to server. Please check your network/server.'
            : e.toString();
      });
    }
  }

  void _handleConfirm() async {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final error = await widget.onConfirmOtp(otp);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (error == null) {
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage = error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().contains('SocketException')
            ? 'Cannot connect to server. Please check your network/server.'
            : e.toString();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFullName =
        widget.fullName != null && widget.fullName!.trim().isNotEmpty;

    return Column(
      children: [
        if (hasFullName) ...[
          // Signup Summary: Full Name, Phone, and Email
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppConfig.cardGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.fullName!.trim(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.brandDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mobile Number',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppConfig.cardGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.phone.trim(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.brandDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppConfig.cardGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.email.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.brandDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // Email Verification Notice Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppConfig.brandLime, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppConfig.brandLime,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'OTP sent successfully on registered email:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppConfig.brandDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  widget.email.trim().isNotEmpty
                      ? widget.email.trim()
                      : 'Registered email address',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.brandDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Enter OTP Field with Label
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Enter OTP',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppConfig.brandDark,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
            color: AppConfig.brandDark,
          ),
          decoration: InputDecoration(
            hintText: 'Enter 6-digit OTP',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              letterSpacing: 0,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            counterText: '',
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppConfig.brandDark, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend OTP Timer Card with Sleek Dark Pill & Lime Countdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _canResend ? Colors.grey : AppConfig.brandLime,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: _canResend ? Colors.grey : AppConfig.brandDark,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Resend OTP Available In:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConfig.brandDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formattedTime,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: _canResend
                            ? Colors.grey.shade500
                            : AppConfig.brandLime,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _timerProgress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _canResend ? Colors.grey : AppConfig.brandLime,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Resend OTP & Confirm OTP Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _canResend && !_isLoading ? _handleResend : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color:
                        _canResend ? AppConfig.brandDark : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  'Resend OTP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color:
                        _canResend ? AppConfig.brandDark : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.brandLime,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm OTP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (widget.bottomActionText != null) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.bottomPromptText != null)
                Text(
                  widget.bottomPromptText!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              GestureDetector(
                onTap: widget.onBottomActionTap,
                child: Text(
                  widget.bottomActionText!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppConfig.brandDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 50),
      ],
    );
  }
}
