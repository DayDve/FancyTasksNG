#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import sys
import ctypes
import signal

def set_pdeathsig():
    """Ensure the process dies when its parent (plasmashell) dies."""
    try:
        libc = ctypes.CDLL("libc.so.6")
        libc.prctl(1, signal.SIGTERM) # 1 is PR_SET_PDEATHSIG
    except Exception:
        pass

class NullDevice:
    def write(self, s): pass
    def flush(self): pass

"""
Unity Bridge Sniffer - DBus Re-emitter
Listens for Unity signals and re-emits them on a private interface
that QML can easily consume.
"""

class BridgeEmitter(dbus.service.Object):
    def __init__(self):
        # We use a unique name for our bridge to avoid conflicts
        try:
            self.bus = dbus.SessionBus()
            self.bus_name = dbus.service.BusName('io.github.daydve.fancytasksng.Bridge', bus=self.bus)
            dbus.service.Object.__init__(self, self.bus_name, '/Bridge')
            print("Bridge: Re-emitter is ready on io.github.daydve.fancytasksng.Bridge")
        except Exception as e:
            print(f"Bridge error: {e}")
            sys.exit(1)

    @dbus.service.signal('io.github.daydve.fancytasksng.BadgeUpdate', signature='sidu')
    def UpdateSignal(self, appId, count, progress, pid):
        # This signal will be sent to the bus
        pass

# Unique bus names are never reused, so a sender's PID can be cached for good.
sender_pids = {}

def sender_pid(sender):
    """PID of the process behind a bus connection, 0 if unknown."""
    if not sender:
        return 0
    if sender not in sender_pids:
        try:
            sender_pids[sender] = int(bus.call_blocking(
                'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                'GetConnectionUnixProcessID', 's', (sender,)))
        except Exception:
            sender_pids[sender] = 0
    return sender_pids[sender]

def handle_unity_update(appId, properties, sender=None, **kwargs):
    count = properties.get("count", 0)
    visible = properties.get("count-visible", True)
    final_count = int(count) if visible else 0

    progress = properties.get("progress", 0.0)
    prog_visible = properties.get("progress-visible", False)
    final_progress = float(progress) if prog_visible else -1.0
    
    # The app id an app reports can differ from the one of the task it runs as
    # (Telegram forks report their own id while started from Telegram's desktop
    # file), so the sender's PID goes along to match the task by process.
    emitter.UpdateSignal(str(appId), final_count, final_progress, sender_pid(sender))

if __name__ == '__main__':
    DBusGMainLoop(set_as_default=True)
    
    emitter = BridgeEmitter()
    
    bus = dbus.SessionBus()

    # Register as Unity service so KDE apps (KMail, Kontact) know we're listening.
    # These apps check for "com.canonical.Unity" before sending badge updates.
    # DBUS_NAME_FLAG_DO_NOT_QUEUE: if the name is already taken (e.g. by the
    # standard Plasma Task Manager), just skip — signals will still be received
    # via the wildcard signal_receiver below.
    try:
        reply = bus.request_name(
            'com.canonical.Unity',
            dbus.bus.NAME_FLAG_DO_NOT_QUEUE
        )
        if reply == dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER:
            print("Bridge: Registered as com.canonical.Unity (primary owner)")
        else:
            print("Bridge: com.canonical.Unity already owned, listening passively")
    except Exception as e:
        print(f"Bridge: Could not request com.canonical.Unity: {e}")

    bus.add_signal_receiver(
        handle_unity_update,
        signal_name="Update",
        dbus_interface="com.canonical.Unity.LauncherEntry",
        sender_keyword="sender"
    )
    
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        sys.exit(0)
