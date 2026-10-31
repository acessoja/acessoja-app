{{flutter_js}}
{{flutter_build_config}}

// Serve the renderer with this build, including deployments without CDN access.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString(),
  },
});
