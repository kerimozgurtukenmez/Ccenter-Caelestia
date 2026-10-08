#!/usr/bin/env python3
# Ccenter sistem tepsisi ikonu (StatusNotifierItem + com.canonical.dbusmenu).
# Quickshell tepsi ikonlarını gösterebilir ama kendisi ikon yayınlayamaz; bu küçük yardımcı onu yapar.
# Uygulama (services/Tray.qml) bunu alt süreç olarak çalıştırır:
#   stdin  <- JSON durum satırları: {"profiles": [...], "active": "...", "boost": bool, "visible": bool, "tooltip": "..."}
#   stdout -> komut satırları: toggle | profile <ad> | boost <dk> | quit
# stdin kapanınca (uygulama kapandı/çöktü) kendisi de kapanır.
# Bağımlılık: PyGObject (Gio, GLib) ve isteğe bağlı GdkPixbuf (resim dosyasından ikon için).
import json
import os
import sys
import warnings

# PyGObject, register_object için "deprecated" uyarısı basıyor; işlevi etkilemiyor, log'u kirletmesin
warnings.filterwarnings("ignore", category=DeprecationWarning)

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

ICON_FILE = sys.argv[1] if len(sys.argv) > 1 else ""
FALLBACK_ICON = "preferences-system"

SNI_XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Category" type="s" access="read"/>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="WindowId" type="i" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="IconPixmap" type="a(iiay)" access="read"/>
    <property name="ToolTip" type="(sa(iiay)ss)" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <property name="Menu" type="o" access="read"/>
    <method name="Activate"><arg name="x" type="i" direction="in"/><arg name="y" type="i" direction="in"/></method>
    <method name="SecondaryActivate"><arg name="x" type="i" direction="in"/><arg name="y" type="i" direction="in"/></method>
    <method name="ContextMenu"><arg name="x" type="i" direction="in"/><arg name="y" type="i" direction="in"/></method>
    <method name="Scroll"><arg name="delta" type="i" direction="in"/><arg name="orientation" type="s" direction="in"/></method>
    <signal name="NewIcon"/>
    <signal name="NewToolTip"/>
    <signal name="NewStatus"><arg name="status" type="s"/></signal>
  </interface>
</node>
"""

MENU_XML = """
<node>
  <interface name="com.canonical.dbusmenu">
    <property name="Version" type="u" access="read"/>
    <property name="TextDirection" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconThemePath" type="as" access="read"/>
    <method name="GetLayout">
      <arg type="i" name="parentId" direction="in"/>
      <arg type="i" name="recursionDepth" direction="in"/>
      <arg type="as" name="propertyNames" direction="in"/>
      <arg type="u" name="revision" direction="out"/>
      <arg type="(ia{sv}av)" name="layout" direction="out"/>
    </method>
    <method name="GetGroupProperties">
      <arg type="ai" name="ids" direction="in"/>
      <arg type="as" name="propertyNames" direction="in"/>
      <arg type="a(ia{sv})" name="properties" direction="out"/>
    </method>
    <method name="GetProperty">
      <arg type="i" name="id" direction="in"/>
      <arg type="s" name="name" direction="in"/>
      <arg type="v" name="value" direction="out"/>
    </method>
    <method name="Event">
      <arg type="i" name="id" direction="in"/>
      <arg type="s" name="eventId" direction="in"/>
      <arg type="v" name="data" direction="in"/>
      <arg type="u" name="timestamp" direction="in"/>
    </method>
    <method name="EventGroup">
      <arg type="a(isvu)" name="events" direction="in"/>
      <arg type="ai" name="idErrors" direction="out"/>
    </method>
    <method name="AboutToShow">
      <arg type="i" name="id" direction="in"/>
      <arg type="b" name="needUpdate" direction="out"/>
    </method>
    <method name="AboutToShowGroup">
      <arg type="ai" name="ids" direction="in"/>
      <arg type="ai" name="updatesNeeded" direction="out"/>
      <arg type="ai" name="idErrors" direction="out"/>
    </method>
    <signal name="LayoutUpdated"><arg type="u" name="revision"/><arg type="i" name="parent"/></signal>
    <signal name="ItemsPropertiesUpdated">
      <arg type="a(ia{sv})" name="updatedProps"/>
      <arg type="a(ias)" name="removedProps"/>
    </signal>
  </interface>
