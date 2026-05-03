# Flyout — 3.3.5a (WotLK) Port

This is a community port of **Flyout** by **lookino** for **World of Warcraft 3.3.5a** (Wrath of the Lich King, Interface 30300).

The original addon was written for Vanilla 1.12. This version has been adapted for WotLK's Lua 5.1 runtime, secure execution environment, and combat-lockdown constraints.

## Credits

- **lookino** — Original author of Flyout for Vanilla WoW.
- **KameleonUK** — Direction modifier contribution.
- **Sourini** — Dragonflight3 compatibility.
- **veechs** — pfUI / Bongos compatibility fixes.
- **Whitealion** — Item texture, tooltip, and use functionality.
- **Arthur-Helias** — pfUI default-action fix.

## What's Different from the Vanilla Version?

| Aspect | Vanilla 1.12 | This Port (3.3.5a) |
|---|---|---|
| **Casting** | Hooks `UseAction`, `GetActionCooldown`, etc. | Uses `SecureActionButtonTemplate` — no hooks, no taint |
| **Macro format** | `/flyout Spell1; Spell2; Spell3` | Must include a `/cast` line for the default action |
| **Combat lockdown** | No restriction | Flyout cannot be opened during combat (Blizzard limitation) |
| **Lua runtime** | Lua 4.0 (custom) | Lua 5.1 (`string.gmatch`, `ipairs`, `self` param convention) |
| **Dependencies** | None | None (still zero external deps) |

The key architectural change is that casting is now handled entirely through Blizzard's `SecureActionButtonTemplate`, following the same pattern used by HealBot. This means:

- **No action-blocked errors** during combat.
- The flyout buttons are protected frames; they cannot be shown or have their attributes modified while `InCombatLockdown()` is active. If you open the flyout before combat starts, it remains usable throughout the fight.

## How to Use

1. Open your macros and create a new macro.
2. Add a `/cast` line for the **default** (first) action, then a `/flyout` line listing all actions separated by semicolons:
   ```
   /cast Summon Imp
   /flyout Summon Imp; Summon Voidwalker; Summon Felhunter
   ```
   - To use a specific rank: `Shadow Bolt(Rank 1)` (omitting the rank uses the highest rank).
   - The `/cast` line is **required** on 3.3.5a — it tells the secure handler what to execute when the action bar button is clicked or keybound.
   - The `/flyout` line is parsed by the addon to build the flyout menu.
3. Drag the macro onto one of your action bars.

### Default Action

The first action in the `/flyout` list is the default. Clicking the action bar button (or pressing its keybind) casts this default action securely via Blizzard's handler.

### Right-Click to Swap Default

Right-click any flyout entry to promote it to the default. The addon automatically updates:
- The `/cast` line in the macro.
- The order in the `/flyout` line.

### Modifiers

You can add modifiers inside the `/flyout` line:

| Modifier | Effect |
|---|---|
| `[direction:DIRECTION]` | Force flyout to expand in a specific direction (`up`, `down`, `left`, `right`), overriding auto-detection |
| `[icon]` | Use the default action's icon for the flyout button on the action bar |
| `[sticky]` | Keep the flyout open after using an action |
| `[lock]` | Keep the `/flyout` list order fixed when right-clicking to swap the default — only `/cast` is updated |

Example with modifiers:
```
/cast Shadow Bolt
/flyout [direction:right][icon] Shadow Bolt; Immolate; Corruption
```

Use `[lock]` if you want right-click swaps to update the default cast without rearranging the flyout order:
```
/cast Flash Heal
/flyout [direction:up][lock] Flash Heal; Greater Heal; Renew; Prayer of Mending
```

## Class Examples (WotLK 3.3.5a)

### Mage

**Teleport** — Travel to capital cities.
```
/cast Teleport: Dalaran
/flyout [direction:left][icon] Teleport: Dalaran; Teleport: Exodar; Teleport: Theramore; Teleport: Darnassus; Teleport: Stormwind; Teleport: Ironforge
```

**Portals** — Open portals for your group.
```
/cast Portal: Dalaran
/flyout [direction:left][icon] Portal: Dalaran; Portal: Exodar; Portal: Theramore; Portal: Darnassus; Portal: Stormwind; Portal: Ironforge
```

**Armor** — Swap between armors.
```
/cast Molten Armor
/flyout [direction:up][icon] Molten Armor; Mage Armor; Ice Armor; Frost Armor
```

**Conjure Food** — High ranks only (macro character limit).
```
/cast Conjure Food
/flyout [direction:up][icon] Conjure Food; Conjure Food(Rank 7); Conjure Food(Rank 6)
```

**Conjure Water** — High ranks only (macro character limit).
```
/cast Conjure Water
/flyout [direction:up][icon] Conjure Water; Conjure Water(Rank 8); Conjure Water(Rank 7)
```

### Warlock

**Summon Demon** — Quick pet swap.
```
/cast Summon Imp
/flyout [direction:up][icon][lock] Summon Imp; Summon Voidwalker; Summon Succubus; Summon Felhunter; Summon Felguard
```

