{{flutter_js}}
{{flutter_build_config}}

// Custom bootstrap: no deprecated service worker (avoids stale cached
// builds), CanvasKit served from this site, and a visible error instead of a
// white page if the engine or app fails to start.
(function () {
  // Headless Chromium / some Linux boxes report locales like "en-US@posix"
  // which Flutter's Locale parser rejects ("Incorrect locale information").
  // Normalize before the engine reads navigator.language(s).
  try {
    var bad = function (v) {
      return !v || /[@;]|posix/i.test(String(v));
    };
    var langs = navigator.languages ? Array.prototype.slice.call(navigator.languages) : [];
    if (bad(navigator.language) || langs.some(bad)) {
      Object.defineProperty(Navigator.prototype, 'language', {
        configurable: true,
        get: function () { return 'en-US'; },
      });
      Object.defineProperty(Navigator.prototype, 'languages', {
        configurable: true,
        get: function () { return ['en-US']; },
      });
    }
  } catch (_) { /* best-effort */ }

  function showBootError(err) {
    var box = document.getElementById('cf-boot');
    if (!box) return;
    box.classList.add('cf-boot-error');
    var msg = document.getElementById('cf-boot-msg');
    if (msg) {
      msg.textContent = 'The admin panel failed to load. Reload with Ctrl+Shift+R ' +
        '(Cmd+Shift+R on Mac). Details: ' + (err && err.message ? err.message : String(err));
    }
  }
  window.cfShowBootError = showBootError;
  _flutter.loader.load({
    config: { canvasKitBaseUrl: 'canvaskit/' },
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        var appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
      } catch (e) {
        console.error('Flutter start failed', e);
        showBootError(e);
      }
    },
  }).catch(function (e) {
    console.error('Flutter load failed', e);
    showBootError(e);
  });
})();
