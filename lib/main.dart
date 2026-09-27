import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'logic/app_state.dart';
import 'ui/screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MahfathatiApp());
}

class MahfathatiApp extends StatelessWidget {
  const MahfathatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'محفظتي',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(textDirection: TextDirection.rtl, child: child!);
        },
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
