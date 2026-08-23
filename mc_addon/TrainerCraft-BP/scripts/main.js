import { world, EntityComponentTypes } from "@minecraft/server";

// Variabel global penampung speed dari Flutter (km/h)
let currentTrainerSpeedKmh = 0.0;

// Konversi Kecepatan Real-World (km/h) ke Movement Value Minecraft Bedrock
// 10 km/h di dunia nyata setara ~0.15 movement speed di MCPE
function kmhToMcMovement(speedKmh) {
  if (speedKmh <= 0.1) return 0.0;
  // Formula scaling linear (bisa di-tweak sesuai kenyamanan gowes)
  let baseMovement = (speedKmh / 100.0) * 1.2; 
  return Math.min(baseMovement, 1.5); // Cap maksimal biar gak ngebug teleport
}

// Tick Loop Minecraft (Jalan 20 FPS di dalam game)
world.afterEvents.worldInitialize.subscribe(() => {
  system.runInterval(() => {
    // Cari semua player di dunia game
    for (const player of world.getAllPlayers()) {
      // Cek apakah player lagi menunggangi sesuatu
      const ridingComp = player.getComponent(EntityComponentTypes.Riding);
      
      if (ridingComp && ridingComp.entityToRide) {
        const vehicle = ridingComp.entityToRide;
        
        // Cek apakah kendaraan tersebut adalah 'trainercraft:bike'
        if (vehicle.typeId === "trainercraft:bike") {
          const movementComp = vehicle.getComponent(EntityComponentTypes.Movement);
          
          if (movementComp) {
            // Ubah kecepatan sepeda secara live!
            const mcSpeed = kmhToMcMovement(currentTrainerSpeedKmh);
            movementComp.setCurrentValue(mcSpeed);
          }
        }
      }
    }
  }, 2); // Update tiap 2 tick (0.1 detik)
});

// Listener pesan WebSocket dari Flutter App Bridge
system.afterEvents.scriptEventReceive.subscribe((event) => {
  if (event.id === "trainercraft:set_speed") {
    const speedVal = parseFloat(event.message);
    if (!isNaN(speedVal)) {
      currentTrainerSpeedKmh = speedVal;
    }
  }
});