import asyncio
import sys
from bluez_peripheral.gatt.service import Service
from bluez_peripheral.gatt.characteristic import characteristic, CharacteristicFlags
from bluez_peripheral.advert import Advertisement
from bluez_peripheral.util import Adapter, get_message_bus

# Global variables buat ngontrol simulasi
TARGET_SPEED_KMH = 20.0  # Kecepatan awal (20 km/jam)
WHEEL_CIRCUMFERENCE_METERS = 2.096  # Ukuran Ban 700x25c (sesuai app lu!)
WHEEL_REVOLUTIONS = 0
LAST_WHEEL_TIME_UNIT = 0  # Dalam unit 1/1024 detik (standar BLE CSC)

class CSCService(Service):
    def __init__(self):
        super().__init__("1816", True)

    @characteristic("2A5B", CharacteristicFlags.NOTIFY)
    def csc_measurement(self, options):
        global WHEEL_REVOLUTIONS, LAST_WHEEL_TIME_UNIT
        
        flags = 0x01  # Flag: Wheel Revolution Data Present
        
        # Format byte sesuai spesifikasi Bluetooth SIG CSC Measurement:
        # Byte 0: Flags
        # Byte 1-4: Cumulative Wheel Revolutions (uint32)
        # Byte 5-6: Last Wheel Event Time (uint16, 1/1024s)
        return bytes([
            flags,
            WHEEL_REVOLUTIONS & 0xFF, 
            (WHEEL_REVOLUTIONS >> 8) & 0xFF, 
            (WHEEL_REVOLUTIONS >> 16) & 0xFF, 
            (WHEEL_REVOLUTIONS >> 24) & 0xFF,
            LAST_WHEEL_TIME_UNIT & 0xFF, 
            (LAST_WHEEL_TIME_UNIT >> 8) & 0xFF
        ])


async def update_simulation_data(service):
    """ Loop background buat ngitung putaran roda sesuai TARGET_SPEED_KMH """
    global WHEEL_REVOLUTIONS, LAST_WHEEL_TIME_UNIT, TARGET_SPEED_KMH
    
    interval = 0.5  # Kirim notification tiap 0.5 detik
    
    while True:
        await asyncio.sleep(interval)
        
        if TARGET_SPEED_KMH > 0:
            # Hitung meter per detik: (km/h * 1000) / 3600
            speed_mps = (TARGET_SPEED_KMH * 1000.0) / 3600.0
            
            # Hitung rotasi roda
            distance_covered = speed_mps * interval
            revs_inc = distance_covered / WHEEL_CIRCUMFERENCE_METERS
            
            WHEEL_REVOLUTIONS += int(revs_inc)
            if WHEEL_REVOLUTIONS > 0xFFFFFFFF:
                WHEEL_REVOLUTIONS = 0
                
            LAST_WHEEL_TIME_UNIT += int(interval * 1024)
            if LAST_WHEEL_TIME_UNIT > 0xFFFF:
                LAST_WHEEL_TIME_UNIT %= 0x10000
                
            # 1. Bikin payload byte data barunya
            flags = 0x01
            payload = bytes([
                flags,
                WHEEL_REVOLUTIONS & 0xFF, 
                (WHEEL_REVOLUTIONS >> 8) & 0xFF, 
                (WHEEL_REVOLUTIONS >> 16) & 0xFF, 
                (WHEEL_REVOLUTIONS >> 24) & 0xFF,
                LAST_WHEEL_TIME_UNIT & 0xFF, 
                (LAST_WHEEL_TIME_UNIT >> 8) & 0xFF
            ])
            
            # 2. Oper payload-nya langsung ke changed(payload) !
            service.csc_measurement.changed(payload)

async def keyboard_control():
    """ Mengubah kecepatan simulasi lewat Terminal secara live """
    global TARGET_SPEED_KMH
    loop = asyncio.get_event_loop()
    
    print("\n--- KONTROL SIMULATOR SPEED ---")
    print("Ketik angka kecepatan (misal: 15, 25, 40, atau 0) lalu Enter:")
    
    while True:
        # Read input asynchronously biar gak nge-block BLE
        user_input = await loop.run_in_executor(None, sys.stdin.readline)
        try:
            val = float(user_input.strip())
            TARGET_SPEED_KMH = val
            print(f"⚙️ Target Speed diubah ke: {TARGET_SPEED_KMH} km/h")
        except ValueError:
            pass

async def main():
    bus = await get_message_bus()
    adapter = await Adapter.get_first(bus)

    csc_service = CSCService()
    await csc_service.register(bus)

    advertisement = Advertisement(
        "TrainerCraft_Sim",
        ["1816"],
        appearance=1152,
        timeout=0
    )

    await advertisement.register(bus, adapter)

    print("==========================================================")
    print("🚀 MOCK CSC SENSOR ACTIVE (Ban: 700x25c)")
    print("Device Name  : TrainerCraft_Sim")
    print("Default Speed: 20.0 km/h")
    print("==========================================================")

    # Jalankan simulasi putaran roda dan listener keyboard secara paralel
    asyncio.create_task(update_simulation_data(csc_service))
    asyncio.create_task(keyboard_control())

    while True:
        await asyncio.sleep(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nSimulator dimatikan.")
