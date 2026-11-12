import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/driver_api.dart';
import 'auth/auth_controller.dart';
import 'auth/session_store.dart';
import 'config.dart';
import 'push/push_service.dart';
import 'recruitment/document_picker.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final store = SecureSessionStore();
  final client = ApiClient(baseUrl: apiBaseUrl, store: store);
  final auth = AuthController(client: client, store: store);
  final push = PushService(client: client, store: store);
  await Future.wait([auth.restore(), push.init()]);
  if (auth.state == AuthState.signedIn) await push.registerToken();
  runApp(DriverApp(auth: auth, api: DriverApi(client), push: push));
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key, required this.auth, required this.api, required this.push});

  final AuthController auth;
  final DriverApi api;
  final PushService push;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: api),
        Provider.value(value: push),
        Provider<DocumentPicker>.value(value: DevicePicker()),
      ],
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Consumer<AuthController>(
          builder: (context, auth, _) => switch (auth.state) {
            AuthState.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
            AuthState.signedOut => const LoginScreen(),
            AuthState.signedIn => const HomeShell(),
          },
        ),
      ),
    );
  }
}
