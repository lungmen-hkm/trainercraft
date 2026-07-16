#!/bin/bash

sudo bluetoothctl <<EOF
power on
discoverable on
pairable on
system-alias tc-debug

menu advertise
clear
service 1816
discoverable on
tx-power on
back

advertise on
EOF

echo "Advertising..."
sleep infinity