</node>
"""

SNI_PATH = "/StatusNotifierItem"
MENU_PATH = "/MenuBar"

state = {"profiles": [], "active": "", "boost": False, "visible": True, "tooltip": "Ccenter"}
revision = 1
conn = None
items = {}  # id -> (props, action)


def emit(line):
    """Uygulamaya komut gönder."""
    try:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        loop.quit()


def load_pixmap(path):
    """Resmi SNI'nin beklediği ARGB32 (big-endian) piksel dizisine çevirir; olmazsa boş liste."""
    if not path or not os.path.isfile(path):
        return []
    try:
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
    except (ImportError, ValueError):
        return []
    out = []
    for size in (32, 64):
        try:
            pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, size, size, True)
        except GLib.Error:
            return []
        if not pb.get_has_alpha():
            pb = pb.add_alpha(False, 0, 0, 0)
        w, h, rs = pb.get_width(), pb.get_height(), pb.get_rowstride()
        px = pb.get_pixels()
        argb = bytearray(w * h * 4)
        k = 0
        for y in range(h):
            row = y * rs
            for x in range(w):
                i = row + x * 4
                argb[k] = px[i + 3]
                argb[k + 1] = px[i]
                argb[k + 2] = px[i + 1]
                argb[k + 3] = px[i + 2]
                k += 4
        out.append((w, h, bytes(argb)))
    return out


PIXMAP = load_pixmap(ICON_FILE)
# Sabit özellikler bir kez hazırlanır: ikon verisini her istekte yeniden çevirmek pahalı (~20 KB, bayt bayt)
STATIC_PROPS = {
    "Category": GLib.Variant("s", "Hardware"),
    "Id": GLib.Variant("s", "ccenter"),
    "Title": GLib.Variant("s", "Ccenter"),
    "Status": GLib.Variant("s", "Active"),
    "WindowId": GLib.Variant("i", 0),
    "IconName": GLib.Variant("s", "" if PIXMAP else FALLBACK_ICON),
    "IconPixmap": GLib.Variant("a(iiay)", PIXMAP),
    "ItemIsMenu": GLib.Variant("b", False),
    "Menu": GLib.Variant("o", MENU_PATH),
}


def build_menu():
    """Menü öğelerini durumdan yeniden kurar: id -> (özellikler, eylem)."""
    global items
    items = {}
    nid = [1]

    def add(props, action=None):
        i = nid[0]
        nid[0] += 1
        items[i] = (props, action)
        return i

    order = [
        add({"label": GLib.Variant("s", "Pencereyi gizle" if state["visible"] else "Pencereyi aç")}, "toggle"),
        add({"type": GLib.Variant("s", "separator")}),
    ]
    for name in state["profiles"]:
        order.append(add({
            "label": GLib.Variant("s", name),
            "toggle-type": GLib.Variant("s", "radio"),
            "toggle-state": GLib.Variant("i", 1 if name == state["active"] else 0),
        }, "profile " + name))
    order.append(add({"type": GLib.Variant("s", "separator")}))
    if state["boost"]:
        order.append(add({"label": GLib.Variant("s", "Maksimum fanı kapat")}, "boost 0"))
    else:
        order.append(add({"label": GLib.Variant("s", "Maksimum fan (15 dk)")}, "boost 15"))
    order.append(add({"type": GLib.Variant("s", "separator")}))
    order.append(add({"label": GLib.Variant("s", "Tamamen kapat")}, "quit"))
    return order


order = build_menu()


def layout_variant():
    children = [GLib.Variant("(ia{sv}av)", (i, items[i][0], [])) for i in order]
    root = {"children-display": GLib.Variant("s", "submenu")}
    return GLib.Variant("(u(ia{sv}av))", (revision, (0, root, children)))


def tooltip_variant():
    return GLib.Variant("(sa(iiay)ss)", ("", [], "Ccenter", state["tooltip"]))


def sni_get_property(_c, _s, _p, _i, prop):
    if prop == "ToolTip":
        return tooltip_variant()
    return STATIC_PROPS.get(prop)


