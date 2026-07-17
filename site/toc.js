/* Filterable API table of contents for library doc pages. */
(function () {
  const root = document.querySelector("[data-toc]");
  if (!root) {
    return;
  }

  const input = root.querySelector("[data-toc-filter]");
  const items = Array.from(root.querySelectorAll("[data-toc-item]"));
  const empty = root.querySelector("[data-toc-empty]");
  const groups = Array.from(root.querySelectorAll("[data-toc-group]"));

  function applyFilter() {
    const q = (input && input.value ? input.value : "").trim().toLowerCase();
    let visible = 0;

    items.forEach(function (li) {
      const name = (li.getAttribute("data-toc-name") || "").toLowerCase();
      const kind = (li.getAttribute("data-toc-kind") || "").toLowerCase();
      const hay = name + " " + kind;
      const show = !q || hay.indexOf(q) !== -1;
      li.hidden = !show;
      if (show) {
        visible += 1;
      }
    });

    groups.forEach(function (g) {
      const any = Array.from(g.querySelectorAll("[data-toc-item]")).some(
        function (li) {
          return !li.hidden;
        }
      );
      g.hidden = !any;
    });

    if (empty) {
      empty.hidden = visible !== 0;
    }
  }

  if (input) {
    input.addEventListener("input", applyFilter);
    input.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") {
        input.value = "";
        applyFilter();
        input.blur();
      }
    });
  }

  applyFilter();
})();
