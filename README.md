# DISK

A highly customizable, physics-driven throwing weapon mod for Minetest (Luanti). Built with seamless cross-compatibility for both standard Minetest Game and Mineclonia. 

Throw it to shatter glass, parry arrows, trigger redstone/mesecons switches from afar, and magnetically carry momentum loot back to your inventory. 

## Features
* **Boomerang Flight Physics:** The disk curves through the air, calculates segment distances, and intelligently homes back to the thrower.
* **The Blueprint Forge:** Sneak + Right-Click an Anvil (Mineclonia) or Steel/Furnace block (Minetest) to open the Forge GUI. Upgrade your disk dynamically using materials from your inventory.
* **Redstone & Mesecons Integration:** Hitting buttons, levers, or target blocks with the disk will remotely trigger them.
* **Mineclonia Enchantment API:** Fully supports Mineclonia's enchanting tables and anvils. Apply Unbreaking, Sharpness, and Punch (Knockback) to scale your disk's power.
* **Projectile Parrying:** Hold the disk in your hand to swat away incoming arrows, snowballs, and fireballs.
* **Offhand Support:** Can be equipped and thrown from the offhand slot.

## Forge Upgrades
Customize your disk by combining different Shapes, Cores, and Colors.

**Outer Shells (Requires Iron/Steel):**
* **Chakram (Agile):** +1 Max Wall Bounces and flies 20% faster.
* **Shield (Heavy):** Double knockback. Doubles your hand-parry radius.
* **Sawtooth (Grinder):** Deals +2 Bleed damage, but loses 15% flight speed after hitting flesh.
* **Shuriken (Piercer):** Infinite follow-through. Slices through an endless line of enemies.

**Core Modules (Requires Gold, Redstone, or Copper):**
* **Hollow Ring (Quickdraw):** Cuts the throwing safety cooldown in half.
* **Iron Cross (Smasher):** Hitting a solid wall triggers a 3x3 shockwave, damaging nearby mobs.
* **Star Emblem (Loyal):** Damages enemies on its return flight back to your hand.
* **Energy Core (Magnetic):** Triples the momentum loot pickup radius to snatch dropped items and emits dynamic light.

**Structural Alloys:**
* Customize your weapon's aesthetic with Polished Steel, Crimson Red, Cobalt Blue, Royal Gold, Emerald Green, or Obsidian Black using standard dyes. Advanced particle trails change based on your selected color and core.

## Dependencies
* **Optional:** `default`, `dye`, `mesecons`, `mcl_core`, `mcl_dye`, `mcl_enchanting`, `mcl_anvils`, `mcl_offhand`, `mcl_sounds`