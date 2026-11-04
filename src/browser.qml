// Wired Browser — браузер на Chromium (QtWebEngine) в стиле Wired.
// Без паролей, закладок и истории: вкладки (закрепление, дублирование), загрузки, поиск по странице, темы, настройки.
// Клавиши: Ctrl+T/W — вкладка, Ctrl+Tab — следующая, Ctrl+L — адрес, Ctrl+F — поиск, Ctrl+±/0 — масштаб,
//          F5/Ctrl+R — обновить, Alt+←/→ — назад/вперёд, F11 — полный экран, Ctrl+J — загрузки, Ctrl+, — настройки.
import QtQuick
import QtQuick.Window
import QtCore
import QtWebEngine

Window {
    id: win
    width: 1480; height: 920; minimumWidth: 640; minimumHeight: 420
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: pal.bg
    title: (view && view.kind === "settings" ? "Настройки — " : view && view.title ? view.title + " — " : "") + "Wired"

    FontLoader { id: fira; source: Qt.resolvedUrl("fonts/FiraCodeNerdFontMono-Regular.ttf") }
    readonly property string mono: fira.status === FontLoader.Ready ? fira.font.family : "FiraCode Nerd Font Mono"
    Timer { id: smoke; interval: 8000; onTriggered: { console.log("SMOKE OK", tabs.count, win.mono); Qt.quit(); } }   // проверка сборки в CI
    readonly property bool windows: Qt.platform.os === "windows"
    // url → путь и обратно: Linux file:///home/x ↔ /home/x, Windows file:///C:/x ↔ C:/x
    function localPath(u) { const p = decodeURIComponent(u.toString().replace(/^file:\/\//, "")); return /^\/[A-Za-z]:/.test(p) ? p.slice(1) : p; }
    function fileUrl(p) { return "file://" + (p.startsWith("/") ? "" : "/") + p; }
    readonly property string home: localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string dlDir: cfg.downloadDir || localPath(StandardPaths.writableLocation(StandardPaths.DownloadLocation))
    readonly property var engines: [
        { id: "google", name: "Google", url: "https://www.google.com/search?q=" },
        { id: "duck", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
        { id: "yandex", name: "Яндекс", url: "https://yandex.ru/search/?text=" },
        { id: "bing", name: "Bing", url: "https://www.bing.com/search?q=" },
        { id: "brave", name: "Brave", url: "https://search.brave.com/search?q=" }
    ]
    readonly property string searchUrl: (engines.find(e => e.id === cfg.engine) || engines[0]).url
    property var view: null                // активный WebEngineView
    property int cur: 0
    property bool fs: false
    readonly property bool maxed: visibility === Window.Maximized || fs

    // ── настройки (всё сохраняется в ~/.config/wired-browser.conf) ──
    Settings {
        id: cfg
        location: win.windows ? StandardPaths.writableLocation(StandardPaths.AppConfigLocation) + "/wired-browser.conf"
                              : win.fileUrl(win.home + "/.config/wired-browser.conf")
        property string theme: "wired"
        property string engine: "google"
        property string links: JSON.stringify([["YouTube", "youtube.com"], ["GitHub", "github.com"], ["Wikipedia", "ru.wikipedia.org"], ["Reddit", "reddit.com"], ["Twitch", "twitch.tv"]])
        property string pinned: "[]"
        property string session: "[]"
        property string startup: "new"           // new | restore
        property bool autoscroll: true
        property bool animTabs: true
        property bool animTheme: true
        property bool ntpWires: true
        property bool ntpClock: true
        property bool ntpWidgets: true
        property bool ntpLinks: true
        property string greeting: "connect to the wired..."
        property real zoom: 1.0
        property string downloadDir: ""
    }
    property var links: JSON.parse(cfg.links)
    function saveLinks(l) { links = l; cfg.links = JSON.stringify(l); }

    // ── темы ──
    readonly property var themes: [
        { id: "wired",   name: "WIRED",   bg: "#050b24", panel: "#0b1233", head: "#0e1640", btn: "#16215a", text: "#dce6ff", dim: "#5f78b8", acc: "#6898f7", light: "#8eb4fb", sel: "#3056e0" },
        { id: "psyche",  name: "PSYCHE",  bg: "#120306", panel: "#1d070b", head: "#280a10", btn: "#3d1018", text: "#ffe1e5", dim: "#b0606c", acc: "#e8607e", light: "#ff9aae", sel: "#b3263f" },
        { id: "navi",    name: "NAVI",    bg: "#020a05", panel: "#06140b", head: "#0a1d10", btn: "#0f2c18", text: "#d4ffe2", dim: "#4f9a68", acc: "#6fcfa8", light: "#a6f0c8", sel: "#1f8a55" },
        { id: "copland", name: "COPLAND", bg: "#0d0904", panel: "#170f06", head: "#21160a", btn: "#33220e", text: "#ffecd0", dim: "#a7834f", acc: "#e8a14a", light: "#ffc77d", sel: "#b56d16" },
        { id: "knights", name: "KNIGHTS", bg: "#0a0614", panel: "#130b24", head: "#1a1033", btn: "#2a1a52", text: "#ece2ff", dim: "#8a74c4", acc: "#a98bff", light: "#cbb8ff", sel: "#6a44e0" }
    ]
    function setTheme(id) { if (id === cfg.theme) return; cfg.theme = id; if (cfg.animTheme) themeFx.restart(); }
    Item {   // текущая палитра; цвета перетекают при смене темы
        id: pal
        readonly property var p: win.themes.find(t => t.id === cfg.theme) || win.themes[0]
        property color bg: p.bg;       Behavior on bg { ColorAnimation { duration: 700 } }
        property color panel: p.panel; Behavior on panel { ColorAnimation { duration: 700 } }
        property color head: p.head;   Behavior on head { ColorAnimation { duration: 700 } }
        property color btn: p.btn;     Behavior on btn { ColorAnimation { duration: 700 } }
        property color text: p.text;   Behavior on text { ColorAnimation { duration: 700 } }
        property color dim: p.dim;     Behavior on dim { ColorAnimation { duration: 700 } }
        property color acc: p.acc;     Behavior on acc { ColorAnimation { duration: 700 } }
        property color light: p.light; Behavior on light { ColorAnimation { duration: 700 } }
        property color sel: p.sel;     Behavior on sel { ColorAnimation { duration: 700 } }
    }

    // ── профиль: куки и кэш живут между запусками, паролей нет ──
    WebEngineProfilePrototype {
        id: proto
        storageName: "wired"
        persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
        httpCacheType: WebEngineProfile.DiskHttpCache
    }
    // загрузки: подключаемся напрямую — Connections { target: proto.instance() } в Qt 6.12 сигнал не получает,
    // и непринятая загрузка молча отменяется
    function onDownload(d) {
        d.downloadDirectory = win.dlDir;
        d.accept();
        win.dls = win.dls.concat([d]);           // всплывашки
        win.dlAll = [d].concat(win.dlAll);       // список в панели загрузок (только эта сессия)
    }
    property var dls: []
    property var dlAll: []
    readonly property var dlActive: dlAll.filter(d => d.state === WebEngineDownloadRequest.DownloadInProgress)
    function dlDone(d) { return d.state === WebEngineDownloadRequest.DownloadCompleted; }
    function dlBad(d) { return d.state === WebEngineDownloadRequest.DownloadCancelled || d.state === WebEngineDownloadRequest.DownloadInterrupted; }
    function mb(b) { return (b / 1048576).toFixed(b < 10485760 ? 1 : 0); }

    // автопрокрутка колесом: скрипт в каждую страницу (изменение действует на новые загрузки)
    function applyScripts() {
        const c = proto.instance().userScripts; c.clear();
        if (!cfg.autoscroll) return;
        const s = WebEngine.script();
        s.name = "wired-autoscroll";
        s.sourceUrl = Qt.resolvedUrl("autoscroll.js");
        s.injectionPoint = WebEngineScript.DocumentReady;
        s.worldId = WebEngineScript.ApplicationWorld;
        s.runsOnSubFrames = true;
        c.insert(s);
    }
    Connections { target: cfg; function onAutoscrollChanged() { win.applyScripts(); } }

    // ── вкладки ──
    ListModel { id: tabs }      // {title, icon, loading, pinned, kind: web|settings}
    property int pinnedCount: 0      // ListModel.get() не реактивен — пересчитываем вручную
    function recount() { let n = 0; for (let i = 0; i < tabs.count; i++) if (tabs.get(i).pinned) n++; pinnedCount = n; }
    function newTab(url, background, at, kind) {
        const i = at === undefined || at < 0 ? tabs.count : at;
        tabs.insert(i, { title: kind === "settings" ? "SETTINGS" : "NEW LAYER", icon: "", loading: false, pinned: false, kind: kind || "web" });
        if (i <= cur && tabs.count > 1) cur++;      // текущая вкладка сдвинулась
        const v = views.itemAt(i);
        if (url) v.url = url;
        if (!background) { cur = i; if (!url && !kind) Qt.callLater(() => ntpSearch.forceActiveFocus()); }
        return v;
    }
    function closeTab(i) {
        if (tabs.count === 1) { win.close(); return; }
        tabs.remove(i);
        if (i < cur || cur >= tabs.count) cur = Math.max(0, cur - 1);
        recount(); savePinned();
        if (cfg.animTabs) switchFx.restart();
    }
    function moveTab(i, j) {
        if (i === j) return;
        tabs.move(i, j, 1);
        if (cur === i) cur = j;
        else if (i < cur && j >= cur) cur--;
        else if (i > cur && j <= cur) cur++;
    }
    function setPinned(i, on) {
        tabs.setProperty(i, "pinned", on);
        let j = 0; for (let k = 0; k < tabs.count; k++) if (k !== i && tabs.get(k).pinned) j++;   // закреплённые — слева
        moveTab(i, j);
        recount(); savePinned();
    }
    function duplicate(i) {
        const v = views.itemAt(i);
        if (tabs.get(i).kind === "settings") return;
        const n = newTab(v.blank ? "" : v.url.toString(), false, i + 1);
        n.zoomFactor = v.zoomFactor;
    }
    function urlOf(i) { const v = views.itemAt(i); return v && !v.blank ? v.url.toString() : ""; }
    function savePinned() {
        const l = []; for (let i = 0; i < tabs.count; i++) if (tabs.get(i).pinned && urlOf(i)) l.push(urlOf(i));
        cfg.pinned = JSON.stringify(l);
    }
    function openSettings() {
        for (let i = 0; i < tabs.count; i++) if (tabs.get(i).kind === "settings") { cur = i; return; }
        newTab("", false, -1, "settings");
    }
    function go(text) {
        let t = text.trim(); if (!t) return;
        const isUrl = /^[a-z]+:\/\//i.test(t) || /^[^\s]+\.[a-z]{2,}(\/|:|$)/i.test(t) || /^localhost(:\d+)?/.test(t);
        if (view.kind === "settings") { newTab("", false); }
        view.url = isUrl ? (/^[a-z]+:\/\//i.test(t) ? t : "https://" + t) : searchUrl + encodeURIComponent(t);
        view.forceActiveFocus();
    }
    onCurChanged: if (cfg.animTabs) switchFx.restart()
    onClosing: {
        savePinned();
        const s = []; for (let i = 0; i < tabs.count; i++) if (!tabs.get(i).pinned && urlOf(i)) s.push(urlOf(i));
        cfg.session = JSON.stringify(s);
    }

    Component.onCompleted: {
        proto.instance().downloadRequested.connect(onDownload);
        applyScripts();
        for (const u of JSON.parse(cfg.pinned)) { newTab(u, true); tabs.setProperty(tabs.count - 1, "pinned", true); }
        recount();
        if (cfg.startup === "restore") for (const u of JSON.parse(cfg.session)) newTab(u, true);
        const a = Qt.application.arguments, i = a.indexOf("--");   // qml-раннер: после «--»; exe: после имени программы
        const url = (i >= 0 ? a.slice(i + 1) : a.slice(1)).find(s => s && !s.startsWith("-") && !s.endsWith(".qml")) || "";
        if (a.indexOf("--smoke") >= 0) smoke.start();
        if (url || tabs.count === pinnedCount) newTab(url || "", false);
        else cur = tabs.count - 1;
    }

    // ── горячие клавиши ──
    Shortcut { sequence: "Ctrl+T"; onActivated: win.newTab("", false) }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.cur) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: win.cur = (win.cur + 1) % tabs.count }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: win.cur = (win.cur - 1 + tabs.count) % tabs.count }
    Shortcut { sequence: "Ctrl+L"; onActivated: { addr.forceActiveFocus(); addr.selectAll(); } }
    Shortcut { sequence: "Ctrl+F"; onActivated: finder.show() }
    Shortcut { sequence: "Ctrl+J"; onActivated: dlPanel.visible = !dlPanel.visible }
    Shortcut { sequence: "Ctrl+,"; onActivated: win.openSettings() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: win.view.reload() }
    Shortcut { sequence: "Alt+Left"; onActivated: win.view.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: win.view.goForward() }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: win.view.zoomFactor = Math.min(3, win.view.zoomFactor + 0.1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: win.view.zoomFactor = Math.max(0.3, win.view.zoomFactor - 0.1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: win.view.zoomFactor = cfg.zoom }
    Shortcut { sequence: "F11"; onActivated: { win.fs = !win.fs; win.fs ? win.showFullScreen() : win.showNormal(); } }
    Shortcut { sequence: "Escape"; enabled: finder.visible || menu.visible || dlPanel.visible || linkEd.visible
               onActivated: { finder.hide(); menu.visible = false; dlPanel.visible = false; linkEd.visible = false; } }

    // ── общие кусочки ──
    component Glyph: Text { font.family: win.mono; color: pal.text; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter }
    component Btn: Rectangle {   // квадратная кнопка панели
        id: b
        property string glyph; property bool on: true; property color tint: pal.text; signal hit()
        width: 34; height: 30; radius: 7
        color: bma.pressed ? pal.sel : bma.containsMouse ? pal.btn : "transparent"
        opacity: on ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 120 } }
        Glyph { anchors.centerIn: parent; text: b.glyph; font.pixelSize: 16; color: b.tint }
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; enabled: b.on; cursorShape: Qt.PointingHandCursor; onClicked: b.hit() }
    }
    component Chip: Rectangle {  // кнопка-плашка с текстом
        id: c
        property string label; property bool active: false; signal hit()
        width: cl.implicitWidth + 26; height: 32; radius: 8
        color: c.active ? Qt.alpha(pal.sel, 0.45) : cma.containsMouse ? pal.btn : Qt.alpha(pal.panel, 0.8)
        border.width: 1; border.color: Qt.alpha(pal.acc, c.active ? 0.9 : cma.containsMouse ? 0.6 : 0.2)
        Behavior on color { ColorAnimation { duration: 150 } }
        Text { id: cl; anchors.centerIn: parent; text: c.label; color: c.active ? pal.text : pal.dim; font.family: win.mono; font.pixelSize: 13 }
        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.hit() }
    }
    component Field: Rectangle {  // поле ввода
        id: f
        property alias text: fi.text
        property string hint
        property alias input: fi
        signal done()
        signal accepted()
        width: 300; height: 34; radius: 8
        color: pal.bg; border.width: 1; border.color: fi.activeFocus ? pal.acc : Qt.alpha(pal.acc, 0.25)
        TextInput {
            id: fi; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
            font.family: win.mono; font.pixelSize: 13; color: pal.text; selectionColor: pal.sel; selectByMouse: true
            onEditingFinished: f.done()
            onAccepted: f.accepted()
            Text { visible: !parent.text; text: f.hint; color: Qt.alpha(pal.dim, 0.7); font: parent.font }
        }
    }
    component Toggle: Item {      // переключатель-строка
        id: t
        property string label; property bool checked; signal toggled(bool v)
        width: parent ? parent.width : 400; height: 36
        Text { anchors.verticalCenter: parent.verticalCenter; text: t.label; color: pal.text; font.family: win.mono; font.pixelSize: 14 }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 24; radius: 12
            color: t.checked ? Qt.alpha(pal.sel, 0.8) : pal.bg; border.width: 1; border.color: Qt.alpha(pal.acc, t.checked ? 0.9 : 0.35)
            Behavior on color { ColorAnimation { duration: 180 } }
            Rectangle {
                width: 16; height: 16; radius: 8; y: 4; x: t.checked ? 26 : 4
                color: t.checked ? pal.text : pal.dim
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
    }

    // ══════════ ВЕРХНЯЯ ПАНЕЛЬ: вкладки + окно ══════════
    Rectangle {
        id: topBar
        width: parent.width; height: win.fs ? 0 : 42; clip: true
        color: pal.bg
        MouseArea {   // перетаскивание окна за пустое место
            anchors.fill: parent
            onPressed: win.startSystemMove()
            onDoubleClicked: win.maxed ? win.showNormal() : win.showMaximized()
        }
        Glyph { x: 14; height: parent.height; text: "✦"; font.pixelSize: 18; color: pal.acc
            SequentialAnimation on opacity { loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 1800; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine } } }

        ListView {
            id: tabBar
            x: 40; y: 6; height: 36; width: parent.width - x - right.width - 70
            orientation: ListView.Horizontal; spacing: 4; interactive: false
            model: tabs
            currentIndex: win.cur
            function slotAt(x) {
                let acc = 0;
                for (let k = 0; k < tabs.count; k++) {
                    const w = tabs.get(k).pinned ? 44 : normalW;
                    if (x < acc + w + 2) return k;
                    acc += w + spacing;
                }
                return tabs.count - 1;
            }
            readonly property real normalW: Math.max(110, Math.min(230, (width - win.pinnedCount * 48) / Math.max(1, tabs.count - win.pinnedCount) - 4))
            delegate: Item {
                id: tab
                required property int index
                required property string title
                required property string icon
                required property bool loading
                required property bool pinned
                required property string kind
                readonly property bool active: index === win.cur
                width: pinned ? 44 : tabBar.normalW; height: 36
                z: tma.dragging ? 10 : 0
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors.fill: parent; anchors.bottomMargin: -8; radius: 9
                    color: tma.dragging ? pal.btn : tab.active ? pal.panel : tma.containsMouse ? Qt.alpha(pal.btn, 0.6) : "transparent"
                    border.width: tab.active || tma.dragging ? 1 : 0; border.color: Qt.alpha(pal.acc, tma.dragging ? 1 : 0.45)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                Rectangle {   // светящаяся полоска активной вкладки
                    x: 10; y: 0; height: 2; radius: 1; width: tab.active ? parent.width - 20 : 0; color: pal.acc
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
                Rectangle {   // метка закреплённой вкладки
                    visible: tab.pinned; anchors.horizontalCenter: parent.horizontalCenter; y: 31; width: 4; height: 4; radius: 2; color: pal.acc
                }
                Image { x: tab.pinned ? 14 : 12; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16
                        source: tab.icon; visible: !tab.loading && tab.icon !== ""; sourceSize: Qt.size(32, 32) }
                Glyph { x: tab.pinned ? 12 : 10; anchors.verticalCenter: parent.verticalCenter; width: 20; font.pixelSize: 13; color: pal.acc
                        visible: tab.loading || tab.icon === ""
                        text: tab.loading ? "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[spin.f % 10] : tab.kind === "settings" ? "󰒓" : "◇"
                        Timer { id: spin; property int f: 0; interval: 80; repeat: true; running: tab.loading; onTriggered: f++ } }
                Text {
                    visible: !tab.pinned
                    x: 36; width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter
                    text: tab.title; elide: Text.ElideRight; font.pixelSize: 13; font.family: win.mono
                    color: tab.active ? pal.text : pal.dim
                }
                Glyph { id: xBtn; anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20; text: "✕"; font.pixelSize: 11; color: xma.containsMouse ? "#e8607e" : pal.dim
                        visible: !tab.pinned; opacity: tab.active || tma.containsMouse ? 1 : 0 }
                MouseArea {
                    id: tma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    property real pressX: 0
                    property bool dragging: false
                    onPressed: m => { pressX = m.x; dragging = false; if (m.button === Qt.LeftButton) win.cur = tab.index; }
                    onPositionChanged: m => {   // перетаскивание: вкладка встаёт на место, над которым курсор
                        if (!(m.buttons & Qt.LeftButton) || (!dragging && Math.abs(m.x - pressX) < 8)) return;
                        dragging = true;
                        let j = tabBar.slotAt(tma.mapToItem(tabBar, m.x, 0).x);
                        j = tab.pinned ? Math.min(j, win.pinnedCount - 1) : Math.max(j, win.pinnedCount);   // не смешивать группы
                        if (j !== tab.index) win.moveTab(tab.index, j);
                    }
                    onReleased: dragging = false
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton) { if (!tab.pinned) win.closeTab(tab.index); }
                        else if (m.button === Qt.RightButton) {
                            const i = tab.index, p = tab.mapToItem(win.contentItem, m.x, m.y), web = tab.kind === "web";
                            menu.popup([
                                [tab.pinned ? "󰐄  Открепить" : "󰐃  Закрепить", () => win.setPinned(i, !tab.pinned), web],
                                ["󰆑  Дублировать", () => win.duplicate(i), web],
                                ["󰋜  Добавить на главную", () => linkEd.open(-1, tab.title, win.urlOf(i)), web && !!win.urlOf(i)],
                                ["󰑐  Обновить", () => views.itemAt(i).reload(), web],
                                null,
                                ["✕  Закрыть", () => win.closeTab(i)],
                                ["✕  Закрыть другие", () => { for (let k = tabs.count - 1; k >= 0; k--) if (k !== i && !tabs.get(k).pinned) win.closeTab(k); }, tabs.count > 1]
                            ], p.x, p.y);
                        }
                    }
                }
                MouseArea { id: xma; anchors.fill: xBtn; hoverEnabled: true; enabled: !tab.pinned; onClicked: win.closeTab(tab.index) }
            }
            // появление и закрытие вкладок — глитч
            add: Transition {
                NumberAnimation { property: "scale"; from: 0.2; to: 1; duration: 260; easing.type: Easing.OutBack }
                SequentialAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 60 }
                    NumberAnimation { property: "opacity"; to: 0.3; duration: 40 } NumberAnimation { property: "opacity"; to: 1; duration: 60 } }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 160 }
                NumberAnimation { property: "scale"; to: 0.6; duration: 160 }
            }
            // прерванное появление не должно оставлять вкладку прозрачной
            move: Transition { NumberAnimation { properties: "x"; duration: 260; easing.type: Easing.OutCubic } NumberAnimation { properties: "opacity,scale"; to: 1; duration: 120 } }
            displaced: Transition { NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutCubic } NumberAnimation { properties: "opacity,scale"; to: 1; duration: 120 } }
        }
        Btn { x: tabBar.x + Math.min(tabBar.contentWidth, tabBar.width) + 6; y: 6; glyph: "+"; onHit: win.newTab("", false) }

        Row {
            id: right
            anchors.right: parent.right; anchors.rightMargin: 8; y: 6; spacing: 2
            Rectangle {   // переключатель тем
                width: themeLbl.implicitWidth + 30; height: 30; radius: 7
                color: thma.containsMouse || themes_.visible ? pal.btn : "transparent"
                Row { anchors.centerIn: parent; spacing: 7
                    Rectangle { width: 9; height: 9; radius: 5; color: pal.acc; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: themeLbl; text: pal.p.name; color: pal.dim; font.family: win.mono; font.pixelSize: 12; font.letterSpacing: 2 } }
                MouseArea { id: thma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: themes_.visible = !themes_.visible }
            }
            Btn { glyph: "󰒓"; onHit: win.openSettings() }
            Item { width: 10; height: 1 }
            Btn { glyph: "─"; onHit: win.showMinimized() }
            Btn { glyph: win.maxed ? "❐" : "□"; onHit: win.maxed ? (win.fs ? (win.fs = false, win.showNormal()) : win.showNormal()) : win.showMaximized() }
            Btn { glyph: "✕"; tint: "#e8607e"; onHit: win.close() }
        }
    }

    // ══════════ НАВИГАЦИЯ ══════════
    Rectangle {
        id: nav
        y: topBar.height; width: parent.width; height: win.fs ? 0 : 46; clip: true
        color: pal.panel
        Row {
            x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Btn { glyph: "󰁍"; on: !!win.view && win.view.canGoBack; onHit: win.view.goBack() }
            Btn { glyph: "󰁔"; on: !!win.view && win.view.canGoForward; onHit: win.view.goForward() }
            Btn { glyph: win.view && win.view.loading ? "✕" : "󰑐"; onHit: win.view.loading ? win.view.stop() : win.view.reload() }
        }
        Rectangle {
            id: addrBox
            x: 130; width: parent.width - 130 - 120; height: 32; anchors.verticalCenter: parent.verticalCenter; radius: 9
            color: pal.bg
            border.width: 1; border.color: addr.activeFocus ? pal.acc : Qt.alpha(pal.acc, 0.25)
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Rectangle {   // свечение при фокусе
                anchors.fill: parent; anchors.margins: -4; radius: 12; color: "transparent"
                border.width: 3; border.color: Qt.alpha(pal.acc, addr.activeFocus ? 0.18 : 0)
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }
            readonly property bool settings: !!win.view && win.view.kind === "settings"
            readonly property string url: settings ? "wired://settings" : win.view && !win.view.blank ? win.view.url.toString() : ""
            Glyph { x: 10; height: parent.height; font.pixelSize: 13
                    text: addrBox.settings ? "󰒓" : addrBox.url.startsWith("https") ? "󰌾" : addrBox.url ? "󰌿" : "›"
                    color: addrBox.url.startsWith("https") ? "#6fcfa8" : addrBox.settings ? pal.acc : pal.dim }
            TextInput {
                id: addr
                x: 32; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter
                font.family: win.mono; font.pixelSize: 14; color: pal.text; selectionColor: pal.sel; selectedTextColor: "#fff"
                clip: true; selectByMouse: true
                visible: activeFocus
                onActiveFocusChanged: if (activeFocus) { text = addrBox.settings ? "" : addrBox.url; selectAll(); }
                onAccepted: win.go(text)
                Keys.onEscapePressed: win.view.forceActiveFocus()
            }
            Text {   // красивый адрес: хост ярко, остальное приглушённо
                x: 32; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter
                visible: !addr.activeFocus; elide: Text.ElideRight; textFormat: Text.StyledText
                font.family: win.mono; font.pixelSize: 14
                readonly property var m: addrBox.url.match(/^([a-z]+:\/\/)([^\/]*)(.*)$/i)
                text: !addrBox.url ? `<font color="${pal.dim}">поиск или адрес</font>`
                    : m ? `<font color="${pal.dim}">${m[1]}</font><font color="${pal.text}">${m[2]}</font><font color="${pal.dim}">${m[3].replace(/&/g, "&amp;").replace(/</g, "&lt;")}</font>`
                        : addrBox.url
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: addr.forceActiveFocus() }
            }
            Text {   // масштаб, если не по умолчанию
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                visible: !!win.view && Math.abs(win.view.zoomFactor - cfg.zoom) > 0.01
                text: win.view ? Math.round(win.view.zoomFactor * 100) + "%" : ""; color: pal.dim; font.family: win.mono; font.pixelSize: 12
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            Item {   // загрузки: значок + кольцо общего прогресса + число активных
                width: 34; height: 30
                Btn { id: dlBtn; anchors.fill: parent; glyph: "󰇚"; tint: win.dlActive.length ? pal.light : pal.text; onHit: dlPanel.visible = !dlPanel.visible }
                Canvas {
                    id: ring
                    anchors.centerIn: parent; width: 28; height: 28; visible: win.dlActive.length > 0
                    readonly property real frac: { let r = 0, t = 0; for (const d of win.dlActive) { r += d.receivedBytes; t += Math.max(d.totalBytes, d.receivedBytes); } return t ? r / t : 0; }
                    onFracChanged: requestPaint()
                    onVisibleChanged: requestPaint()
                    property real spinA: 0
                    NumberAnimation on spinA { from: 0; to: 2 * Math.PI; duration: 1600; loops: Animation.Infinite; running: ring.visible }
                    onSpinAChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d"); g.reset(); g.lineWidth = 2;
                        g.strokeStyle = Qt.alpha(pal.acc, 0.2); g.beginPath(); g.arc(14, 14, 12, 0, 2 * Math.PI); g.stroke();
                        g.strokeStyle = pal.acc; g.beginPath(); g.arc(14, 14, 12, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(frac, 0.04)); g.stroke();
                        g.fillStyle = pal.light; g.beginPath(); g.arc(14 + 12 * Math.cos(spinA), 14 + 12 * Math.sin(spinA), 1.6, 0, 2 * Math.PI); g.fill();
                    }
                }
                Rectangle {
                    visible: win.dlActive.length > 1; anchors.right: parent.right; y: -2; width: 14; height: 14; radius: 7; color: pal.sel
                    Text { anchors.centerIn: parent; text: win.dlActive.length; color: "#fff"; font.pixelSize: 9; font.bold: true }
                }
            }
        }
        // загрузка страницы: осциллограмма по нижнему краю
        Canvas {
            id: wave
            anchors.bottom: parent.bottom; width: parent.width; height: 8
            property real ph: 0
            property real prog: win.view && win.view.loading ? win.view.loadProgress / 100 : 0
            Behavior on prog { NumberAnimation { duration: 300 } }
            opacity: win.view && win.view.loading ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
            Timer { interval: 33; repeat: true; running: wave.opacity > 0; onTriggered: { wave.ph += 0.35; wave.requestPaint(); } }
            onPaint: {
                const g = getContext("2d"), W = width * prog, H = height;
                g.reset(); g.strokeStyle = pal.acc; g.lineWidth = 1.6; g.beginPath();
                for (let x = 0; x <= W; x += 3) {
                    const y = H / 2 + Math.sin(x / 14 + ph) * 2.2 + (Math.random() - 0.5) * 1.6;
                    x ? g.lineTo(x, y) : g.moveTo(x, y);
                }
                g.stroke();
                g.fillStyle = pal.light; g.fillRect(W - 2, 0, 3, H);
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(pal.acc, 0.15) }
    }

    // ══════════ СОДЕРЖИМОЕ ══════════
    Item {
        id: content
        anchors { top: nav.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true

        Repeater {
            id: views
            model: tabs
            delegate: WebEngineView {
                id: v
                required property int index
                required property bool pinned
                required property string kind
                anchors.fill: parent
                readonly property bool active: index === win.cur
                readonly property bool blank: url.toString() === "" || url.toString() === "about:blank"
                visible: active && !blank && kind === "web"
                profile: proto.instance()
                backgroundColor: pal.bg
                zoomFactor: cfg.zoom
                settings.fullScreenSupportEnabled: true
                settings.scrollAnimatorEnabled: true
                onActiveChanged: if (active) win.view = v
                Component.onCompleted: if (active) win.view = v
                Component.onDestruction: if (win.view === v) win.view = null
                onTitleChanged: tabs.setProperty(index, "title", title || url.toString())
                onIconChanged: tabs.setProperty(index, "icon", icon.toString())
                onLoadingChanged: tabs.setProperty(index, "loading", loading)
                onUrlChanged: if (pinned) win.savePinned()
                onNewWindowRequested: r => r.openIn(win.newTab("", r.destination === WebEngineNewWindowRequest.InNewBackgroundTab))
                onFullScreenRequested: r => { r.accept(); win.fs = r.toggleOn; r.toggleOn ? win.showFullScreen() : win.showNormal(); }
                onContextMenuRequested: r => { r.accepted = true; menu.show(v, r); }
                onFindTextFinished: r => { finder.matches = r.numberOfMatches; finder.at = r.activeMatch; }
                onPermissionRequested: p => perm.ask(p)
            }
        }

        // ── новая вкладка: как виджеты на рабочем столе ──
        Item {
            id: ntp
            property bool feedOk: false
            anchors.fill: parent
            visible: !!win.view && win.view.blank && win.view.kind === "web"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            Canvas {   // фон: медленные «провода»
                id: wires
                anchors.fill: parent
                visible: cfg.ntpWires
                property real t: 0
                Timer { interval: 50; repeat: true; running: ntp.visible && cfg.ntpWires; onTriggered: { wires.t += 0.02; wires.requestPaint(); } }
                onPaint: {
                    const g = getContext("2d"); g.reset();
                    for (let k = 0; k < 7; k++) {
                        g.strokeStyle = Qt.alpha(pal.acc, 0.05 + k * 0.012); g.lineWidth = 1; g.beginPath();
                        for (let x = 0; x <= width; x += 12) {
                            const y = height * (0.18 + k * 0.11) + Math.sin(x / (160 + k * 30) + t * (1 + k * 0.2)) * (30 + k * 6)
                                    + Math.sin(x / 47 + t * 2 + k) * 6;
                            x ? g.lineTo(x, y) : g.moveTo(x, y);
                        }
                        g.stroke();
                    }
                }
            }

            Column {
                anchors.centerIn: parent; anchors.verticalCenterOffset: cfg.ntpWidgets && ntp.feedOk ? -60 : -20
                spacing: 6
                Text {   // часы
                    id: clock
                    visible: cfg.ntpClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: win.mono; font.pixelSize: 92; font.weight: Font.Light; color: pal.text
                    property date now: new Date()
                    Timer { interval: 1000; repeat: true; running: ntp.visible && cfg.ntpClock; triggeredOnStart: true; onTriggered: clock.now = new Date() }
                    text: Qt.formatTime(now, "hh:mm") + `<font color="${pal.dim}">:${Qt.formatTime(now, "ss")}</font>`
                    textFormat: Text.StyledText
                }
                Text {
                    visible: cfg.ntpClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: win.mono; font.pixelSize: 13; font.letterSpacing: 4; color: pal.dim
                    text: Qt.formatDate(clock.now, "yyyy.MM.dd") + "  //  " + Qt.formatDate(clock.now, "dddd").toUpperCase()
                }
                Item { width: 1; height: cfg.ntpClock ? 26 : 0 }
                Rectangle {   // поиск
                    width: Math.min(640, ntp.width - 80); height: 52; radius: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.alpha(pal.panel, 0.9); border.width: 1; border.color: ntpSearch.activeFocus ? pal.acc : Qt.alpha(pal.acc, 0.3)
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                    Glyph { x: 18; height: parent.height; text: "›"; font.pixelSize: 22; color: pal.acc }
                    TextInput {
                        id: ntpSearch
                        x: 44; width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter
                        font.family: win.mono; font.pixelSize: 17; color: pal.text; selectionColor: pal.sel; clip: true
                        onAccepted: { win.go(text); text = ""; }
                        Text { visible: !parent.text; text: cfg.greeting; color: Qt.alpha(pal.dim, 0.7); font: parent.font }
                    }
                }
                Item { width: 1; height: 22 }
                Flow {   // быстрые ссылки: ПКМ — изменить, ✕ — убрать, + — добавить
                    visible: cfg.ntpLinks
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitW, ntp.width - 80); spacing: 10
                    readonly property real implicitW: { let w = 0; for (let i = 0; i < children.length; i++) w += children[i].width + 10; return w; }
                    Repeater {
                        model: win.links
                        Rectangle {
                            id: ql
                            required property var modelData
                            required property int index
                            width: qlt.implicitWidth + 30; height: 32; radius: 8
                            color: qma.containsMouse ? pal.btn : Qt.alpha(pal.panel, 0.7)
                            border.width: 1; border.color: Qt.alpha(pal.acc, qma.containsMouse ? 0.7 : 0.2)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { id: qlt; anchors.centerIn: parent; text: ql.modelData[0]; color: pal.text; font.family: win.mono; font.pixelSize: 13 }
                            MouseArea {
                                id: qma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: m => {
                                    if (m.button === Qt.RightButton) {
                                        const p = ql.mapToItem(win.contentItem, m.x, m.y), i = ql.index;
                                        menu.popup([["󰏫  Изменить", () => linkEd.open(i)], ["󰏌  В новой вкладке", () => win.newTab("https://" + ql.modelData[1].replace(/^https?:\/\//, ""), true)],
                                                    null, ["✕  Убрать", () => win.saveLinks(win.links.filter((_, k) => k !== i))]], p.x, p.y);
                                    } else if (m.button === Qt.MiddleButton) win.newTab("https://" + ql.modelData[1].replace(/^https?:\/\//, ""), true);
                                    else win.go(ql.modelData[1]);
                                }
                            }
                            Glyph {   // убрать
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -6; width: 16; height: 16
                                visible: qma.containsMouse || rmA.containsMouse; text: "✕"; font.pixelSize: 9; color: "#e8607e"
                                Rectangle { anchors.fill: parent; z: -1; radius: 8; color: pal.bg; border.width: 1; border.color: Qt.alpha("#e8607e", 0.6) }
                                MouseArea { id: rmA; anchors.fill: parent; hoverEnabled: true; onClicked: win.saveLinks(win.links.filter((_, k) => k !== ql.index)) }
                            }
                        }
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 8
                        color: addA.containsMouse ? pal.btn : "transparent"; border.width: 1; border.color: Qt.alpha(pal.acc, 0.3)
                        Glyph { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: pal.dim }
                        MouseArea { id: addA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: linkEd.open(-1) }
                    }
                }
            }

            // нижние виджеты: осциллограф звука и карта узлов (данные от wired-feed)
            Row {
                visible: cfg.ntpWidgets && ntp.feedOk   // данные только с wired-feed (на Windows его нет)
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 30
                spacing: 18
                component Card: Rectangle {
                    property string label
                    width: 380; height: 130; radius: 12
                    color: Qt.alpha(pal.panel, 0.85); border.width: 1; border.color: Qt.alpha(pal.acc, 0.25)
                    Text { x: 14; y: 10; text: "// " + parent.label; color: pal.dim; font.family: win.mono; font.pixelSize: 11; font.letterSpacing: 2 }
                }
                Card {
                    label: "SCOPE"
                    Canvas {
                        id: scope
                        x: 14; y: 30; width: parent.width - 28; height: parent.height - 42
                        property var w: []
                        Timer {
                            interval: 50; repeat: true; running: ntp.visible && cfg.ntpWidgets
                            onTriggered: {
                                const x = new XMLHttpRequest();
                                x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) {
                                    ntp.feedOk = x.status === 200;
                                    try { scope.w = JSON.parse(x.responseText).w || []; } catch (e) { scope.w = []; } scope.requestPaint(); } };
                                x.open("GET", "http://127.0.0.1:47811/scope"); x.send();
                            }
                        }
                        onPaint: {
                            const g = getContext("2d"), n = w.length, H = height; g.reset();
                            g.strokeStyle = Qt.alpha(pal.acc, 0.15); g.beginPath(); g.moveTo(0, H / 2); g.lineTo(width, H / 2); g.stroke();
                            g.strokeStyle = pal.acc; g.lineWidth = 1.6; g.beginPath();
                            for (let i = 0; i < Math.max(n, 2); i++) {
                                const x = i / Math.max(n - 1, 1) * width, y = H / 2 - (n ? w[i] : 0) * H * 1.6;
                                i ? g.lineTo(x, y) : g.moveTo(x, y);
                            }
                            g.stroke();
                        }
                    }
                }
                Card {
                    label: "NODES"
                    Canvas {
                        id: map
                        x: 14; y: 30; width: parent.width - 28; height: parent.height - 42
                        property var net: ({ nodes: {}, links: [] })
                        Timer {
                            interval: 2000; repeat: true; running: ntp.visible && cfg.ntpWidgets; triggeredOnStart: true
                            onTriggered: {
                                const x = new XMLHttpRequest();
                                x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) {
                                    try { map.net = JSON.parse(x.responseText); } catch (e) {} map.requestPaint(); } };
                                x.open("GET", "http://127.0.0.1:47811/net"); x.send();
                            }
                        }
                        onPaint: {
                            const g = getContext("2d"), ids = Object.keys(net.nodes || {}), pos = {};
                            g.reset();
                            ids.forEach((id, i) => pos[id] = { x: (i + 0.5) / ids.length * width, y: height / 2 + (i % 2 ? 12 : -12) });
                            for (const l of net.links || []) {
                                const a = pos[l.a], b = pos[l.b]; if (!a || !b) continue;
                                g.strokeStyle = l.up ? Qt.alpha(pal.acc, 0.7) : Qt.alpha(pal.dim, 0.3);
                                g.setLineDash(l.up ? [] : [3, 4]); g.beginPath(); g.moveTo(a.x, a.y); g.lineTo(b.x, b.y); g.stroke();
                            }
                            g.setLineDash([]);
                            g.font = "11px '" + win.mono + "'"; g.textAlign = "center";
                            ids.forEach(id => {
                                const n = net.nodes[id], p = pos[id];
                                g.fillStyle = n.up ? pal.acc : pal.dim; g.beginPath(); g.arc(p.x, p.y, 5, 0, 2 * Math.PI); g.fill();
                                g.fillStyle = n.up ? pal.text : pal.dim; g.fillText(n.name || id.slice(0, 7), p.x, p.y + 22);
                            });
                            if (!ids.length) { g.fillStyle = pal.dim; g.fillText("no signal", width / 2, height / 2); }
                        }
                    }
                }
            }
        }

        // ── вкладка настроек ──
        Flickable {
            id: settingsPage
            anchors.fill: parent
            visible: !!win.view && win.view.kind === "settings"
            contentHeight: sCol.implicitHeight + 120; clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            onVisibleChanged: if (visible) { contentY = 0; sIn.restart(); }
            Column {
                id: sCol
                width: Math.min(820, settingsPage.width - 80); x: (settingsPage.width - width) / 2; y: 48
                spacing: 34
                NumberAnimation on y { id: sIn; from: 80; to: 48; duration: 380; easing.type: Easing.OutCubic }

                component Section: Column {
                    id: sec
                    property string label
                    width: sCol.width; spacing: 10
                    Row { spacing: 10
                        Rectangle { width: 3; height: 16; radius: 1; color: pal.acc; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: sec.label; color: pal.dim; font.family: win.mono; font.pixelSize: 12; font.letterSpacing: 3 } }
                }

                Column {
                    spacing: 6
                    Text { text: "// SETTINGS"; color: pal.text; font.family: win.mono; font.pixelSize: 34; font.weight: Font.Light }
                    Text { text: "всё сохраняется сразу"; color: pal.dim; font.family: win.mono; font.pixelSize: 13 }
                }

                Section {
                    label: "ТЕМА"
                    Flow {
                        width: parent.width; spacing: 12
                        Repeater {
                            model: win.themes
                            Rectangle {   // мини-превью темы
                                id: tc
                                required property var modelData
                                readonly property bool on: modelData.id === cfg.theme
                                width: 150; height: 104; radius: 10; color: modelData.bg; clip: true
                                border.width: on ? 2 : 1; border.color: on ? modelData.acc : Qt.alpha(modelData.acc, tcma.containsMouse ? 0.7 : 0.25)
                                scale: tcma.containsMouse ? 1.04 : 1
                                Behavior on scale { NumberAnimation { duration: 150 } }
                                Rectangle { x: 10; y: 10; width: 56; height: 12; radius: 3; color: tc.modelData.panel
                                    Rectangle { width: parent.width - 10; x: 5; height: 2; color: tc.modelData.acc } }
                                Rectangle { x: 10; y: 26; width: parent.width - 20; height: 14; radius: 4; color: tc.modelData.panel }
                                Rectangle { x: 10; y: 46; width: parent.width - 20; height: 1; color: Qt.alpha(tc.modelData.acc, 0.3) }
                                Canvas {
                                    x: 10; y: 50; width: parent.width - 20; height: 22
                                    Component.onCompleted: requestPaint()
                                    onPaint: { const g = getContext("2d"); g.strokeStyle = tc.modelData.acc; g.lineWidth = 1.5; g.beginPath();
                                        for (let x = 0; x <= width; x += 2) { const y = 11 + Math.sin(x / 9) * 6 * Math.sin(x / width * Math.PI); x ? g.lineTo(x, y) : g.moveTo(x, y); } g.stroke(); }
                                }
                                Text { x: 10; y: 78; text: tc.modelData.name; color: tc.modelData.text; font.family: win.mono; font.pixelSize: 12; font.letterSpacing: 2 }
                                Glyph { anchors.right: parent.right; anchors.rightMargin: 10; y: 78; text: "◉"; font.pixelSize: 12; color: tc.modelData.acc; visible: tc.on }
                                MouseArea { id: tcma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.setTheme(tc.modelData.id) }
                            }
                        }
                    }
                }

                Section {
                    label: "АНИМАЦИИ"
                    Toggle { label: "Глитч при смене вкладок"; checked: cfg.animTabs; onToggled: v => cfg.animTabs = v }
                    Toggle { label: "Развёртка при смене темы"; checked: cfg.animTheme; onToggled: v => cfg.animTheme = v }
                    Toggle { label: "Живые «провода» на главной"; checked: cfg.ntpWires; onToggled: v => cfg.ntpWires = v }
                }

                Section {
                    label: "ГЛАВНАЯ"
                    Toggle { label: "Часы и дата"; checked: cfg.ntpClock; onToggled: v => cfg.ntpClock = v }
                    Toggle { label: "Виджеты SCOPE и NODES"; checked: cfg.ntpWidgets; onToggled: v => cfg.ntpWidgets = v }
                    Toggle { label: "Быстрые ссылки"; checked: cfg.ntpLinks; onToggled: v => cfg.ntpLinks = v }
                    Item { width: 1; height: 4 }
                    Text { text: "Текст в строке поиска"; color: pal.text; font.family: win.mono; font.pixelSize: 14 }
                    Field { width: parent.width; text: cfg.greeting; hint: "connect to the wired..."; onDone: cfg.greeting = text || "connect to the wired..." }
                    Item { width: 1; height: 4 }
                    Text { text: "Быстрые ссылки — клик, чтобы изменить"; color: pal.text; font.family: win.mono; font.pixelSize: 14 }
                    Repeater {
                        model: win.links
                        Rectangle {
                            id: lr
                            required property var modelData
                            required property int index
                            width: parent.width; height: 36; radius: 8
                            color: lrma.containsMouse ? pal.btn : Qt.alpha(pal.panel, 0.7)
                            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: lr.modelData[0]; color: pal.text; font.family: win.mono; font.pixelSize: 13 }
                            Text { x: 200; anchors.verticalCenter: parent.verticalCenter; text: lr.modelData[1]; color: pal.dim; font.family: win.mono; font.pixelSize: 13
                                   width: parent.width - 300; elide: Text.ElideRight }
                            MouseArea { id: lrma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: linkEd.open(lr.index) }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                Btn { glyph: "󰁝"; on: lr.index > 0; onHit: { const l = win.links.slice(); l.splice(lr.index - 1, 0, l.splice(lr.index, 1)[0]); win.saveLinks(l); } }
                                Btn { glyph: "󰁅"; on: lr.index < win.links.length - 1; onHit: { const l = win.links.slice(); l.splice(lr.index + 1, 0, l.splice(lr.index, 1)[0]); win.saveLinks(l); } }
                                Btn { glyph: "✕"; tint: "#e8607e"; onHit: win.saveLinks(win.links.filter((_, k) => k !== lr.index)) }
                            }
                        }
                    }
                    Chip { label: "+ добавить ссылку"; onHit: linkEd.open(-1) }
                }

                Section {
                    label: "ПОИСК"
                    Flow { width: parent.width; spacing: 8
                        Repeater { model: win.engines
                            Chip { required property var modelData; label: modelData.name; active: modelData.id === cfg.engine; onHit: cfg.engine = modelData.id } } }
                }

                Section {
                    label: "ПОВЕДЕНИЕ"
                    Toggle { label: "Прокрутка нажатием колеса мыши"; checked: cfg.autoscroll; onToggled: v => cfg.autoscroll = v }
                    Item { width: 1; height: 4 }
                    Text { text: "При запуске открывать"; color: pal.text; font.family: win.mono; font.pixelSize: 14 }
                    Row { spacing: 8
                        Chip { label: "новую вкладку"; active: cfg.startup === "new"; onHit: cfg.startup = "new" }
                        Chip { label: "вкладки прошлого раза"; active: cfg.startup === "restore"; onHit: cfg.startup = "restore" } }
                    Item { width: 1; height: 4 }
                    Text { text: "Масштаб страниц по умолчанию"; color: pal.text; font.family: win.mono; font.pixelSize: 14 }
                    Flow { width: parent.width; spacing: 8
                        Repeater { model: [0.8, 0.9, 1.0, 1.1, 1.25, 1.5]
                            Chip { required property real modelData; label: Math.round(modelData * 100) + "%"; active: Math.abs(cfg.zoom - modelData) < 0.01; onHit: cfg.zoom = modelData } } }
                }

                Section {
                    label: "ЗАГРУЗКИ"
                    Text { text: "Папка (пусто — стандартная «Загрузки»)"; color: pal.text; font.family: win.mono; font.pixelSize: 14 }
                    Row { spacing: 8
                        Field { width: sCol.width - 130; text: cfg.downloadDir; hint: win.dlDir; onDone: cfg.downloadDir = text.trim() }
                        Chip { label: "открыть"; onHit: Qt.openUrlExternally(win.fileUrl(win.dlDir)) } }
                }

                Section {
                    label: "ДАННЫЕ"
                    Row { spacing: 12
                        Chip { id: clr; label: "Очистить кэш"; onHit: { proto.instance().clearHttpCache(); label = "кэш очищен ✓"; } }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "куки и вход на сайтах остаются"; color: pal.dim; font.family: win.mono; font.pixelSize: 12 } }
                }

                Text { text: "WIRED BROWSER · Chromium " + "· let's all love Lain"; color: Qt.alpha(pal.dim, 0.6); font.family: win.mono; font.pixelSize: 11; font.letterSpacing: 2 }
            }
        }

        // ── смена вкладки: короткий глитч ──
        Item {
            id: switchFx
            anchors.fill: parent; visible: false
            function restart() { anim.restart(); }
            Repeater {
                model: 7
                Rectangle {
                    width: parent.width; x: (Math.random() - 0.5) * 40
                    y: Math.random() * parent.height; height: 3 + Math.random() * 26
                    color: index % 3 ? pal.acc : "#e8607e"; opacity: 0.18
                }
            }
            SequentialAnimation {
                id: anim
                PropertyAction { target: switchFx; property: "visible"; value: true }
                PauseAnimation { duration: 90 }
                PropertyAction { target: switchFx; property: "visible"; value: false }
            }
        }

        // ── запрос разрешения от сайта ──
        Rectangle {
            id: perm
            property var p: null
            function ask(x) { if (p) p.deny(); p = x; }
            readonly property var names: ({ 1: "микрофон", 2: "камеру", 3: "камеру и микрофон", 4: "запись экрана", 5: "запись экрана и звука",
                                            6: "захват мыши", 7: "уведомления", 8: "местоположение", 9: "буфер обмена", 10: "шрифты" })
            visible: !!p
            anchors.horizontalCenter: parent.horizontalCenter; y: 12
            width: permRow.implicitWidth + 32; height: 44; radius: 10
            color: pal.panel; border.width: 1; border.color: pal.acc
            Row {
                id: permRow; anchors.centerIn: parent; spacing: 12
                Text { anchors.verticalCenter: parent.verticalCenter; color: pal.text; font.family: win.mono; font.pixelSize: 13
                       text: perm.p ? (perm.p.origin.toString().replace(/^https?:\/\//, "").replace(/\/$/, "") + " просит " + (perm.names[perm.p.permissionType] || "доступ")) : "" }
                Rectangle { width: 92; height: 28; radius: 7; color: am.containsMouse ? pal.sel : pal.btn
                    Text { anchors.centerIn: parent; text: "разрешить"; color: pal.text; font.family: win.mono; font.pixelSize: 12 }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: { perm.p.grant(); perm.p = null; } } }
                Rectangle { width: 92; height: 28; radius: 7; color: dm.containsMouse ? "#5a1a2a" : "transparent"; border.width: 1; border.color: pal.btn
                    Text { anchors.centerIn: parent; text: "отказать"; color: pal.dim; font.family: win.mono; font.pixelSize: 12 }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; onClicked: { perm.p.deny(); perm.p = null; } } }
            }
        }

        // ── поиск по странице ──
        Rectangle {
            id: finder
            property int matches: 0; property int at: 0
            function show() { visible = true; fInput.forceActiveFocus(); fInput.selectAll(); }
            function hide() { if (!visible) return; visible = false; if (win.view) { win.view.findText(""); win.view.forceActiveFocus(); } }
            visible: false
            anchors.right: parent.right; anchors.rightMargin: 16; y: 12
            width: 340; height: 40; radius: 10
            color: pal.panel; border.width: 1; border.color: pal.acc
            Glyph { x: 12; height: parent.height; text: "󰍉"; font.pixelSize: 14; color: pal.acc }
            TextInput {
                id: fInput
                x: 34; width: 210; anchors.verticalCenter: parent.verticalCenter; clip: true
                font.family: win.mono; font.pixelSize: 13; color: pal.text; selectionColor: pal.sel
                onTextChanged: win.view.findText(text)
                Keys.onReturnPressed: e => win.view.findText(text, e.modifiers & Qt.ShiftModifier ? WebEngineView.FindBackward : 0)
                Keys.onEscapePressed: finder.hide()
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                   font.family: win.mono; font.pixelSize: 12; color: finder.matches ? pal.dim : "#e8607e"
                   text: fInput.text ? finder.at + "/" + finder.matches : "" }
        }

        // ── всплывашки загрузок ──
        Column {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16; spacing: 8
            visible: !dlPanel.visible
            Repeater {
                model: win.dls
                Rectangle {
                    id: dl
                    required property var modelData
                    readonly property var d: modelData
                    readonly property bool done: win.dlDone(d)
                    readonly property bool bad: win.dlBad(d)
                    width: 340; height: 58; radius: 10
                    color: pal.panel; border.width: 1; border.color: dl.bad ? "#e8607e" : dl.done ? "#6fcfa8" : Qt.alpha(pal.acc, 0.5)
                    Text { x: 14; y: 9; width: parent.width - 60; elide: Text.ElideMiddle; font.family: win.mono; font.pixelSize: 13; color: pal.text; text: dl.d.downloadFileName }
                    Text { x: 14; y: 30; font.family: win.mono; font.pixelSize: 11; color: pal.dim
                           text: dl.done ? "DONE · клик — открыть" : dl.bad ? "FAILED"
                               : win.mb(dl.d.receivedBytes) + " / " + (dl.d.totalBytes > 0 ? win.mb(dl.d.totalBytes) : "?") + " MB" }
                    Rectangle { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; height: 2; radius: 1; color: dl.done ? "#6fcfa8" : pal.acc
                                width: (parent.width - 28) * (dl.d.totalBytes > 0 ? dl.d.receivedBytes / dl.d.totalBytes : 0) }
                    MouseArea { anchors.fill: parent; cursorShape: dl.done ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: dl.done ? Qt.openUrlExternally(win.fileUrl(dl.d.downloadDirectory + "/" + dl.d.downloadFileName)) : dlPanel.visible = true }
                    Glyph { anchors.right: parent.right; anchors.rightMargin: 12; y: 8; text: "✕"; font.pixelSize: 11; color: pal.dim
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: win.dls = win.dls.filter(x => x !== dl.d) } }
                    Timer { running: dl.done || dl.bad; interval: 6000; onTriggered: win.dls = win.dls.filter(x => x !== dl.d) }
                    NumberAnimation on x { from: 360; to: 0; duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // ══════════ ПАНЕЛЬ ЗАГРУЗОК ══════════
    MouseArea { anchors.fill: parent; visible: dlPanel.visible; onPressed: dlPanel.visible = false }
    Rectangle {
        id: dlPanel
        visible: false
        anchors.right: parent.right; anchors.rightMargin: 12; y: nav.y + nav.height - 2
        width: 420; height: (win.dlAll.length ? Math.min(dlList.contentHeight, 420) : 40) + 92; radius: 12
        color: Qt.alpha(pal.panel, 0.98); border.width: 1; border.color: Qt.alpha(pal.acc, 0.55)
        transform: Scale { id: dsc; origin.y: 0 }
        onVisibleChanged: if (visible) { win.dls = []; dIn.restart(); }
        ParallelAnimation { id: dIn
            NumberAnimation { target: dsc; property: "yScale"; from: 0.05; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: dlPanel; property: "opacity"; from: 0; to: 1; duration: 120 } }
        Text { x: 16; y: 14; text: "// DOWNLOADS"; color: pal.dim; font.family: win.mono; font.pixelSize: 12; font.letterSpacing: 3 }
        Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 14; text: win.dlActive.length ? win.dlActive.length + " active" : ""
               color: pal.acc; font.family: win.mono; font.pixelSize: 12 }
        ListView {
            id: dlList
            x: 8; y: 40; width: parent.width - 16; height: Math.min(contentHeight, 420); clip: true
            model: win.dlAll; spacing: 4
            delegate: Rectangle {
                id: de
                required property var modelData
                readonly property var d: modelData
                readonly property bool done: win.dlDone(d)
                readonly property bool bad: win.dlBad(d)
                width: dlList.width; height: 56; radius: 8
                color: dema.containsMouse ? Qt.alpha(pal.btn, 0.8) : "transparent"
                MouseArea { id: dema; anchors.fill: parent; hoverEnabled: true; cursorShape: de.done ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (de.done) Qt.openUrlExternally(win.fileUrl(de.d.downloadDirectory + "/" + de.d.downloadFileName)) }
                Glyph { x: 10; y: 10; width: 22; text: de.done ? "󰄬" : de.bad ? "󰅙" : "󰇚"; font.pixelSize: 16
                        color: de.done ? "#6fcfa8" : de.bad ? "#e8607e" : pal.acc }
                Text { x: 40; y: 9; width: parent.width - 130; elide: Text.ElideMiddle; text: de.d.downloadFileName; color: pal.text; font.family: win.mono; font.pixelSize: 13 }
                Text { x: 40; y: 29; font.family: win.mono; font.pixelSize: 11; color: pal.dim
                       text: de.done ? win.mb(de.d.totalBytes || de.d.receivedBytes) + " MB · готово" : de.bad ? "отменено"
                           : win.mb(de.d.receivedBytes) + " / " + (de.d.totalBytes > 0 ? win.mb(de.d.totalBytes) : "?") + " MB" }
                Rectangle { x: 40; y: 46; height: 2; radius: 1; visible: !de.done && !de.bad; color: pal.acc
                            width: (parent.width - 130) * (de.d.totalBytes > 0 ? de.d.receivedBytes / de.d.totalBytes : 0)
                            Behavior on width { NumberAnimation { duration: 200 } } }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    Btn { glyph: "󰉋"; visible: de.done; onHit: Qt.openUrlExternally(win.fileUrl(de.d.downloadDirectory)) }
                    Btn { glyph: de.done || de.bad ? "✕" : "■"; tint: de.done || de.bad ? pal.dim : "#e8607e"
                          onHit: de.done || de.bad ? win.dlAll = win.dlAll.filter(x => x !== de.d) : de.d.cancel() }
                }
            }
        }
        Text { visible: !win.dlAll.length; anchors.horizontalCenter: parent.horizontalCenter; y: 52; text: "пока пусто"; color: pal.dim; font.family: win.mono; font.pixelSize: 13 }
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; x: 10; spacing: 8
            Chip { label: "󰉋  папка загрузок"; onHit: Qt.openUrlExternally(win.fileUrl(win.dlDir)) }
            Chip { label: "очистить список"; visible: win.dlAll.some(d => win.dlDone(d) || win.dlBad(d))
                   onHit: win.dlAll = win.dlAll.filter(d => !win.dlDone(d) && !win.dlBad(d)) }
        }
    }

    // ══════════ КОНТЕКСТНОЕ МЕНЮ ══════════
    MouseArea { anchors.fill: parent; visible: menu.visible; acceptedButtons: Qt.AllButtons; onPressed: menu.visible = false }
    Rectangle {
        id: menu
        property var items: []
        function popup(it, px, py) {   // it: [[текст, действие, доступно?] | null]
            items = it;
            x = Math.min(px, win.width - width - 8); y = Math.min(py, win.height - col.implicitHeight - 20);
            visible = true; menuIn.restart();
        }
        function show(v, r) {
            const W = WebEngineView, it = [], sel = r.selectedText, link = r.linkUrl.toString();
            if (link) it.push(["󰏌  Открыть в новой вкладке", () => win.newTab(link, true)], ["󰆏  Копировать ссылку", () => v.triggerWebAction(W.CopyLinkToClipboard)]);
            if (r.mediaType === ContextMenuRequest.MediaTypeImage)
                it.push(["󰋩  Копировать картинку", () => v.triggerWebAction(W.CopyImageToClipboard)], ["󰏌  Картинку в новой вкладке", () => win.newTab(r.mediaUrl.toString(), true)]);
            if (r.isContentEditable) it.push(["󰆐  Вырезать", () => v.triggerWebAction(W.Cut)], ["󰆏  Копировать", () => v.triggerWebAction(W.Copy)], ["󰆒  Вставить", () => v.triggerWebAction(W.Paste)]);
            else if (sel) it.push(["󰆏  Копировать", () => v.triggerWebAction(W.Copy)],
                                  ["󰍉  Искать «" + (sel.length > 18 ? sel.slice(0, 18) + "…" : sel) + "»", () => win.newTab(win.searchUrl + encodeURIComponent(sel), false)]);
            if (it.length) it.push(null);
            it.push(["󰁍  Назад", () => v.goBack(), v.canGoBack], ["󰁔  Вперёд", () => v.goForward(), v.canGoForward], ["󰑐  Обновить", () => v.reload()]);
            const p = v.mapToItem(win.contentItem, r.position.x, r.position.y);
            popup(it, p.x, p.y);
        }
        visible: false
        width: 270; height: col.implicitHeight + 12; radius: 10
        color: Qt.alpha(pal.panel, 0.97); border.width: 1; border.color: Qt.alpha(pal.acc, 0.55)
        transform: Scale { id: msc; origin.y: 0 }
        ParallelAnimation { id: menuIn
            NumberAnimation { target: msc; property: "yScale"; from: 0.05; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: menu; property: "opacity"; from: 0; to: 1; duration: 100 } }
        Column {
            id: col; x: 6; y: 6; width: parent.width - 12
            Repeater {
                model: menu.items
                Item {
                    required property var modelData
                    width: col.width; height: modelData ? 30 : 9
                    readonly property bool ok: !!modelData && modelData[2] !== false
                    Rectangle { visible: !modelData; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Qt.alpha(pal.acc, 0.2) }
                    Rectangle { visible: !!modelData; anchors.fill: parent; radius: 6; color: mia.containsMouse && parent.ok ? pal.sel : "transparent" }
                    Text { visible: !!modelData; x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData ? modelData[0] : ""
                           font.family: win.mono; font.pixelSize: 13; color: parent.ok ? pal.text : Qt.alpha(pal.dim, 0.5) }
                    MouseArea { id: mia; anchors.fill: parent; hoverEnabled: true; enabled: parent.ok
                                onClicked: { menu.visible = false; modelData[1](); } }
                }
            }
        }
    }

    // ══════════ РЕДАКТОР БЫСТРОЙ ССЫЛКИ ══════════
    MouseArea { anchors.fill: parent; visible: linkEd.visible; onPressed: linkEd.visible = false
                Rectangle { anchors.fill: parent; color: Qt.alpha(pal.bg, 0.55) } }
    Rectangle {
        id: linkEd
        property int idx: -1
        function open(i, name, url) {
            idx = i;
            leName.text = i >= 0 ? win.links[i][0] : (name || "");
            leUrl.text = i >= 0 ? win.links[i][1] : (url || "").replace(/^https?:\/\//, "").replace(/\/$/, "");
            visible = true; leIn.restart(); leName.input.forceActiveFocus();
        }
        function save() {
            const n = leName.text.trim(), u = leUrl.text.trim();
            if (!n || !u) return;
            const l = win.links.slice();
            if (idx >= 0) l[idx] = [n, u]; else l.push([n, u]);
            win.saveLinks(l); visible = false;
        }
        visible: false
        anchors.centerIn: parent; width: 420; height: 230; radius: 14
        color: pal.panel; border.width: 1; border.color: pal.acc
        NumberAnimation { id: leIn; target: linkEd; property: "scale"; from: 0.85; to: 1; duration: 220; easing.type: Easing.OutBack }
        Column {
            x: 20; y: 18; width: parent.width - 40; spacing: 10
            Text { text: linkEd.idx >= 0 ? "// EDIT LINK" : "// NEW LINK"; color: pal.dim; font.family: win.mono; font.pixelSize: 12; font.letterSpacing: 3 }
            Field { id: leName; width: parent.width; hint: "название"; onAccepted: leUrl.input.forceActiveFocus() }
            Field { id: leUrl; width: parent.width; hint: "адрес, например youtube.com"; onAccepted: linkEd.save() }
            Item { width: 1; height: 6 }
            Row { spacing: 8; anchors.right: parent.right
                Chip { label: "удалить"; visible: linkEd.idx >= 0; onHit: { win.saveLinks(win.links.filter((_, k) => k !== linkEd.idx)); linkEd.visible = false; } }
                Chip { label: "отмена"; onHit: linkEd.visible = false }
                Chip { label: "сохранить"; active: true; onHit: linkEd.save() } }
        }
    }

    // ══════════ ВЫБОР ТЕМЫ (быстрый) ══════════
    MouseArea { anchors.fill: parent; visible: themes_.visible; onPressed: themes_.visible = false }
    Rectangle {
        id: themes_
        visible: false
        anchors.right: parent.right; anchors.rightMargin: 150; y: 44
        width: 250; height: tcol.implicitHeight + 16; radius: 12
        color: Qt.alpha(pal.panel, 0.97); border.width: 1; border.color: Qt.alpha(pal.acc, 0.55)
        onVisibleChanged: if (visible) tIn.restart()
        NumberAnimation { id: tIn; target: themes_; property: "opacity"; from: 0; to: 1; duration: 140 }
        Column {
            id: tcol; x: 8; y: 8; width: parent.width - 16; spacing: 2
            Repeater {
                model: win.themes
                Rectangle {
                    id: trow
                    required property var modelData
                    width: tcol.width; height: 40; radius: 8
                    color: tma2.containsMouse ? Qt.alpha(pal.btn, 0.9) : modelData.id === cfg.theme ? Qt.alpha(pal.sel, 0.25) : "transparent"
                    Row { x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Repeater { model: ["bg", "panel", "sel", "acc", "light"]
                            Rectangle { width: 14; height: 22; radius: 3; color: trow.modelData[modelData]; border.width: 1; border.color: Qt.alpha("#ffffff", 0.08) } } }
                    Text { x: 108; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.family: win.mono; font.pixelSize: 13; font.letterSpacing: 2
                           color: modelData.id === cfg.theme ? pal.text : pal.dim }
                    MouseArea { id: tma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { win.setTheme(modelData.id); themes_.visible = false; } }
                }
            }
        }
    }

    // ── смена темы: развёртка сверху вниз + рваные полосы ──
    Item {
        id: themeFx
        anchors.fill: parent; visible: false
        function restart() { tfx.restart(); }
        property real p: 0
        Rectangle { width: parent.width; y: themeFx.p * parent.height - 2; height: 3; color: pal.light; opacity: 0.9 }
        Rectangle { width: parent.width; y: themeFx.p * parent.height - 80; height: 78
                    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.alpha(pal.acc, 0.22) } } }
        Repeater { model: 10
            Rectangle { width: parent.width * (0.3 + Math.random() * 0.7); x: Math.random() * parent.width * 0.4
                        y: Math.random() * parent.height; height: 2 + Math.random() * 14; color: index % 2 ? pal.acc : pal.light
                        opacity: themeFx.p < 0.35 ? 0.25 : 0 } }
        SequentialAnimation {
            id: tfx
            PropertyAction { target: themeFx; property: "visible"; value: true }
            NumberAnimation { target: themeFx; property: "p"; from: 0; to: 1.05; duration: 700; easing.type: Easing.InOutQuad }
            PropertyAction { target: themeFx; property: "visible"; value: false }
        }
    }

    // ── рамка окна и растягивание за края ──
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: win.maxed ? 0 : 1; border.color: Qt.alpha(pal.acc, 0.35) }
    Repeater {
        model: [
            { e: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor }, { e: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
            { e: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, c: Qt.SizeVerCursor }, { e: Qt.TopEdge, x: 8, y: 0, w: -16, h: 3, c: Qt.SizeVerCursor },
            { e: Qt.LeftEdge | Qt.BottomEdge, x: 0, y: -8, w: 8, h: 8, c: Qt.SizeBDiagCursor }, { e: Qt.RightEdge | Qt.BottomEdge, x: -8, y: -8, w: 8, h: 8, c: Qt.SizeFDiagCursor }
        ]
        MouseArea {
            required property var modelData
            enabled: !win.maxed
            x: modelData.x < 0 ? win.width + modelData.x : modelData.x; y: modelData.y < 0 ? win.height + modelData.y : modelData.y
            width: modelData.w < 0 ? win.width + modelData.w : modelData.w; height: modelData.h < 0 ? win.height + modelData.h : modelData.h
            cursorShape: modelData.c
            onPressed: win.startSystemResize(modelData.e)
        }
    }
}
