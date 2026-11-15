import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/view/home_page.dart';
import 'features/authentication/providers/auth_session_provider.dart';
import 'features/authentication/view/auth_page.dart';
import 'features/authentication/view/splash_page.dart';
import 'features/authentication/providers/session_bootstrap_provider.dart';
import 'theme.dart';
import 'features/settings/viewmodel/theme_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(sessionBootstrapProvider);
    final authenticated = ref.watch(
      authSessionProvider.select((session) => session != null),
    );
    return MaterialApp(
      key: ValueKey(authenticated),
      title: 'Next Harvest',
      locale: const Locale('en', 'US'),
      theme: NextHarvestTheme.light(),
      darkTheme: NextHarvestTheme.dark(),
      themeMode:
          ref.watch(themeViewModelProvider).asData?.value ?? ThemeMode.system,
      home: startup.when(
        skipLoadingOnRefresh: false,
        loading: () => const SplashPage(),
        error: (_, _) => const SplashPage(hasError: true),
        data: (_) => authenticated ? const HomePage() : const AuthPage(),
      ),
    );
  }
}
