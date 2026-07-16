import { world, system } from "@minecraft/server";
import { http, HttpRequestMethod } from "@minecraft/server-net";

// ⚠️ GANTI pake IP Address HP Redmi lu yang dapet dari Wi-Fi (Misal: 192.168.1.5)
const SERVER_URL = "http://127.0.0.1:8080/"; 

system.runInterval(async () => {
    // Ambil semua player yang ada di world
    const players = world.getAllPlayers();
    if (players.length === 0) return;
    const player = players[0]; // Targetin player utama (lu sendiri)

    try {
        // Tembak request GET ke server shelf di HP
        const response = await http.request({
            uri: SERVER_URL,
            method: HttpRequestMethod.Get
        });

        if (response.status === 200) {
            // Ubah text body response jadi angka
            const speedKmh = parseFloat(response.body);
            
            // Kalau lu gowes di atas 3 km/jam, paksa karakter maju relatif ke depan
            if (speedKmh > 3.0) {
                // Rumus kalkulasi kalkulasi kecepatan maju (^ ^ ^teleport_ke_depan)
                const forwardSpeed = (speedKmh / 25).toFixed(2);
                
                // Eksekusi command teleportasi tipis-tipis biar jalannya smooth
                player.runCommandAsync(`tp ^ ^ ^${forwardSpeed}`);
                
                // Tampilin action bar estetik di atas hotbar biar lu tau speed gowes lu
                player.onScreenDisplay.setActionBar(`§aGowes Speed: §f${speedKmh.toFixed(1)} km/h`);
            } else {
                // Pas lu brenti ngedayung
                player.onScreenDisplay.setActionBar(`§cNgaso dulu... Speed: 0.0 km/h`);
            }
        }
    } catch (error) {
        // Jangan tampilin error message di chat biar gak nyepam pas nyari koneksi
    }
}, 4); // Dilempar tiap 4 tick (artinya dalam 1 detik ada 5 kali pengecekan, responsif banget!)