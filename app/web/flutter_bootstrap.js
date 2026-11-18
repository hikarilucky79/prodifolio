{{flutter_js}}
{{flutter_build_config}}

(function () {
  function hideFolioShellFromAccessibility() {
    var shell = document.getElementById('folio-shell');
    if (shell) {
      shell.setAttribute('aria-hidden', 'true');
    }
  }

  window.addEventListener('flutter-first-frame', hideFolioShellFromAccessibility, {
    once: true
  });

  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}}
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      suppressMultithreadingWarning: true
    },
    onEntrypointLoaded: async function (engineInitializer) {
      var appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      requestAnimationFrame(function () {
        requestAnimationFrame(hideFolioShellFromAccessibility);
      });
    }
  });
})();
