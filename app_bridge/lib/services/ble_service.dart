import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  //Timer? _mockTimer;
  int? _lastWheelRevolutions;
  int? _lastWheelEventTime;
  
  BluetoothDevice? _connectedDevice;

  // Hapus const/final biar variabel ini bisa diobok-obok nilainya
  double circumference = 2.105; // Default awal tetep 700x25c
  double currentSpeedKmh = 0.0;
  bool isConnectedToSensor = false;

  final String cscServiceUuid = "1816";
  final String cscMeasurementCharUuid = "2a5b";

  // Tambahin parameter Function onTimeout di akhir
  Future<void> connectToSensor(Function onDataReceived, Function onConnected, Function onTimeout) async {
    if (await FlutterBluePlus.isSupported == false) return;

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try { await FlutterBluePlus.turnOn(); } catch (_) { return; }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (FlutterBluePlus.isScanningNow) { await FlutterBluePlus.stopScan(); }

    print("Memulai pencarian sensor sepeda...");
    
    // Set timeout scan di sini (misal 10 detik biar gak kelamaan nunggu)
    const scanTimeout = Duration(seconds: 10);
    await FlutterBluePlus.startScan(timeout: scanTimeout);

    StreamSubscription<List<ScanResult>>? scanSub;
    
    // TRICK: Pantau status scanning FBP buat nyergap moment TIMEOUT
    StreamSubscription<bool>? isScanningSub;
    isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      // Jika FBP berhenti nyecan DAN kita belum berhasil konek ke sensor mana pun
      if (!isScanning && !isConnectedToSensor) {
        print("Scan selesai karena timeout.");
        onTimeout(); // Panggil callback timeout buat ngabari UI
        scanSub?.cancel();
        isScanningSub?.cancel();
      }
    });

    scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        String deviceName = r.device.platformName.toLowerCase();
        String serviceUuids = r.advertisementData.serviceUuids.toString();

        bool isCscSensor = serviceUuids.contains(cscServiceUuid) || 
                           deviceName.contains("speed") || 
                           deviceName.contains("cadence");

        if (isCscSensor && _connectedDevice == null) {
          print("Sensor VALID ditemukan!");
          isScanningSub?.cancel(); // Matikan pemantau timeout karena udah aman
          await scanSub?.cancel();
          await FlutterBluePlus.stopScan();

          try {
            _connectedDevice = r.device;
            await _connectedDevice!.connect(license: License.nonprofit);
            isConnectedToSensor = true;
            onConnected(); 

            List<BluetoothService> services = await _connectedDevice!.discoverServices();
            for (BluetoothService service in services) {
              if (service.uuid.toString().contains(cscServiceUuid)) {
                for (BluetoothCharacteristic characteristic in service.characteristics) {
                  if (characteristic.uuid.toString().contains(cscMeasurementCharUuid)) {
                    await characteristic.setNotifyValue(true);
                    characteristic.lastValueStream.listen((value) {
                      decodeCscData(value);
                      onDataReceived(); 
                    });
                  }
                }
              }
            }
          } catch (e) {
            isConnectedToSensor = false;
            _connectedDevice = null;
          }
          break;
        }
      }
    });
  }

  Future<void> disconnectSensor() async {

    if (_connectedDevice != null) {
      print("Memutus koneksi dari sensor: ${_connectedDevice!.platformName}...");
      try {
        await _connectedDevice!.disconnect();
        print("Sensor berhasil diputuskan dengan aman.");
      } catch (e) {
        print("Error pas disconnect: $e");
      } finally {
        // Bersihkan semua state
        _connectedDevice = null;
        isConnectedToSensor = false;
        currentSpeedKmh = 0.0;
        _lastWheelRevolutions = null;
        _lastWheelEventTime = null;
      }
    } else {
      print("Gak ada sensor yang lagi konek, Luq.");
    }
  }

  // Fungsi setter yang dipanggil sama dialog Flutter tadi
  void updateCircumference(double selectedMeter) {
    circumference = selectedMeter;
    print("Sistem BLE: Ukuran keliling roda di-update ke $circumference meter");
  }

  // Fungsi mocking buat emulator biar ngikutin kalkulasi circumference baru
  //void startMockingSpeed() {
  //  stopMockingSpeed(); 
  //  
  //  _mockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
  //   // Kita simulasikan ada 2 putaran roda per detik (RPS = 2)
  //    double simulatedRps = 2.0; 
  //    
  //    // Rumus m/s: Putaran per detik * Keliling Roda
  //    double speedMps = simulatedRps * circumference;
  //    
  //    // Konversi ke km/jam
  //    currentSpeedKmh = speedMps * 3.6;
  //    
  //    print("Mocking Speed (${circumference}m): ${currentSpeedKmh.toStringAsFixed(1)} km/jam");
  //  });
  //}

  //void stopMockingSpeed() {
  //  if (_mockTimer != null) {
  //    _mockTimer!.cancel();
  //    _mockTimer = null;
  //  }
  //  currentSpeedKmh = 0.0;
  //}

  // Fungsi asli buat sensor sepeda beneran nanti
  void decodeCscData(List<int> value) {
    if (value.isEmpty) return;
    int flags = value[0];
    bool hasWheelData = (flags & 0x01) != 0;

    if (hasWheelData && value.length >= 7) {
      int wheelRevolutions = value[1] | (value[2] << 8) | (value[3] << 16) | (value[4] << 24);
      int wheelEventTime = value[5] | (value[6] << 8);

      if (_lastWheelRevolutions != null && _lastWheelEventTime != null) {
        int deltaRotations = wheelRevolutions - _lastWheelRevolutions!;
        int deltaEventTime = wheelEventTime - _lastWheelEventTime!;

        if (deltaEventTime < 0) deltaEventTime += 65535;

        if (deltaRotations > 0 && deltaEventTime > 0) {
          double timeInSeconds = deltaEventTime / 1024.0;
          
          // Di sini dia bakal otomatis pake nilai 'circumference' dinamis yang lu set dari UI
          double speedMps = (deltaRotations * circumference) / timeInSeconds;
          currentSpeedKmh = speedMps * 3.6;
        }
      }
      _lastWheelRevolutions = wheelRevolutions;
      _lastWheelEventTime = wheelEventTime;
    }
  }
}