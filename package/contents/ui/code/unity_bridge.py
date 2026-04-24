#!/usr/bin/env python3
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import sys

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

    @dbus.service.signal('io.github.daydve.fancytasksng.BadgeUpdate', signature='si')
    def UpdateSignal(self, appId, count):
        # This signal will be sent to the bus
        pass

def handle_unity_update(appId, properties, **kwargs):
    count = properties.get("count", 0)
    visible = properties.get("count-visible", True)
    final_count = int(count) if visible else 0
    
    # Re-emit on our private channel
    emitter.UpdateSignal(str(appId), final_count)

if __name__ == '__main__':
    DBusGMainLoop(set_as_default=True)
    
    emitter = BridgeEmitter()
    
    bus = dbus.SessionBus()
    bus.add_signal_receiver(
        handle_unity_update,
        signal_name="Update",
        dbus_interface="com.canonical.Unity.LauncherEntry"
    )
    
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        sys.exit(0)
