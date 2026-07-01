/// Web OAuth 2.0 client for YouTube linking (server auth code exchange).
///
/// Must be the **Firebase Web client** from the same GCP project as the Android
/// app (`android/app/google-services.json` → `oauth_client` with `client_type: 3`).
/// Using a Web client from a different project causes Android `ApiException: 10`.
///
/// Also set Firebase secrets `YOUTUBE_CLIENT_ID` / `YOUTUBE_CLIENT_SECRET` to this
/// same Web client's ID and secret. See docs/STREAMING_SETUP.md.
const kYouTubeWebClientId =
    '202403125129-vnidfiidc4dj9tks4btugh9ncnhn8oi5.apps.googleusercontent.com';
