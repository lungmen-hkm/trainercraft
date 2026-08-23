import { world, system, EntityComponentTypes } from "@minecraft/server";

// Variabel global penampung speed dari Flutter (km/h)
let currentTrainerSpeedKmh = 0.0;

// Konversi Kecepatan Real-World (km/h) ke Movement Value Minecraft Bedrock
function kmhToMcMovement(speedKmh) {
  if (speedKmh <= 0.1) return 0.0;
  // Formula scaling linear
  let baseMovement = (speedKmh / 100.0) * 1.2; 
  return Math.min(baseMovement, 1.5); // Cap maksimal biar gak ngebug
}

// Tick Loop Minecraft (Jalan tiap 2 ticks / 0.1 detik)
system.runInterval(() => {
  for (const player of world.getAllPlayers()) {
    // Cek apakah player lagi menunggangi sesuatu
    const ridingComp = player.getComponent(EntityComponentTypes.Riding);
    
    if (ridingComp) {
      // Di Script API modern, gunain 'entityRiddenOn' (fallback ke 'entityToRide' kalo versi lama)
      const vehicle = ridingComp.entityRiddenOn ?? ridingComp.entityToRide;
      
      if (vehicle && vehicle.typeId === "trainercraft:bike") {
        const movementComp = vehicle.getComponent(EntityComponentTypes.Movement);
        
        if (movementComp) {
          const mcSpeed = kmhToMcMovement(currentTrainerSpeedKmh);
          movementComp.setCurrentValue(mcSpeed);
        }
      }
    }
  }
}, 2);

// Listener pesan WebSocket / Command dari Flutter
system.afterEvents.scriptEventReceive.subscribe((event) => {
  if (event.id === "trainercraft:set_speed") {
    const speedVal = parseFloat(event.message);
    if (!isNaN(speedVal)) {
      currentTrainerSpeedKmh = speedVal;
    }
  }
});