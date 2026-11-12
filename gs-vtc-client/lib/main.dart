import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/client_api.dart';
import 'auth/auth_controller.dart';
import 'auth/session_store.dart';
import 'booking/booking_controller.dart';
import 'config.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final store = SecureSessionStore();
  final client = ApiClient(baseUrl: apiBaseUrl, store: store);
  final auth = AuthController(client: client, store: store);
  await auth.restore();
  final api = ClientApi(client);
  runApp(ClientApp(auth: auth, api: api, booking: BookingController(api)));
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key, required this.auth, required this.api, required this.booking});

  final AuthController auth;
  final ClientApi api;
  final BookingController booking;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: booking),
        Provider.value(value: api),
      ],
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Consumer<AuthController>(
          builder: (context, auth, _) => auth.state == AuthState.unknown ? const Scaffold(body: Center(child: CircularProgressIndicator())) : const HomeShell(),
        ),
      ),
    );
  }
}
