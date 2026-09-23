import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const AppLifecycleManager(
        child: AppView(),
      ),
    );
  }
}

/// Dedicated lifecycle manager to handle background/resume socket management
class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Gracefully close WebSocket sink on background
      WebSocketService().disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // Safely access providers now that context is inside the MultiProvider tree
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);
      if (auth.isAuthenticated && auth.currentMblNo != null) {
        chat.init(auth.currentMblNo!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return MaterialApp(
          title: 'Heychat',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppConfig.lightBg,
            colorScheme: const ColorScheme.light(
              primary: AppConfig.brandDark,
              secondary: AppConfig.brandLime,
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: AppConfig.brandDark,
              elevation: 0.5,
              scrolledUnderElevation: 1,
              iconTheme: IconThemeData(color: AppConfig.brandDark),
              titleTextStyle: TextStyle(
                color: AppConfig.brandDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          home: auth.isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppConfig.brandDark,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : (auth.isAuthenticated
                  ? const HomeScreen()
                  : const LoginScreen()),
        );
      },
    );
  }
}