**Soul Stones** — Create soulstone and healthstone.
```
/cast Create Healthstone
/flyout [direction:left][icon] Create Healthstone; Create Soulstone
```

### Hunter

**Aspects** — Swap hunter aspects on the fly.
```
/cast Aspect of the Hawk
/flyout [direction:up][icon][lock] Aspect of the Hawk; Aspect of the Dragonhawk; Aspect of the Cheetah; Aspect of the Pack; Aspect of the Viper; Aspect of the Wild; Aspect of the Beast
```

**Tracking** — Toggle tracking by creature type.
```
/cast Track Humanoids
/flyout [direction:left][icon] Track Humanoids; Track Beasts; Track Hidden; Track Undead; Track Demons; Track Giants; Track Dragonkin; Track Elementals
```

### Priest

**Buffs** — Party buffs at a glance.
```
/cast Power Word: Fortitude
/flyout [direction:up][icon] Power Word: Fortitude; Prayer of Fortitude; Divine Spirit; Prayer of Spirit; Shadow Protection; Prayer of Shadow Protection; Fear Ward
```

**Healing** — Primary heals (right-click to set default; `[lock]` keeps the heal order fixed).
```
/cast Flash Heal
/flyout [direction:up][icon][lock] Flash Heal; Greater Heal; Renew; Prayer of Mending; Binding Heal; Circle of Healing
```

### Druid

**Forms** — All shapeshift forms.
```
/cast Bear Form
/flyout [direction:up][icon][lock] Bear Form; Dire Bear Form; Cat Form; Travel Form; Aquatic Form; Flight Form; Swift Flight Form; Moonkin Form; Tree of Life
```

**Buffs** — Mark and Thorns.
```
/cast Mark of the Wild
/flyout [direction:left][icon] Mark of the Wild; Gift of the Wild; Thorns
```

### Shaman

**Totems — Earth** — Earth totems in one menu.
```
/cast Strength of Earth Totem
/flyout [direction:up][icon][lock] Strength of Earth Totem; Stoneskin Totem; Earthbind Totem; Stoneclaw Totem; Tremor Totem
```

**Totems — Fire** — Fire totems in one menu.
```
/cast Searing Totem
/flyout [direction:up][icon][lock] Searing Totem; Flametongue Totem; Frost Resistance Totem; Magma Totem; Fire Elemental Totem; Totem of Wrath
```

**Shields** — Swap between shields.
```
/cast Lightning Shield
/flyout [direction:left][icon] Lightning Shield; Water Shield; Earth Shield
```

### Paladin

**Auras** — Switch auras quickly.
```
/cast Devotion Aura
/flyout [direction:up][icon][lock] Devotion Aura; Retribution Aura; Concentration Aura; Shadow Resistance Aura; Frost Resistance Aura; Fire Resistance Aura; Crusader Aura
```

**Blessings** — Single-target blessings.
```
/cast Blessing of Might
/flyout [direction:left][icon] Blessing of Might; Blessing of Wisdom; Blessing of Kings; Blessing of Sanctuary; Blessing of Light
```

### Warrior

**Stances** — Battle, Defensive, Berserker.
```
/cast Battle Stance
/flyout [direction:up][icon][lock] Battle Stance; Defensive Stance; Berserker Stance
```

**Shouts** — Buff shouts.
```
/cast Battle Shout
/flyout [direction:left][icon] Battle Shout; Commanding Shout
```

### Rogue

**Poisons** — Apply poisons to weapons.
```
/cast Instant Poison
/flyout [direction:up][icon] Instant Poison; Deadly Poison; Wound Poison; Crippling Poison; Mind-numbing Poison; Anesthetic Poison
```

**Stealth Abilities** — Vanish, Stealth.
```
/cast Stealth
/flyout [direction:left][icon] Stealth; Vanish
```

### Death Knight

**Presences** — Blood, Frost, Unholy.
```
/cast Blood Presence
/flyout [direction:up][icon][lock] Blood Presence; Frost Presence; Unholy Presence
```

**Paths** — Path of Frost.
```
/cast Path of Frost
/flyout [direction:left][icon] Path of Frost; Horn of Winter; Bone Shield
```

## Compatibility

This addon works with the default action bars and has explicit support for:

- **Bongos**
- **pfUI**
- **Dragonflight3**

Because it uses `SecureActionButtonTemplate` instead of global function hooks, compatibility with other action-bar replacements depends on whether they correctly expose `ActionButton_GetPagedID` and standard button naming conventions.

## Known Limitations

1. **Cannot open flyout during combat** — `SecureActionButtonTemplate` frames are protected. Opening before combat is fine; the buttons remain usable once visible.
2. **Action bar addons that replace the default button template** may need explicit compatibility patches (see `compat.lua`).
3. **No cross-realm addon messaging** — standard 3.3.5a restriction; not relevant for this addon.

## License

The original Flyout was released under an open license. This port preserves the same spirit. See `LICENSE` for details.
