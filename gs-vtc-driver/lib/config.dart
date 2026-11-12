// Adresse de l'API, choisie à la compilation :
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
// Par défaut, 10.0.2.2 est l'ordinateur vu depuis l'émulateur Android.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

// Site web (mot de passe oublié, inscription, documents) : --dart-define=SITE_URL=https://...
const String siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'http://10.0.2.2:3001');

// Nom affiché dans l'app : le nom définitif n'est pas encore choisi.
const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'Chauffeur');
