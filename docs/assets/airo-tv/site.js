(function () {
  "use strict";

  var menuButton = document.querySelector("[data-menu-button]");
  var navigation = document.querySelector("[data-navigation]");

  function closeMenu() {
    if (!menuButton || !navigation) return;
    menuButton.setAttribute("aria-expanded", "false");
    navigation.classList.remove("open");
    document.body.classList.remove("menu-open");
  }

  if (menuButton && navigation) {
    menuButton.addEventListener("click", function () {
      var isOpen = menuButton.getAttribute("aria-expanded") === "true";
      menuButton.setAttribute("aria-expanded", String(!isOpen));
      navigation.classList.toggle("open", !isOpen);
      document.body.classList.toggle("menu-open", !isOpen);
    });

    navigation.addEventListener("click", function (event) {
      if (event.target.closest("a")) closeMenu();
    });

    window.addEventListener("resize", function () {
      if (window.innerWidth > 780) closeMenu();
    });
  }

  var sectionLinks = document.querySelectorAll('.site-nav > a[href^="#"]:not(.button)');
  var sectionLinkMap = new Map();

  sectionLinks.forEach(function (link) {
    var section = document.querySelector(link.getAttribute("href"));
    if (section) sectionLinkMap.set(section, link);
  });

  if (typeof window.IntersectionObserver === "function" && sectionLinkMap.size) {
    var sectionObserver = new IntersectionObserver(
      function (entries) {
        var current = entries
          .filter(function (entry) {
            return entry.isIntersecting;
          })
          .sort(function (left, right) {
            return right.intersectionRatio - left.intersectionRatio;
          })[0];

        if (!current) return;
        sectionLinks.forEach(function (link) {
          link.removeAttribute("aria-current");
        });
        sectionLinkMap.get(current.target).setAttribute("aria-current", "location");
      },
      { rootMargin: "-18% 0px -62% 0px", threshold: [0, 0.1, 0.25] },
    );

    sectionLinkMap.forEach(function (_link, section) {
      sectionObserver.observe(section);
    });
  }

  var filters = document.querySelectorAll("[data-guide-filter]");
  var guides = document.querySelectorAll("[data-guide-device]");

  filters.forEach(function (button) {
    button.addEventListener("click", function () {
      var selected = button.getAttribute("data-guide-filter") || "all";
      filters.forEach(function (candidate) {
        candidate.setAttribute("aria-selected", String(candidate === button));
      });
      guides.forEach(function (guide) {
        var devices = (guide.getAttribute("data-guide-device") || "").split(" ");
        guide.hidden = selected !== "all" && !devices.includes(selected);
      });
    });
  });

  var year = document.querySelector("[data-current-year]");
  if (year) year.textContent = String(new Date().getFullYear());

  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (!reducedMotion) {
    var scrollProgress = document.createElement("div");
    scrollProgress.className = "scroll-progress";
    scrollProgress.setAttribute("aria-hidden", "true");
    document.body.appendChild(scrollProgress);

    var progressFrameRequested = false;

    function updateScrollProgress() {
      var scrollRange = document.documentElement.scrollHeight - window.innerHeight;
      var progress = scrollRange > 0 ? window.scrollY / scrollRange : 0;
      scrollProgress.style.transform = "scaleX(" + Math.min(1, Math.max(0, progress)) + ")";
      progressFrameRequested = false;
    }

    function requestProgressUpdate() {
      if (progressFrameRequested) return;
      progressFrameRequested = true;
      window.requestAnimationFrame(updateScrollProgress);
    }

    window.addEventListener("scroll", requestProgressUpdate, { passive: true });
    window.addEventListener("resize", requestProgressUpdate);
    requestProgressUpdate();

    var revealSelectors = [
      ".section-intro",
      ".screen-step",
      ".channel-showcase-content",
      ".live-demo-stage",
      ".live-demo-details",
      ".device-row",
      ".community-item",
      ".roadmap-stage",
      ".vision-step",
      ".trust-grid > *",
    ];
    var revealTargets = [];

    revealSelectors.forEach(function (selector) {
      document.querySelectorAll(selector).forEach(function (element, index) {
        element.classList.add("scroll-reveal");
        element.style.setProperty("--reveal-delay", Math.min(index, 3) * 55 + "ms");
        revealTargets.push(element);
      });
    });

    if (typeof window.IntersectionObserver === "function") {
      var revealObserver = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            revealObserver.unobserve(entry.target);
          });
        },
        { threshold: 0.12, rootMargin: "0px 0px -8% 0px" },
      );
      revealTargets.forEach(function (element) {
        revealObserver.observe(element);
      });
    } else {
      revealTargets.forEach(function (element) {
        element.classList.add("is-visible");
      });
    }
  }

  var liveDemoInstances = [];

  function initializeLiveDemo(root) {
    var demoVideo = root.querySelector("[data-live-demo-video]");
    var demoStart = root.querySelector("[data-live-demo-start]");
    var demoButton = root.querySelector("[data-live-demo-button]");
    var demoStatus = root.querySelector("[data-live-demo-status]");
    if (!demoVideo || !demoStart || !demoButton || !demoStatus) return null;

    var channelName = root.getAttribute("data-live-channel") || "live sample";
    var retryLabel = root.getAttribute("data-live-retry-label") || "Try live sample again";
    var startWithSound = root.hasAttribute("data-live-start-with-sound");
    var initialButtonMarkup = demoButton.innerHTML;
    var idleStatus = demoStatus.textContent;
    var demoHls = null;
    var demoStarted = false;
    var demoRecovering = false;
    var demoRecoveryAttempts = 0;
    var demoRecoveryTimer = null;
    var demoSource = "";
    var demoUsesNativeHls = false;

    function setDemoStatus(message, state) {
      demoStatus.textContent = message;
      demoStatus.setAttribute("data-state", state || "ready");
      root.setAttribute("data-live-state", state || "ready");
    }

    function clearDemoRecoveryTimer() {
      if (!demoRecoveryTimer) return;
      window.clearTimeout(demoRecoveryTimer);
      demoRecoveryTimer = null;
    }

    function requestDemoPlayback() {
      if (!demoStarted) return;
      var playRequest = demoVideo.play();
      if (!playRequest) return;
      playRequest
        .then(function () {
          demoStart.hidden = true;
        })
        .catch(function (error) {
          if (!demoStarted) return;
          if (demoRecovering && error && error.name !== "NotAllowedError") return;
          if (!demoRecovering && error && error.name !== "NotAllowedError") {
            setDemoStatus("Preparing the live stream...", "loading");
            return;
          }
          clearDemoRecoveryTimer();
          demoRecovering = false;
          demoStart.hidden = true;
          setDemoStatus("Stream ready. Press the video Play control to continue.", "ready");
        });
    }

    function destroyDemoStream() {
      clearDemoRecoveryTimer();
      demoStarted = false;
      demoRecovering = false;
      demoRecoveryAttempts = 0;
      demoSource = "";
      demoUsesNativeHls = false;
      if (demoHls) {
        demoHls.destroy();
        demoHls = null;
      }
      demoVideo.pause();
      demoVideo.removeAttribute("src");
      demoVideo.load();
    }

    function restoreDemoUi(useRetryLabel) {
      demoStart.hidden = false;
      demoButton.disabled = false;
      demoButton.innerHTML = useRetryLabel
        ? '<i data-lucide="rotate-cw" aria-hidden="true"></i> ' + retryLabel
        : initialButtonMarkup;
      if (!useRetryLabel) setDemoStatus(idleStatus, "ready");
      if (window.lucide) window.lucide.createIcons();
    }

    function resetDemoAfterFailure() {
      destroyDemoStream();
      restoreDemoUi(true);
    }

    function failDemo(message) {
      setDemoStatus(message, "error");
      resetDemoAfterFailure();
    }

    function retryNativeDemo() {
      if (!demoSource) return;
      var separator = demoSource.includes("?") ? "&" : "?";
      demoVideo.pause();
      demoVideo.removeAttribute("src");
      demoVideo.load();
      window.setTimeout(function () {
        if (!demoStarted || !demoRecovering) return;
        demoVideo.src = demoSource + separator + "airo_retry=" + Date.now();
        requestDemoPlayback();
      }, 250);
    }

    function recoverDemo(kind) {
      if (!demoStarted || demoRecovering) return true;
      if (demoRecoveryAttempts >= 1) return false;

      demoRecoveryAttempts += 1;
      demoRecovering = true;
      setDemoStatus("Connection interrupted. Retrying live stream automatically...", "recovering");
      clearDemoRecoveryTimer();
      demoRecoveryTimer = window.setTimeout(function () {
        if (!demoStarted || !demoRecovering) return;
        failDemo("The live sample is unavailable or blocked in this region.");
      }, 8000);

      if (demoHls) {
        try {
          if (kind === "network") {
            demoHls.startLoad(-1);
          } else {
            demoHls.recoverMediaError();
          }
          requestDemoPlayback();
        } catch (_error) {
          failDemo("The live sample could not recover automatically.");
        }
        return true;
      }

      if (demoUsesNativeHls) {
        retryNativeDemo();
        return true;
      }

      return false;
    }

    demoButton.addEventListener("click", function () {
      var source = demoButton.getAttribute("data-live-source");
      if (!source || demoStarted) return;

      liveDemoInstances.forEach(function (instance) {
        if (instance.root !== root) instance.stopForSwitch();
      });
      if (startWithSound) {
        demoVideo.defaultMuted = false;
        demoVideo.muted = false;
        demoVideo.volume = 1;
      }
      demoStarted = true;
      demoSource = source;
      demoRecoveryAttempts = 0;
      demoRecovering = false;
      demoButton.disabled = true;
      setDemoStatus("Connecting directly to the third-party live stream...", "loading");
      clearDemoRecoveryTimer();
      demoRecoveryTimer = window.setTimeout(function () {
        if (!demoStarted || demoVideo.currentTime > 0 || demoRecovering) return;
        if (!recoverDemo("network")) {
          failDemo("The live sample did not respond in time.");
        }
      }, 8000);

      if (demoVideo.canPlayType("application/vnd.apple.mpegurl")) {
        demoUsesNativeHls = true;
        demoVideo.src = source;
        requestDemoPlayback();
        return;
      }

      if (window.Hls && window.Hls.isSupported()) {
        demoHls = new window.Hls({
          capLevelToPlayerSize: true,
          backBufferLength: 20,
          maxBufferLength: 12,
          maxMaxBufferLength: 24,
        });
        demoHls.on(window.Hls.Events.ERROR, function (_event, data) {
          if (!data.fatal || demoRecovering) return;
          var kind = data.type === window.Hls.ErrorTypes.NETWORK_ERROR ? "network" : "media";
          if (!recoverDemo(kind)) {
            failDemo("The live sample is unavailable or blocked in this region.");
          }
        });
        demoHls.loadSource(source);
        demoHls.attachMedia(demoVideo);
        requestDemoPlayback();
        return;
      }

      failDemo("This browser cannot play the live HLS sample.");
    });

    demoVideo.addEventListener("playing", function () {
      clearDemoRecoveryTimer();
      demoRecovering = false;
      demoStart.hidden = true;
      setDemoStatus("Playing " + channelName + " live through the browser.", "playing");
    });
    demoVideo.addEventListener("canplay", function () {
      if (!demoStarted || !demoVideo.paused) return;
      requestDemoPlayback();
    });
    demoVideo.addEventListener("waiting", function () {
      if (demoRecovering) return;
      setDemoStatus("The live stream is buffering...", "loading");
    });
    demoVideo.addEventListener("error", function () {
      if (!demoStarted) return;
      if (!recoverDemo("media")) {
        failDemo("The live sample could not be played.");
      }
    });

    document.addEventListener("visibilitychange", function () {
      if (!demoStarted) return;
      if (document.hidden) {
        demoVideo.pause();
        if (demoHls) demoHls.stopLoad();
        setDemoStatus("Paused because this tab is hidden.", "paused");
      } else if (demoHls) {
        demoHls.startLoad(-1);
        setDemoStatus("Stream ready. Press the video Play control to continue.", "ready");
      }
    });

    return {
      root: root,
      destroy: destroyDemoStream,
      stopForSwitch: function () {
        if (!demoStarted) return;
        destroyDemoStream();
        restoreDemoUi(false);
      },
    };
  }

  document.querySelectorAll("[data-live-demo]").forEach(function (root) {
    var instance = initializeLiveDemo(root);
    if (instance) liveDemoInstances.push(instance);
  });

  window.addEventListener("pagehide", function () {
    liveDemoInstances.forEach(function (instance) {
      instance.destroy();
    });
  });

  if (window.lucide) window.lucide.createIcons();
})();
