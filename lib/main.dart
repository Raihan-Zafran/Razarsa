import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications.dart';
import 'core/theme.dart';
import 'data/store.dart';
import 'features/auth/login_screen.dart';
import 'features/security/lock.dart';
import 'shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  store.onExpenseAdded = () => Notif.checkBudget(store);
  Notif.syncDaily(store.switches['daily'] == true);
  runApp(RazarsaApp(store: store));
}

class RazarsaApp extends StatelessWidget {
  const RazarsaApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Razarsa',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 450),
          locale: store.lang == 'en' ? const Locale('en', 'US') : const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                  .copyWith(statusBarColor: Colors.transparent),
              child: child!,
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: store.loggedIn ? const LockGate(key: ValueKey('app'), child: AppShell()) : const LoginScreen(key: ValueKey('login')),
          ),
        ),
      ),
    );
  }
}
