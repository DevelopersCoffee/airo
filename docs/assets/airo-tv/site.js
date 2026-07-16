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

  var demoVideo = document.querySelector("[data-live-demo-video]");
  var demoStart = document.querySelector("[data-live-demo-start]");
  var demoButton = document.querySelector("[data-live-demo-button]");
  var demoStatus = document.querySelector("[data-live-demo-status]");
  var demoHls = null;
  var demoStarted = false;

  function setDemoStatus(message, state) {
    if (!demoStatus) return;
    demoStatus.textContent = message;
    demoStatus.setAttribute("data-state", state || "ready");
  }

  function destroyDemoStream() {
    if (demoHls) {
      demoHls.destroy();
      demoHls = null;
    }
    if (demoVideo) {
      demoVideo.pause();
      demoVideo.removeAttribute("src");
      demoVideo.load();
    }
    demoStarted = false;
  }

  function resetDemoAfterFailure() {
    destroyDemoStream();
    if (demoStart) demoStart.hidden = false;
    if (demoButton) {
      demoButton.disabled = false;
      demoButton.innerHTML = '<i data-lucide="rotate-cw" aria-hidden="true"></i> Try live sample again';
      if (window.lucide) window.lucide.createIcons();
    }
  }

  if (demoVideo && demoStart && demoButton && demoStatus) {
    demoButton.addEventListener("click", function () {
      var source = demoButton.getAttribute("data-live-source");
      if (!source || demoStarted) return;

      demoStarted = true;
      demoButton.disabled = true;
      setDemoStatus("Connecting directly to the third-party live stream...", "loading");

      function requestPlayback() {
        var playRequest = demoVideo.play();
        if (playRequest) {
          playRequest
            .then(function () {
              demoStart.hidden = true;
            })
            .catch(function () {
              if (!demoStarted) return;
              demoStart.hidden = true;
              setDemoStatus("Stream ready. Press the video Play control to continue.", "ready");
            });
        }
      }

      if (demoVideo.canPlayType("application/vnd.apple.mpegurl")) {
        demoVideo.src = source;
        requestPlayback();
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
          if (!data.fatal) return;
          setDemoStatus("The live sample is unavailable or blocked in this region.", "error");
          resetDemoAfterFailure();
        });
        demoHls.loadSource(source);
        demoHls.attachMedia(demoVideo);
        requestPlayback();
        return;
      }

      setDemoStatus("This browser cannot play the live HLS sample.", "error");
      resetDemoAfterFailure();
    });

    demoVideo.addEventListener("playing", function () {
      demoStart.hidden = true;
      setDemoStatus("Playing YRF Music live through the browser.", "playing");
    });
    demoVideo.addEventListener("waiting", function () {
      setDemoStatus("The live stream is buffering...", "loading");
    });
    demoVideo.addEventListener("error", function () {
      if (!demoStarted) return;
      setDemoStatus("The live sample could not be played.", "error");
      resetDemoAfterFailure();
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
    window.addEventListener("pagehide", destroyDemoStream);
  }

  if (window.lucide) window.lucide.createIcons();
})();
