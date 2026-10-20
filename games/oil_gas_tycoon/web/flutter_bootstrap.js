{{flutter_js}}
{{flutter_build_config}}

// Use the build's own renderer so an installed game works offline.
_flutter.loader.load({
  config: { canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href },
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('loading')?.remove();
      if ('serviceWorker' in navigator) {
        // The build tool creates a versioned, scope-local offline bundle.
        navigator.serviceWorker.register(new URL('service_worker.js', document.baseURI)).catch(() => {});
      }
    } catch (error) {
      window.tycoonStartupFailure();
    }
  }
}).catch(() => window.tycoonStartupFailure());
