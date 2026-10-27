import 'package:flutter/material.dart';

import 'common/di/injector.dart';
import 'common/domain/entities/app_settings.dart';
import 'common/domain/repositories/settings_repository.dart';
import 'common/domain/usecases/watch_settings_usecase.dart';
import 'common/presentation/theme/app_theme.dart';
import 'screens/home/view/home_view.dart';

class NexoraApp extends StatefulWidget {
  const NexoraApp({super.key});

  @override
  State<NexoraApp> createState() => _NexoraAppState();
}

class _NexoraAppState extends State<NexoraApp> {
  // Rebuilds the theme whenever the colour is changed in Settings.
  final _settings = sl<WatchSettingsUseCase>()();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings>(
      stream: _settings,
      initialData: sl<SettingsRepository>().current,
      builder: (context, snapshot) {
        final color = snapshot.data!.themeColor;
        return MaterialApp(
          title: 'NexoraApp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(color),
          darkTheme: AppTheme.dark(color),
          home: const HomeView(),
        );
      },
    );
  }
}