def sni_method(_c, _s, _p, _i, method, _params, inv):
    if method in ("Activate", "SecondaryActivate"):
        emit("toggle")
    inv.return_value(None)


def menu_get_property(_c, _s, _p, _i, prop):
    return {
        "Version": GLib.Variant("u", 3),
        "TextDirection": GLib.Variant("s", "ltr"),
        "Status": GLib.Variant("s", "normal"),
        "IconThemePath": GLib.Variant("as", []),
    }.get(prop)


def menu_method(_c, _s, _p, _i, method, params, inv):
    if method == "GetLayout":
        inv.return_value(layout_variant())
    elif method == "GetGroupProperties":
        ids = params.unpack()[0]
        res = [(i, items[i][0]) for i in (ids or list(items)) if i in items]
        inv.return_value(GLib.Variant("(a(ia{sv}))", (res,)))
    elif method == "GetProperty":
        i, name = params.unpack()
        v = items.get(i, ({}, None))[0].get(name)
        inv.return_value(GLib.Variant("(v)", (v if v is not None else GLib.Variant("s", ""),)))
    elif method == "Event":
        i, event = params.unpack()[:2]
        if event == "clicked" and i in items and items[i][1]:
            emit(items[i][1])
        inv.return_value(None)
    elif method == "EventGroup":
        for i, event, _d, _t in params.unpack()[0]:
            if event == "clicked" and i in items and items[i][1]:
                emit(items[i][1])
        inv.return_value(GLib.Variant("(ai)", ([],)))
    elif method == "AboutToShow":
        inv.return_value(GLib.Variant("(b)", (False,)))
    elif method == "AboutToShowGroup":
        inv.return_value(GLib.Variant("(aiai)", ([], [])))
    else:
        inv.return_value(None)


def on_state(line):
    """Uygulamadan gelen durum satırı: menüyü ve ipucunu günceller."""
    global order, revision
    try:
        new = json.loads(line)
    except ValueError:
        return
    menu_changed = any(new.get(k) != state.get(k) for k in ("profiles", "active", "boost", "visible"))
    tip_changed = new.get("tooltip") != state.get("tooltip")
    state.update({k: v for k, v in new.items() if k in state})
    if menu_changed:
        order = build_menu()
        revision += 1
        conn.emit_signal(None, MENU_PATH, "com.canonical.dbusmenu", "LayoutUpdated",
                         GLib.Variant("(ui)", (revision, 0)))
    if tip_changed:
        conn.emit_signal(None, SNI_PATH, "org.kde.StatusNotifierItem", "NewToolTip", None)


def on_stdin(channel, cond):
    if cond & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    line = channel.readline()
    if not line:
        loop.quit()
        return False
    on_state(line.strip())
    return True


def register_watcher():
    try:
        conn.call_sync("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
                       "RegisterStatusNotifierItem", GLib.Variant("(s)", (bus_name,)), None,
                       Gio.DBusCallFlags.NONE, 2000, None)
    except GLib.Error as e:
        sys.stderr.write("tepsi: StatusNotifierWatcher yok (%s)\n" % e.message)


def on_watcher_appeared(*_):
    register_watcher()   # bar (Caelestia) yeniden başlarsa yeniden kaydol


loop = GLib.MainLoop()
conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
bus_name = "org.kde.StatusNotifierItem-%d-1" % os.getpid()
conn.register_object(SNI_PATH, Gio.DBusNodeInfo.new_for_xml(SNI_XML).interfaces[0],
                     sni_method, sni_get_property, None)
conn.register_object(MENU_PATH, Gio.DBusNodeInfo.new_for_xml(MENU_XML).interfaces[0],
                     menu_method, menu_get_property, None)
# Adı senkron al: tepsiye kaydolmadan önce ad bizim olmalı
conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
               GLib.Variant("(su)", (bus_name, 0)), None, Gio.DBusCallFlags.NONE, -1, None)
Gio.bus_watch_name_on_connection(conn, "org.kde.StatusNotifierWatcher", Gio.BusNameWatcherFlags.NONE,
                                 on_watcher_appeared, None)

ch = GLib.IOChannel.unix_new(sys.stdin.fileno())
GLib.io_add_watch(ch, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
loop.run()
