import 'package:flutter/material.dart';
import 'services/ble_service.dart';
import 'services/server_service.dart';
import 'package:external_app_launcher/external_app_launcher.dart';

void main() {
  runApp(const TrainerCraftApp());
}

class TrainerCraftApp extends StatelessWidget {
  const TrainerCraftApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}



class _HomeScreenState extends State<HomeScreen> {
bool _isMinecraftInstalled = false;
bool _isScanningBle = false; // Buat nandain status scanning di UI
bool _isBleTimeout = false;
double _topSpeedKmh = 0.0; // Tempat nyimpen rekor top speed
  @override
  void initState() {
    super.initState();
    _checkMinecraftInstallation(); // Cek pas aplikasi pertama kali dibuka
  }

  // Fungsi buat nge-cek keberadaan game Minecraft Bedrock di Android
  Future<void> _checkMinecraftInstallation() async {
    await LaunchApp.isAppInstalled(
    androidPackageName: 'com.mojang.minecraftpe',
    ).then((isInstalled) {
      setState(() {
        _isMinecraftInstalled = isInstalled;
      });
    });
  }

  // Fungsi buat maksa nge-launch game dari tombol
  void _launchMinecraft() async {
    if (_isMinecraftInstalled) {
      await LaunchApp.openApp(
        androidPackageName: 'com.mojang.minecraftpe',
      );
    } else {
      await LaunchApp.openApp(
        androidPackageName: 'com.mojang.minecraftpe',
      );
    }
  }
// Daftar preset ban: Kunci (Teks UI) -> Nilai (Meter untuk rumus)
final Map<String, double> _tirePresets = {
  "700x23c": 2.097,
  "700x25c (Road)": 2.105,
  "700x28c": 2.136,
  "26\" x 2.0\" (MTB)": 2.068,
  "27.5\" x 2.1\" (MTB)": 2.148,
  "29\" x 2.1\" (MTB)": 2.288,
};

// Variabel untuk nyimpen pilihan yang lagi aktif di UI
String _selectedPreset = "700x25c (Road)";

void _showTireSizeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      // Pake StatefulBuilder biar dropdown di dalam dialog bisa berubah pas diklik
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF252538),
            title: const Text("Pilih Ukuran Ban", style: TextStyle(color: Colors.white)),
            content: DropdownButton<String>(
              value: _selectedPreset,
              dropdownColor: const Color(0xFF252538),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: _tirePresets.keys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(key),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  // Update state di dalam dialog biar UI-nya berubah
                  setDialogState(() {
                    _selectedPreset = newValue;
                  });
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  // Ambil nilai meter berdasarkan kunci teks yang dipilih
                  double selectedMeter = _tirePresets[_selectedPreset]!;
                  
                  // Kirim nilai meternya ke BleService lu
                  _bleService.updateCircumference(selectedMeter);
                  
                  // Update UI utama biar teks di Kotak No 4 ikut berubah
                  setState(() {}); 
                  
                  Navigator.pop(context); // Tutup dialog
                },
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      );
    },
  );
}

  final BleService _bleService = BleService();
  final ServerService _serverService = ServerService();
  bool _isServerRunning = false;

  // Fungsi buat nge-handle pembatalan/stop service
  void _stopLatihan() async {
    await _bleService.disconnectSensor();
    await _serverService.stopServer();
    setState(() {
      _isServerRunning = false;
      _isScanningBle = false;
    });
  }

  void _mulaiLatihan() async {
  setState(() {
    _isScanningBle = true; 
    _isBleTimeout = false;
    _topSpeedKmh = 0.0; // Reset top speed tiap mulai latihan baru
  });

  try {
    await _bleService.connectToSensor(
      () {
        // Callback tiap ada update data speed baru
        if (mounted) {
          setState(() {
            // Update top speed kalau speed sekarang lebih kenceng dari rekor sebelumnya
            if (_bleService.currentSpeedKmh > _topSpeedKmh) {
              _topSpeedKmh = _bleService.currentSpeedKmh;
            }
          });
        }
      },
      () async {
        await _serverService.startServer(() => _bleService.currentSpeedKmh);
        if (mounted) {
          setState(() {
            _isScanningBle = false; 
            _isServerRunning = true;
          });
        }
      },
      () {
        if (mounted) {
          setState(() {
            _isScanningBle = false; 
            _isBleTimeout = true;   
          });
        }
      }
    );
  } catch (e) {
    setState(() { _isScanningBle = false; });
  }
  } 

  // Fungsi bungkus untuk toggle nyala/mati (Bisa buat restart juga)
  void _handleServiceButton() {
    if (_isServerRunning) {
      _stopLatihan();
    } else {
      _mulaiLatihan();
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('TrainerCraft App Bridge'),
      centerTitle: true,
      backgroundColor: const Color(0xFF1E1E2E),
      titleTextStyle: const TextStyle(color: Colors.white),
    ),
    backgroundColor: const Color(0xFF1E1E2E), // Vibe dark mode ala KDE Connect
    body: Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.count(
        crossAxisCount: 2, // Bikin 2 kolom (Kiri Kuning/Status, Kanan Hijau/Tombol)
        childAspectRatio: 1.3, // Sesuaikan proporsi kotak biar gak terlalu tinggi
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          // 1. STATUS SERVER (Kuning/Status)
          _buildStatusCard(
            icon: Icons.dns,
            title: "Server Status",
            value: _isServerRunning ? "Active" : "Inactive",
            textColor: _isServerRunning ? Colors.greenAccent : Colors.redAccent,
          ),

          // 2. START/STOP SERVER (Hijau/Tombol)
          _buildActionButton(
            icon: Icons.power_settings_new,
            label: _isServerRunning ? "Stop Service" : "Start Service",
            color: _isServerRunning ? Colors.orange : Colors.green,
            onTap: _handleServiceButton,
          ),

          // 3. SPEED REAL TIME ATAU INDIKATOR SCANNING
// 3. SPEED REAL TIME / SCANNING / TIMEOUT STATE
_isScanningBle
    ? _buildStatusCardWithWidget(
        icon: Icons.bluetooth_searching,
        title: "BLE Sensor",
        widget: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
            ),
            SizedBox(width: 8),
            Text("Scanning...", style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      )
    : _isBleTimeout
        ? _buildStatusCardWithWidget(
            icon: Icons.bluetooth_disabled,
            title: "BLE Sensor",
            widget: const Text(
              "Sensor finding timeout", 
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          )
        : _buildStatusCardWithWidget(
            icon: Icons.speed,
            title: "Real-time Speed",
            widget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_bleService.currentSpeedKmh.toStringAsFixed(1)} km/h",
                  style: const TextStyle(
                    color: Colors.blueAccent, 
                    fontSize: 11, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 4),
      // Text Top Speed Kecil di Bawahnya
                Row(
                  children: [
                    const Icon(Icons.navigation_rounded, size: 12, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                Text(
                  "Top: ${_topSpeedKmh.toStringAsFixed(1)} km/h",
                  style: TextStyle(
                  color: Colors.white.withOpacity(0.6), 
                  fontSize: 11, 
                  fontWeight: FontWeight.w500
                  )
                )
              ],
            )
        ]),
        ),
          // 4. PEMILIH UKURAN BAN (Hijau/Tombol)
          _buildActionButton(
            icon: Icons.adjust,
            label: "Ban: $_selectedPreset",
            color: Colors.teal,
            onTap: () {
              _showTireSizeDialog(context);
            },
          ),
        
          // 5. PEMERIKSA INSTALASI MC (Kuning/Status)
          _buildStatusCard(
            icon: Icons.checklist,
            title: "Minecraft Check",
            value: _isMinecraftInstalled ? "Minecraft Installed" : "Minecraft Not Installed", // Nanti v1 di-hardcode dulu, next pake package device_apps
            textColor: _isMinecraftInstalled ? Colors.amber : Colors.grey,
          ),

          // 6. BUKA/INSTALL MINECRAFT (Hijau/Tombol)
          _buildActionButton(
            icon: Icons.sports_esports,
            label: _isMinecraftInstalled ? "Launch Game" : "Install Game",
            color: _isMinecraftInstalled ? Colors.indigo : Colors.red,
            onTap: () {
              _launchMinecraft();
            },
          ),
      
      ],
      ),
    ),
  );
  }
  // Helper untuk Kotak Status (Kuning - No Click)
Widget _buildStatusCard({required IconData icon, required String title, required String value, required Color textColor}) {
  return Card(
    color: const Color(0xFF252538),
    child: Padding(
      padding: const EdgeInsets.all(10.0), // Dikit diringkas biar lega
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          // Bungkus pake Flexible/Expanded biar kalau teksnya kepanjangan dia otomatis bikin baris baru ke bawah
          Flexible(
            child: Text(
              value, 
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 2, // Maksimal 2 baris biar gak overflow
              overflow: TextOverflow.ellipsis, // Kalau beneran gembrot banget, bakal dipotong pake titik-titik (...)
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper untuk Kotak Tombol (Hijau - Clickable)
Widget _buildActionButton(
  {
    required IconData icon, 
    required String label, 
    required Color color, 
    required VoidCallback onTap
  }
    )
    {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Card(
      color: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              label, 
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildStatusCardWithWidget({required IconData icon, required String title, required Widget widget}) {
  return Card(
    color: const Color(0xFF252538),
    child: Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          // Widget custom (loading bar + teks scanning) bakal ngebakar di sini
          widget 
        ],
      ),
    ),
  );
}
}