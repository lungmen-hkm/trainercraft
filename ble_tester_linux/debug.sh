#!/bin/bash

# Pastiin bluetooth laptop idup dan seger
echo "Mengaktifkan Bluetooth Laptop..."
sudo rfkill unblock bluetooth
sudo bluetoothctl power on

# Nonaktifkan bluetooth web/plugin lain biar gak bentrok
sudo bluetoothctl advertise off 2>/dev/null

echo ""
echo "=========================================================="
echo "Memulai Memancarkan Sinyal Sensor Sepeda Palsu (UUID: 1816)"
echo "=========================================================="
echo "Nama Device: Trainercraft_Fake"
echo "Pencet [CTRL+C] di terminal ini buat matiin."
echo ""

# Trik jitu: Pakai pipe input biar session bluetoothctl tetap tertahan (stay alive)
mkfifo /tmp/bt_pipe 2>/dev/null
cat > /tmp/bt_pipe &
cat_pid=$!

# Jalankan bluetoothctl dan biarkan dia membaca input dari pipe yang standby
bluetoothctl < /tmp/bt_pipe &
bt_pid=$!

# Kirim perintah konfigurasi satu per satu ke dalam pipe dengan jeda waktu
sleep 0.5
echo "menu advertise" > /tmp/bt_pipe
sleep 0.5
echo "clear" > /tmp/bt_pipe
sleep 0.5
echo "uuids 1816" > /tmp/bt_pipe
sleep 0.5
echo "name Trainercraft_Debug" > /tmp/bt_pipe
sleep 0.5
echo "back" > /tmp/bt_pipe
sleep 0.5
echo "advertise on" > /tmp/bt_pipe

# Jebakan loop biar script bash gak kelar dan terus nahan background process
trap "kill $cat_pid $bt_pid 2>/dev/null; rm /tmp/bt_pipe 2>/dev/null; echo -e '\nAdvertising dihentikan.'; exit" INT
while true; do
    sleep 1
done
