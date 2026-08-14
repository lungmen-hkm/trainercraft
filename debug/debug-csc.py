import asyncio
import sys
from bluez_peripheral.gatt.service import Service
from bluez_peripheral.gatt.characteristic import characteristic, CharacteristicFlags
from bluez_peripheral.advert import Advertisement
from bluez_peripheral.util import Adapter, get_message_bus

# Global variables
TARGET_SPEED_KMH = 20.0  # Kecepatan awal
WHEEL_CIRCUMFERENCE_METERS = 2.096  # 700x25c
WHEEL_REVOLUTIONS = 0
LAST_WHEEL_TIME_UNIT = 0  # Unit 1/1024 detik

class CSCService(Service):
    def __init__(self):
        super().__init__("1816", True)

    @characteristic("2A5B", CharacteristicFlags.NOTIFY)
    def csc_measurement(self, options):
        global WHEEL_REVOLUTIONS, LAST_WHEEL_TIME_UNIT
        
        flags = 0x01  # Flag: Wheel Revolution Data Present
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
    """ Loop background dengan Accumulation Precision untuk 0-30 km/h """
    global WHEEL_REVOLUTIONS, LAST_WHEEL_TIME_UNIT, TARGET_SPEED_KMH
    
    interval = 0.2  # 200ms (5Hz) biar responsif dan UI Flutter mulus banget
    rev_accumulator = 0.0  # Nyimpen pecahan rotasi biar gak ilang gara-gara int()
    
    while True:
        await asyncio.sleep(interval)
        
        if TARGET_SPEED_KMH > 0:
            # 1. Hitung meter per detik
            speed_mps = (TARGET_SPEED_KMH * 1000.0) / 3600.0
            
            # 2. Hitung penambahan rotasi pecahan
            distance_covered = speed_mps * interval
            revs_inc = distance_covered / WHEEL_CIRCUMFERENCE_METERS
            
            # Akumulasikan ke float dulu
            rev_accumulator += revs_inc
            
            # 3. Jika akumulasi sudah mencapai 1 putaran atau lebih
            if rev_accumulator >= 1.0:
                full_revs = int(rev_accumulator)  # Ambil jumlah putaran utuh
                rev_accumulator -= full_revs       # Simpan sisa pecahannya
                
                # Tambah total revolusi
                WHEEL_REVOLUTIONS = (WHEEL_REVOLUTIONS + full_revs) & 0xFFFFFFFF
                
                # Update waktu event berdasarkan durasi aktual dari putaran roda tersebut
                # 1 putaran penuh memakan waktu (WHEEL_CIRCUMFERENCE / speed_mps) detik
                time_taken_seconds = (full_revs * WHEEL_CIRCUMFERENCE_METERS) / speed_mps
                time_units_inc = int(time_taken_seconds * 1024.0)
                
                LAST_WHEEL_TIME_UNIT = (LAST_WHEEL_TIME_UNIT + time_units_inc) & 0xFFFF
                
                # 4. Kirim notification byte ke Flutter
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
                
                service.csc_measurement.changed(payload)

async def keyboard_control():
    """ Mengubah kecepatan simulasi lewat Terminal secara live """
    global TARGET_SPEED_KMH
    loop = asyncio.get_event_loop()
    
    print("\n--- KONTROL SIMULATOR SPEED ---")
    print("Ketik angka kecepatan (misal: 5, 12.5, 25, 30, atau 0) lalu Enter:")
    
    while True:
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

    asyncio.create_task(update_simulation_data(csc_service))
    asyncio.create_task(keyboard_control())

    while True:
        await asyncio.sleep(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nSimulator dimatikan.")