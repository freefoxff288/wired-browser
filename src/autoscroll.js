// Автопрокрутка как в Windows: нажать колесо и вести мышь. Клик или отпускание после движения — стоп.
(() => {
    if (window.__wiredAutoscroll) return; window.__wiredAutoscroll = true;
    let on = false, ox = 0, oy = 0, mx = 0, my = 0, moved = false, target = null, mark = null, raf = 0;

    const scrollable = el => {
        for (; el && el !== document.body && el !== document.documentElement; el = el.parentElement) {
            const s = getComputedStyle(el);
            if ((/(auto|scroll)/.test(s.overflowY) && el.scrollHeight > el.clientHeight) ||
                (/(auto|scroll)/.test(s.overflowX) && el.scrollWidth > el.clientWidth)) return el;
        }
        return document.scrollingElement || document.documentElement;
    };
    const speed = d => Math.sign(d) * Math.max(0, Math.abs(d) - 12) ** 1.35 / 18;   // мёртвая зона 12px

    function stop() {
        on = false; cancelAnimationFrame(raf);
        if (mark) mark.remove(); mark = null;
    }
    function tick() {
        if (!on) return;
        target.scrollBy(speed(mx - ox), speed(my - oy));
        if (mark) {
            const dy = my - oy, dx = mx - ox;
            mark.textContent = Math.abs(dy) < 12 && Math.abs(dx) < 12 ? "✦" : Math.abs(dy) >= Math.abs(dx) ? (dy > 0 ? "▼" : "▲") : (dx > 0 ? "▶" : "◀");
        }
        raf = requestAnimationFrame(tick);
    }
    addEventListener("mousedown", e => {
        if (on) { stop(); e.preventDefault(); e.stopPropagation(); return; }
        if (e.button !== 1) return;
        if (e.target.closest("a[href], input, textarea, select, [contenteditable=''], [contenteditable=true]")) return;
        e.preventDefault(); e.stopPropagation();
        on = true; moved = false; ox = mx = e.clientX; oy = my = e.clientY; target = scrollable(e.target);
        mark = document.createElement("div");
        mark.setAttribute("style", `position:fixed;left:${ox - 18}px;top:${oy - 18}px;width:36px;height:36px;z-index:2147483647;
            pointer-events:none;border-radius:50%;border:1.5px solid #6898f7;background:rgba(5,11,36,.75);
            box-shadow:0 0 14px rgba(104,152,247,.55);display:grid;place-items:center;
            font:12px monospace;color:#8eb4fb;transition:transform .12s`);
        mark.textContent = "✦";
        document.documentElement.appendChild(mark);
        raf = requestAnimationFrame(tick);
    }, true);
    addEventListener("mousemove", e => { if (!on) return; mx = e.clientX; my = e.clientY; if (Math.hypot(mx - ox, my - oy) > 8) moved = true; }, true);
    addEventListener("mouseup", e => { if (on && e.button === 1 && moved) stop(); }, true);
    addEventListener("auxclick", e => { if (e.button === 1 && (on || moved)) e.preventDefault(); }, true);
    addEventListener("keydown", () => on && stop(), true);
    addEventListener("wheel", () => on && stop(), true);
    addEventListener("blur", () => on && stop());
})();
