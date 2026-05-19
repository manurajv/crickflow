/**
 * Firebase ID token verification.
 * Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON in production.
 */
let admin;
try {
  admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp();
  }
} catch {
  admin = null;
}

async function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: { code: 'AUTH_REQUIRED', message: 'Bearer token required' },
    });
  }

  const token = header.slice(7);

  if (!admin) {
    req.user = { uid: 'dev-user', role: 'organizer' };
    return next();
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = { uid: decoded.uid, role: decoded.role || 'viewer' };
    next();
  } catch (e) {
    res.status(401).json({
      success: false,
      error: { code: 'INVALID_TOKEN', message: e.message },
    });
  }
}

module.exports = authMiddleware;
