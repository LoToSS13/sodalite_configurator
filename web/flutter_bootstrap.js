{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (error) {
      window.sodaliteSplash?.fail();
      console.error('Unable to start the configurator.', error);
    }
  },
}).catch((error) => {
  window.sodaliteSplash?.fail();
  console.error('Unable to load the configurator.', error);
});
