import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/website_provider.dart';
import 'providers/api_provider.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/websites/website_form_screen.dart';
import 'screens/apis/api_form_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  runApp(const DevManagerApp());
}

class DevManagerApp extends StatelessWidget {
  const DevManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebsiteProvider()),
        ChangeNotifierProvider(create: (_) => ApiProvider()),
      ],
      child: MaterialApp(
        title: 'DevManager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
        routes: {
          '/add-website': (_) => const WebsiteFormScreen(),
          '/add-endpoint': (_) => const ApiFormScreen(),
        },
      ),
    );
  }
}
