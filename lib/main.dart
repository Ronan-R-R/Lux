import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/company_onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/catalogue_screen.dart';
import 'screens/store_screen.dart';
import 'screens/store_detail_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/pdf_upload_screen.dart';
import 'screens/company_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Initialization Error:\n$e',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
    return;
  }

  runApp(const ProviderScope(child: LuxApp()));
}

// Refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _router = GoRouter(
  initialLocation: '/',
  refreshListenable:
      GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loc = state.matchedLocation;
    final publicRoutes = ['/login', '/register'];

    if (session == null && !publicRoutes.contains(loc)) return '/login';
    if (session != null && publicRoutes.contains(loc)) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const CompanyOnboardingScreen()),
    GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/stores', builder: (_, __) => const StoreScreen()),
    GoRoute(
      path: '/store-detail',
      builder: (context, state) =>
          StoreDetailScreen(store: state.extra as Store),
    ),
    GoRoute(path: '/catalogue', builder: (_, __) => const CatalogueScreen()),
    GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
    GoRoute(path: '/upload', builder: (_, __) => const PdfUploadScreen()),
    GoRoute(path: '/company-settings', builder: (_, __) => const CompanySettingsScreen()),
  ],
);

class LuxApp extends StatelessWidget {
  const LuxApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lux',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
