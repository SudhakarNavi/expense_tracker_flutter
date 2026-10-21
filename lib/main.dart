import 'package:flutter/material.dart';

import 'app.dart';
import 'services/hive_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

/// Opens local storage, then starts the app. If storage cannot be opened the
/// user sees an explanation and a retry button instead of a blank screen.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<AppStores> _stores = HiveService.init();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStores>(
      future: _stores,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ExpenseTrackerApp(stores: snapshot.data!);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: snapshot.hasError
              ? StartupErrorScreen(
                  onRetry: () => setState(() => _stores = HiveService.init()),
                )
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}
