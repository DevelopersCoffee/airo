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

  if (window.lucide) window.lucide.createIcons();
})();
