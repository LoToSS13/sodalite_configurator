(() => {
  const screen = document.getElementById('startup-screen');
  const canvas = document.getElementById('startup-background');
  const message = document.getElementById('startup-message');
  const retry = document.getElementById('startup-retry');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  // Values and gradient stops from the supplied Figma settings.
  const effectParams = {
    detail: 1.19,
    intensity: 2.9,
    twist: 1.57,
    warp: 1.27,
    zoom: 11,
    rotationSpeed: 100,
    morphSpeed: 3.74,
    material: 0,
    gradientBalance: 0,
    gradientMethod: 0,
    gradient: {
      stops: [
        { position: 0, color: { r: 0, g: 117 / 255, b: 1, a: 1 } },
        { position: 0.5, color: { r: 1, g: 1, b: 1, a: 1 } },
        { position: 1, color: { r: 0, g: 117 / 255, b: 1, a: 1 } },
      ],
    },
  };
  let finished = false;
  let failed = false;
  let stopEffect = () => {};

  retry.addEventListener('click', () => window.location.reload());

  const slowTimer = window.setTimeout(() => {
    message.textContent = 'Загрузка занимает больше времени, чем обычно…';
    retry.hidden = false;
  }, 20000);

  function fail() {
    if (finished) return;
    failed = true;
    window.clearTimeout(slowTimer);
    stopEffect();
    screen.classList.add('has-error');
    message.textContent = 'Не удалось загрузить конфигуратор. Попробуйте ещё раз.';
    retry.hidden = false;
  }

  function onScriptError(event) {
    const source = event.target?.src;
    if (typeof source === 'string' && /\/(flutter_bootstrap|main\.dart)\.js(?:\?|$)/.test(source)) {
      fail();
    }
  }

  function finish() {
    if (finished) return;
    finished = true;
    window.clearTimeout(slowTimer);
    window.removeEventListener('error', onScriptError, true);
    screen.setAttribute('aria-hidden', 'true');
    screen.inert = true;
    screen.classList.add('is-ready');
    const remove = () => {
      screen.remove();
      stopEffect();
    };
    if (reducedMotion.matches) {
      remove();
    } else {
      // Fade the entire startup screen evenly, keeping the background animated.
      const startedAt = performance.now();
      function fadeOut(now) {
        const progress = Math.min(1, (now - startedAt) / 700);
        if (progress === 1 || reducedMotion.matches) {
          remove();
          return;
        }
        const eased = progress * progress * (3 - 2 * progress);
        screen.style.opacity = String(1 - eased);
        window.requestAnimationFrame(fadeOut);
      }
      window.requestAnimationFrame(fadeOut);
    }
    delete window.sodaliteSplash;
  }

  window.sodaliteSplash = { fail };
  window.addEventListener('flutter-first-frame', finish, { once: true });
  window.addEventListener('error', onScriptError, true);

  async function startEffect() {
    // The CSS gradient is visible immediately, including without WebGPU.
    if (finished || failed || !navigator.gpu || reducedMotion.matches) return;
    let device;
    let context;
    let animation = 0;
    let disposed = false;
    const state = {};

    function dispose() {
      if (disposed) return;
      disposed = true;
      window.cancelAnimationFrame(animation);
      document.removeEventListener('visibilitychange', onVisibilityChange);
      reducedMotion.removeEventListener('change', onMotionChange);
      canvas.style.visibility = 'hidden';
      state.depthTexture?.destroy();
      state.msaaTexture?.destroy();
      state.vertexBuffer?.destroy();
      state.indexBuffer?.destroy();
      state.uniformBuf?.destroy();
      context?.unconfigure();
      device?.destroy();
    }

    let draw;
    function onVisibilityChange() {
      window.cancelAnimationFrame(animation);
      if (!document.hidden && !disposed) animation = window.requestAnimationFrame(draw);
    }

    function onMotionChange() {
      if (reducedMotion.matches) dispose();
    }

    stopEffect = dispose;
    try {
      const adapter = await navigator.gpu.requestAdapter({ powerPreference: 'low-power' });
      if (!adapter || disposed) return;
      device = await adapter.requestDevice();
      if (disposed) {
        device.destroy();
        return;
      }
      device.lost.then(dispose);
      device.addEventListener('uncapturederror', dispose);
      const { setup, render } = await import('./splash-effect.js');
      if (disposed) return;
      context = canvas.getContext('webgpu');
      if (!context) {
        dispose();
        return;
      }
      const format = navigator.gpu.getPreferredCanvasFormat();
      context.configure({ device, format, alphaMode: 'opaque' });
      setup(device, { state });

      const startedAt = performance.now();
      let previousFrame = -Infinity;
      draw = (now) => {
        if (disposed || document.hidden) return;
        // Limit both pixel count and frame rate while Flutter initializes.
        if (now - previousFrame >= 1000 / 24) {
          try {
            const width = Math.max(1, canvas.clientWidth);
            const height = Math.max(1, canvas.clientHeight);
            const scale = Math.min(window.devicePixelRatio || 1, 1.5, Math.sqrt(1500000 / (width * height)));
            const pixelWidth = Math.min(device.limits.maxTextureDimension2D, Math.max(1, Math.round(width * scale)));
            const pixelHeight = Math.min(device.limits.maxTextureDimension2D, Math.max(1, Math.round(height * scale)));
            if (canvas.width !== pixelWidth || canvas.height !== pixelHeight) {
              canvas.width = pixelWidth;
              canvas.height = pixelHeight;
            }
            render(device, { state, params: effectParams, time: now - startedAt, output: context.getCurrentTexture() });
            previousFrame = now;
          } catch (error) {
            console.debug('Startup background is using its CSS fallback.', error);
            dispose();
            return;
          }
        }
        animation = window.requestAnimationFrame(draw);
      };
      document.addEventListener('visibilitychange', onVisibilityChange);
      reducedMotion.addEventListener('change', onMotionChange);
      if (reducedMotion.matches) dispose();
      else if (!document.hidden) animation = window.requestAnimationFrame(draw);
    } catch (error) {
      console.debug('Startup background is using its CSS fallback.', error);
      dispose();
    }
  }

  // Flutter starts independently; the decorative effect never gates startup.
  window.requestAnimationFrame(() => { void startEffect(); });
})();
