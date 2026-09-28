#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/airpods-battery.py <MAC>
#
# Battery levels of connected AirPods, for services/BtBattery.qml. AirPods
# don't implement BlueZ's Battery1 over A2DP; they report through Apple's
# accessory protocol (AAP) on L2CAP PSM 0x1001 instead. This opens that
# channel, asks for notifications and prints one line per battery update:
#
#   left \t right \t case     (0..100, or -1 when that part isn't reporting)
#
# Exits when the device refuses the channel (not an Apple accessory) or
# disconnects.

import socket
import sys
import time

PSM = 0x1001
HANDSHAKE = bytes.fromhex("00000400010002000000000000000000")
NOTIFY = bytes.fromhex("040004000f00ffffffff")
BATTERY = bytes.fromhex("040004000400")

# component byte -> column; status 0x04 means the part isn't reporting
PARTS = {0x04: 0, 0x02: 1, 0x08: 2}
DISCONNECTED = 0x04


def connect(mac):
    # the channel can lag the audio connection by a few seconds
    for attempt in range(5):
        s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
        try:
            s.connect((mac, PSM))
            return s
        except ConnectionRefusedError:
            s.close()
            return None
        except OSError:
            s.close()
            time.sleep(2)
    return None


def main():
    s = connect(sys.argv[1])
    if s is None:
        sys.exit(1)
    s.send(HANDSHAKE)
    s.send(NOTIFY)
    while True:
        try:
            d = s.recv(1024)
        except OSError:
            break
        if not d:
            break
        if not d.startswith(BATTERY) or len(d) < 7:
            continue
        levels = [-1, -1, -1]
        for i in range(d[6]):
            p = d[7 + i * 5: 12 + i * 5]
            if len(p) < 5 or p[0] not in PARTS or p[3] == DISCONNECTED:
                continue
            levels[PARTS[p[0]]] = min(p[2], 100)
        print("\t".join(map(str, levels)), flush=True)


main()
