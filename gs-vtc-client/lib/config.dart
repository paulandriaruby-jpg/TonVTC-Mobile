// Réglages choisis à la compilation (--dart-define=NOM=valeur).
// API_BASE_URL : adresse de l'API (par défaut l'ordinateur vu depuis l'émulateur Android).
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

// Site web (mot de passe oublié, conditions générales).
const String siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'http://10.0.2.2:3001');

// Identifiant OAuth "application Web" du projet Google Cloud : le jeton Google est émis pour lui et vérifié par l'API.
// Vide : le bouton "Continuer avec Google" indique que la connexion Google n'est pas encore disponible.
const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

// Nom affiché dans l'app : le nom définitif n'est pas encore choisi.
const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'TonVTC');

// Staging : jeton envoyé à l'API (en-tête X-Staging-Token), qui refuse sinon. Vide hors staging.
const String stagingToken = String.fromEnvironment('STAGING_TOKEN');
