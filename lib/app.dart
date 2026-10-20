import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_pages.dart';
import 'features/shell/main_shell.dart';
import 'state/app_state.dart';

class VenusApp extends StatelessWidget {
  const VenusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Venus JMI Group',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: !state.initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : state.isLoggedIn
          ? const MainShell()
          : const SplashPage(),
    );
  }
}
