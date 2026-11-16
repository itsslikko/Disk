-- ============================================================================
-- DISK - CONFIGURATION & ABILITIES (v1.0.4 - Knockback Fix)
-- ============================================================================
local modname = core.get_current_modname()

local CONFIG = {
    base_damage = 6,
    bounce_damage_bonus = 1.5,
    speed = 26,                 -- Initial throw speed
    return_speed = 30,          -- Homing return speed
    blade_hit_radius = 0.50,    -- Physical blade width around the disk center for grazing hits!
    gravity = -3.5,             -- Slight gravity arc over long distances
    air_drag = 0.985,           -- Gradual momentum loss in air
    bounce_speed_keep = 0.82,   -- Keeps 82% speed per bounce until momentum runs out
    min_stick_speed = 7.0,      -- Below this speed, wall impact sticks the disk!
    max_bounces = 4,            -- Max bounces before sticking into the next surface
    break_fragile = true,
    parry_projectiles = true,
    hand_parry_radius = 4.0,
    momentum_item_pickup = true,
    pickup_radius = 1.8,

    max_uses = 250,
    throw_wear_cost = 1,
    hit_wear_cost = 2,
}

local WEAR_UNIT = math.floor(65535 / CONFIG.max_uses)
local is_mcl = core.get_modpath("mcl_core") ~= nil
local has_dye = core.get_modpath("dye") ~= nil or core.get_modpath("mcl_dye") ~= nil

-- ============================================================================
-- UPGRADE COSTS & MATERIALS
-- ============================================================================
local mat_iron = is_mcl and "mcl_core:iron_ingot" or "default:steel_ingot"
local mat_gold = is_mcl and "mcl_core:gold_ingot" or "default:gold_ingot"
local mat_redstone = is_mcl and "mcl_core:redstone" or (core.registered_items["default:mese_crystal"] and "default:mese_crystal" or "default:copper_ingot")

local dye_red    = is_mcl and "mcl_dye:red"    or (has_dye and "dye:red"    or mat_iron)
local dye_blue   = is_mcl and "mcl_dye:blue"   or (has_dye and "dye:blue"   or mat_iron)
local dye_yellow = is_mcl and "mcl_dye:yellow" or (has_dye and "dye:yellow" or mat_iron)
local dye_green  = is_mcl and "mcl_dye:green"  or (has_dye and "dye:green"  or mat_iron)
local dye_black  = is_mcl and "mcl_dye:black"  or (has_dye and "dye:black"  or mat_iron)

local snd_throw  = is_mcl and "mcl_throwing_throw" or "default_place_node_hard"
local snd_bounce = is_mcl and "mcl_sounds_place_stone" or "default_dig_cracky"
local snd_break  = "default_tool_breaks"

local UPGRADE_COSTS = {
    shape_chakram  = {item = mat_iron, count = 1, label = is_mcl and "(1x Iron)" or "(1x Steel)"},
    shape_shield   = {item = mat_iron, count = 3, label = is_mcl and "(3x Iron)" or "(3x Steel)"},
    shape_sawtooth = {item = mat_iron, count = 2, label = is_mcl and "(2x Iron)" or "(2x Steel)"},
    shape_star     = {item = mat_iron, count = 2, label = is_mcl and "(2x Iron)" or "(2x Steel)"},

    core_open  = {item = "", count = 0, label = "(Free)"},
    core_cross = {item = mat_iron, count = 4, label = is_mcl and "(4x Iron)" or "(4x Steel)"},
    core_star  = {item = mat_gold, count = 2, label = "(2x Gold)"},
    core_tech  = {item = mat_redstone, count = 3, label = is_mcl and "(3x Redstone)" or "(3x Mese)"},

    col_steel   = {item = "", count = 0, label = "(Free)"},
    col_crimson = {item = dye_red,    count = 1, label = "(1x Red Dye)"},
    col_cobalt  = {item = dye_blue,   count = 1, label = "(1x Blue Dye)"},
    col_gold    = {item = dye_yellow, count = 1, label = "(1x Ylw Dye)"},
    col_emerald = {item = dye_green,  count = 1, label = "(1x Grn Dye)"},
    col_void    = {item = dye_black,  count = 1, label = "(1x Blk Dye)"},
}

-- ============================================================================
-- NODE HELPERS
-- ============================================================================
local function is_forge_node(nodename)
    if not nodename then return false end
    if is_mcl then
        return nodename:find("mcl_anvils:anvil") ~= nil
    else
        return nodename == "default:steelblock" or nodename == "default:furnace" or nodename == "default:furnace_active" or nodename:find("anvil") ~= nil
    end
end

local function is_breakable_node(nodename)
    local def = core.registered_nodes[nodename]
    if not def then return false end
    local g = def.groups or {}
    if g.leaves or g.glass or g.flora or g.torch or g.plant or g.dig_immediate == 3 or g.dig_by_trident then
        return true
    end
    if nodename:find("glass") or nodename:find("pane") or nodename:find("pot") then
        return true
    end
    return false
end

local function trigger_redstone_node(pos, player, pointed, disk_ent)
    local node = core.get_node(pos)
    local def = core.registered_nodes[node.name]
    if not def then return end

    if def._on_arrow_hit then
        local fake_arrow = {
            object = (disk_ent and disk_ent.object) or player,
            _stuckin = pos,
            _shooter = player,
        }
        pcall(def._on_arrow_hit, pos, fake_arrow)
        return
    end

    if def.on_rightclick and (node.name:find("button") or node.name:find("lever") or node.name:find("wallswitch") or node.name:find("switch")) then
        pcall(def.on_rightclick, pos, node, player, ItemStack(""), pointed)
    elseif def.on_punch and (node.name:find("target") or node.name:find("button") or node.name:find("switch")) then
        pcall(def.on_punch, pos, node, player, pointed)
    end
end

-- ============================================================================
-- TEXTURES & METADATA
-- ============================================================================
local SHAPES = {"chakram", "shield", "sawtooth", "star"}
local SHAPE_NAMES = {chakram = "Chakram Ring", shield = "Round Shield", sawtooth = "Sawtooth Blade", star = "Shuriken Star"}
local CORES = {"open", "star", "cross", "tech"}
local CORE_NAMES = {open = "Hollow Ring", star = "Star Emblem", cross = "Iron Cross", tech = "Energy Core"}

local COLORS = {
    {id = "steel",   name = "Polished Steel", hex = "#ffffff"},
    {id = "crimson", name = "Crimson Red",    hex = "#ef4444"},
    {id = "cobalt",  name = "Cobalt Blue",    hex = "#3b82f6"},
    {id = "gold",    name = "Royal Gold",     hex = "#eab308"},
    {id = "emerald", name = "Emerald Green",  hex = "#22c55e"},
    {id = "void",    name = "Obsidian Black", hex = "#475569"},
}

local BLUEPRINTS = {
    shape_chakram  = "Agile (Shape): +2 Max Wall Bounces and 20% faster flight speed.",
    shape_shield   = "Heavy Shield (Shape): Sneak + Left-Click to Shield-Bash & Parry arrows! Double knockback.",
    shape_sawtooth = "Grinder (Shape): Deals +2 Bleed damage on contact, losing 15% speed when slicing flesh.",
    shape_star     = "Piercer (Shape): Slices through enemies with zero speed loss.",
    core_open  = "Lightweight (Core): Minimal air drag—flies much farther before losing momentum.",
    core_cross = "Smasher (Core): Hitting a solid wall triggers a 3x3 shockwave, damaging nearby mobs.",
    core_star  = "Loyal (Core): Automatically returns to your hand after sticking, slicing enemies on the way back!",
    core_tech  = "Recall & Magnet (Core): Right-Click anytime after throwing to recall Disk to your hand! 3x Loot Magnet."
}

local function get_color_def(id)
    for _, c in ipairs(COLORS) do if c.id == id then return c end end
    return COLORS[1]
end

local function compose_disk_texture(shape, core_type, color_id)
    local col = get_color_def(color_id)
    local blade = "disk_blade_" .. (shape or "chakram") .. ".png"
    if col.id ~= "steel" then blade = "(" .. blade .. "^[multiply:" .. col.hex .. ")" end
    if core_type and core_type ~= "open" then return blade .. "^disk_core_" .. core_type .. ".png" end
    return blade
end

local function get_variant_itemname(shape, core_type, color_id, is_enchanted)
    local base = (shape == "chakram" and core_type == "open" and color_id == "steel")
        and modname .. ":disk_chakram"
        or string.format("%s:disk_%s_%s_%s", modname, shape, core_type, color_id)
    return (is_enchanted and core.registered_tools[base .. "_enchanted"]) and (base .. "_enchanted") or base
end

local function is_disk_item(name)
    return name and name:find("^" .. modname .. ":disk_") ~= nil
end

local function get_disk_meta(stack)
    local meta = stack:get_meta()
    local s, c, col = meta:get_string("disk_shape"), meta:get_string("disk_core"), meta:get_string("disk_color")
    return (s == "" and "chakram" or s), (c == "" and "open" or c), (col == "" and "steel" or col)
end

-- ============================================================================
-- PARTICLES
-- ============================================================================
local function pixel_tex(hex) return "[combine:2x2^[noalpha^[colorize:" .. hex .. ":255" end

local function fx_wall_sparks(pos, normal, hex_color)
    local n = normal or {x = 0, y = 1, z = 0}
    local base_v = vector.multiply(n, 4)
    local spark_hex = (hex_color == "#ffffff" or hex_color == "#cbd5e1") and "#fbbf24" or hex_color

    core.add_particlespawner({
        amount = 14, time = 0.04, minpos = vector.subtract(pos, 0.05), maxpos = vector.add(pos, 0.05),
        minvel = vector.add(base_v, {x = -3.5, y = -1.0, z = -3.5}), maxvel = vector.add(base_v, {x = 3.5,  y = 4.0,  z = 3.5}),
        minacc = {x = 0, y = -14, z = 0}, maxacc = {x = 0, y = -18, z = 0},
        minexptime = 0.18, maxexptime = 0.42, minsize = 0.9, maxsize = 1.8,
        texture = pixel_tex(spark_hex), glow = 14,
    })
end

local function fx_slash_hit(pos, dir, hex_color)
    local perp = {x = -dir.z, y = 0.3, z = dir.x}
    core.add_particlespawner({
        amount = 16, time = 0.05, minpos = vector.subtract(pos, 0.2), maxpos = vector.add(pos, 0.2),
        minvel = vector.multiply(perp, -6), maxvel = vector.multiply(perp, 6),
        minacc = {x = 0, y = -4, z = 0}, maxacc = {x = 0, y = -4, z = 0},
        minexptime = 0.12, maxexptime = 0.25, minsize = 1.2, maxsize = 2.4,
        texture = pixel_tex(hex_color or "#ef4444"), glow = 14,
    })
end

local function fx_shockwave(pos, hex_color)
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        core.add_particle({
            pos = pos, velocity = {x = math.cos(angle) * 8, y = 0, z = math.sin(angle) * 8},
            expirationtime = 0.2, size = 3, texture = pixel_tex(hex_color or "#94a3b8"), glow = 10,
        })
    end
end

local function fx_flight_trail(pos, hex_color, core_type, time_offset, high_momentum)
    local tex = pixel_tex(hex_color or "#e2e8f0")
    local p_vel = {x = 0, y = 0.25, z = 0}
    local spread = (core_type == "tech") and 0.8 or 0.45
    if core_type == "cross" then p_vel.x = math.cos(time_offset * 15) * 2.0; p_vel.z = math.sin(time_offset * 15) * 2.0
    elseif core_type == "star" then p_vel.y = 1.5 end

    core.add_particle({
        pos = { x = pos.x + (math.random() - 0.5) * spread, y = pos.y + (math.random() - 0.5) * 0.1, z = pos.z + (math.random() - 0.5) * spread },
        velocity = p_vel, expirationtime = (core_type == "tech") and 0.3 or (high_momentum and 0.20 or 0.15),
        size = (core_type == "tech") and 2.2 or (high_momentum and 1.6 or 1.2), texture = tex, glow = 14,
    })
end

-- ============================================================================
-- PROJECTILE PARRY & UNIVERSAL DAMAGE HELPER
-- ============================================================================
local function is_projectile_entity(ent)
    if not ent or not ent.name or ent.name == modname .. ":flying_disk" or ent.name == "__builtin:item" then return false end
    local n = ent.name:lower()
    if n:find("arrow") or n:find("fireball") or n:find("snowball") or n:find("thrown") or ent._is_arrow then return true end
    local v = ent.object:get_velocity()
    return (v and vector.length(v) > 8 and not ent.health and not ent.hp)
end

local function deflect_projectile(obj, deflector_pos)
    local v = obj:get_velocity()
    if v and vector.length(v) > 0.5 then
        obj:set_velocity(vector.multiply(v, -1.2))
    elseif deflector_pos and obj:get_pos() then
        obj:set_velocity(vector.multiply(vector.normalize(vector.subtract(obj:get_pos(), deflector_pos)), 20))
    end
    core.sound_play(snd_bounce, {pos = obj:get_pos(), gain = 1.0, pitch = 1.6}, true)
end

local function damage_target(target_obj, player, disk_obj, dmg, dir_norm, kb)
    local ent = target_obj:get_luaentity()
    local is_living = target_obj:is_player() or (ent and ent.is_mob)

    if is_mcl and mcl_util and mcl_util.deal_damage and mcl_damage then
        local mcl_reason = { type = "trident", source = player, direct = disk_obj }
        mcl_damage.finish_reason(mcl_reason)
        mcl_util.deal_damage(target_obj, dmg, mcl_reason)

        -- V1.0.4 FIX: Only apply physical knockback velocity to living mobs/players! 
        -- Prevents chests and Kinetica windmills from flying into the sky.
        if is_living then
            if ent and ent.projectile_knockback then
                ent:projectile_knockback(math.max(1, math.floor(kb / 3)), dir_norm)
            else
                target_obj:add_velocity({x = dir_norm.x * kb, y = 2.0, z = dir_norm.z * kb})
            end
        end
    else
        if player then
            target_obj:punch(player, 1.0, { full_punch_interval = 1.0, damage_groups = {fleshy = dmg} }, vector.multiply(dir_norm, kb))
        end
        if is_living then
            target_obj:add_velocity({x = dir_norm.x * kb, y = 1.5, z = dir_norm.z * kb})
        end
    end
end

local function disk_intersects_entity(disk_pos, obj, blade_radius)
    local opos = obj:get_pos()
    if not opos then return false end
    local props = obj:get_properties()
    local cbox = (props and props.collisionbox) or {-0.4, -0.5, -0.4, 0.4, 1.5, 0.4}

    local min_x, min_y, min_z = opos.x + cbox[1] - blade_radius, opos.y + cbox[2] - 0.25, opos.z + cbox[3] - blade_radius
    local max_x, max_y, max_z = opos.x + cbox[4] + blade_radius, opos.y + cbox[5] + 0.25, opos.z + cbox[6] + blade_radius

    return (disk_pos.x >= min_x and disk_pos.x <= max_x) and (disk_pos.y >= min_y and disk_pos.y <= max_y) and (disk_pos.z >= min_z and disk_pos.z <= max_z)
end

-- ============================================================================
-- TRACKING THROWN DISKS FOR TECH CORE RIGHT-CLICK RECALL
-- ============================================================================
local player_disks = {}

local function register_active_disk(pname, ent)
    if not pname then return end
    player_disks[pname] = player_disks[pname] or {}
    table.insert(player_disks[pname], ent)
end

local function recall_tech_disks(player)
    local pname = player:get_player_name()
    local list = player_disks[pname]
    if not list then return false end
    local recalled = false

    for i = #list, 1, -1 do
        local ent = list[i]
        if ent and ent.object and ent.object:get_pos() then
            if ent.core_type == "tech" and not ent.returning then
                ent.stuck = false; ent.returning = true; ent.hit_mobs = {}
                core.sound_play(snd_throw, {pos = player:get_pos(), gain = 0.8, pitch = 1.5}, true)
                recalled = true
            end
        else
            table.remove(list, i)
        end
    end
    return recalled
end

-- ============================================================================
-- 3D FLYING & STICKING DISK ENTITY
-- ============================================================================
core.register_entity(modname .. ":flying_disk", {
    initial_properties = { visual = "wielditem", visual_size = {x = 0.42, y = 0.42, z = 0.42}, wield_item = modname .. ":disk_chakram", physical = false, pointable = false, glow = 5, static_save = true },
    thrower_name = nil, _itemstack_str = "", _collectable = true, trail_hex = "#e2e8f0", shape_type = "chakram", core_type = "open",
    vel = {x = 0, y = 0, z = 0}, bounces = 0, stuck = false, returning = false, loyalty_level = 0, loyalty_timer = 0.6,
    hit_mobs = {}, carried_items = {}, spin_yaw = 0, time_alive = 0, ench_sharpness = 0, ench_unbreaking = 0, ench_knockback = 0, ench_impaling = 0,

    get_staticdata = function(self)
        return core.serialize({ thrower_name = self.thrower_name, _itemstack_str = self._itemstack_str, _collectable = self._collectable, trail_hex = self.trail_hex, shape_type = self.shape_type, core_type = self.core_type, vel = self.vel, bounces = self.bounces, stuck = self.stuck, returning = self.returning, loyalty_level = self.loyalty_level, ench_sharpness = self.ench_sharpness, ench_unbreaking = self.ench_unbreaking, ench_knockback = self.ench_knockback, ench_impaling = self.ench_impaling })
    end,

    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1}); self.hit_mobs = {}; self.carried_items = {}
        if staticdata and staticdata ~= "" then
            local data = core.deserialize(staticdata)
            if data then
                self.thrower_name = data.thrower_name; self._itemstack_str = data._itemstack_str or ""; self._collectable = (data._collectable ~= false)
                self.trail_hex = data.trail_hex or "#e2e8f0"; self.shape_type = data.shape_type or "chakram"; self.core_type = data.core_type or "open"
                self.vel = data.vel or {x = 0, y = 0, z = 0}; self.bounces = data.bounces or 0; self.stuck = data.stuck or false
                self.returning = data.returning or false; self.loyalty_level = data.loyalty_level or 0
                self.ench_sharpness = data.ench_sharpness or 0; self.ench_unbreaking = data.ench_unbreaking or 0; self.ench_knockback = data.ench_knockback or 0; self.ench_impaling = data.ench_impaling or 0

                local stack = ItemStack(self._itemstack_str)
                if not stack:is_empty() then
                    local w_name = stack:get_name()
                    if not core.registered_items[w_name] then w_name = w_name:gsub("_enchanted$", "") end
                    self.object:set_properties({ wield_item = w_name, glow = (self.core_type == "tech") and 14 or 5 })
                end
                self.object:set_rotation({x = math.pi / 2, y = 0, z = 0})
                if self.stuck then self.object:set_velocity({x = 0, y = 0, z = 0}) else self.object:set_velocity(self.vel) end
                if self.thrower_name then register_active_disk(self.thrower_name, self) end
            end
        end
    end,

    setup = function(self, player, dir, stack, color_hex, shape_id, core_id, ench_data, collectable)
        self.thrower_name = player:get_player_name(); self._itemstack_str = stack:to_string(); self._collectable = collectable
        self.shape_type = shape_id; self.core_type = core_id; self.trail_hex = (color_hex ~= "#ffffff") and color_hex or "#cbd5e1"
        ench_data = ench_data or {}
        self.ench_sharpness = ench_data.sharp or 0; self.ench_unbreaking = ench_data.unbreak or 0; self.ench_knockback = ench_data.knock or 0; self.ench_impaling = ench_data.impaling or 0
        self.loyalty_level = ench_data.loyalty or 0
        if self.core_type == "star" and self.loyalty_level == 0 then self.loyalty_level = 2 end

        self.vel = vector.multiply(dir, (self.shape_type == "chakram") and (CONFIG.speed * 1.2) or CONFIG.speed)
        self.object:set_velocity(self.vel)
        local w_name = stack:get_name()
        if not core.registered_items[w_name] then w_name = w_name:gsub("_enchanted$", "") end
        self.object:set_properties({ wield_item = w_name, glow = (self.core_type == "tech") and 14 or 5 })
        self.object:set_rotation({x = math.pi / 2, y = 0, z = 0})
        register_active_disk(self.thrower_name, self)
    end,

    add_disk_wear = function(self, amount)
        if not self._collectable then return false end
        local stack = ItemStack(self._itemstack_str)
        stack:add_wear(math.floor(amount / (self.ench_unbreaking + 1)))
        if stack:get_count() == 0 then
            core.sound_play(snd_break, {pos = self.object:get_pos(), gain = 0.9}, true)
            self.object:remove(); return true
        end
        self._itemstack_str = stack:to_string(); return false
    end,

    give_to_player = function(self, player)
        local ppos = player:get_pos()
        local inv = player:get_inventory()

        for _, item_obj in pairs(self.carried_items) do
            if item_obj and item_obj:get_pos() then
                local ent = item_obj:get_luaentity()
                if ent and ent.itemstring and inv then
                    local leftover = inv:add_item("main", ItemStack(ent.itemstring))
                    if leftover:is_empty() then item_obj:remove() else ent.itemstring = leftover:to_string(); item_obj:set_pos(ppos) end
                end
            end
        end

        if not self._collectable then
            core.sound_play(snd_throw, {pos = ppos, gain = 0.6, pitch = 1.4}, true)
            self.object:remove(); return true
        end

        local stack = ItemStack(self._itemstack_str)
        if inv then
            local wield = player:get_wielded_item()
            if wield:is_empty() or inv:room_for_item("main", stack) then
                if wield:is_empty() then player:set_wielded_item(stack) else inv:add_item("main", stack) end
                core.sound_play(snd_throw, {pos = ppos, gain = 0.6, pitch = 1.4}, true)
                self.object:remove(); return true
            end
        end
        return false
    end,

    update_momentum_loot = function(self, pos)
        if not CONFIG.momentum_item_pickup or self.bounces < 1 then return end
        for _, obj in ipairs(core.get_objects_inside_radius(pos, (self.core_type == "tech") and (CONFIG.pickup_radius * 3) or CONFIG.pickup_radius)) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "__builtin:item" then self.carried_items[tostring(obj)] = obj end
        end
        for id, item_obj in pairs(self.carried_items) do
            if item_obj and item_obj:get_pos() then item_obj:set_pos(pos); item_obj:set_velocity(self.vel) else self.carried_items[id] = nil end
        end
    end,

    check_wide_blade_hits = function(self, pos1, pos2, player, is_return_flight)
        local seg = vector.subtract(pos2, pos1)
        local dist = vector.length(seg)
        local steps = math.max(1, math.ceil(dist / 0.35))
        local dir_norm = (dist > 0.001) and vector.normalize(seg) or {x = 0, y = 0, z = 1}

        for s = 0, steps do
            local t = (steps == 0) and 0 or (s / steps)
            local sample_pos = vector.add(pos1, vector.multiply(seg, t))

            for _, obj in ipairs(core.get_objects_inside_radius(sample_pos, 2.5)) do
                if obj ~= self.object and obj ~= player then
                    local ent = obj:get_luaentity()
                    if is_projectile_entity(ent) then
                        if CONFIG.parry_projectiles and vector.distance(sample_pos, obj:get_pos()) <= 1.4 then deflect_projectile(obj, sample_pos) end
                    elseif not (ent and (ent.name == "__builtin:item" or ent.name == modname .. ":flying_disk" or ent.name == "mcl_tridents:trident_clip")) then
                        if disk_intersects_entity(sample_pos, obj, CONFIG.blade_hit_radius) then
                            local id = tostring(obj)
                            if not self.hit_mobs[id] then
                                self.hit_mobs[id] = true
                                local dmg = CONFIG.base_damage + (is_return_flight and 0 or math.floor(self.bounces * CONFIG.bounce_damage_bonus)) + (self.ench_sharpness * 1.5) + (self.ench_impaling * 2.0)
                                if not is_return_flight then
                                    if self.shape_type == "sawtooth" then dmg = dmg + 2; self.vel = vector.multiply(self.vel, 0.85) elseif self.shape_type ~= "star" then self.vel = vector.multiply(self.vel, 0.92) end
                                    self.object:set_velocity(self.vel)
                                end
                                damage_target(obj, player, self.object, dmg, dir_norm, ((self.shape_type == "shield") and 6 or 3) + (self.ench_knockback * 2))
                                fx_slash_hit(sample_pos, dir_norm, self.trail_hex); self:update_momentum_loot(sample_pos)
                                if self:add_disk_wear(WEAR_UNIT * CONFIG.hit_wear_cost) then return true end
                            end
                        end
                    end
                end
            end
        end
        return false
    end,

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end
        local player = self.thrower_name and core.get_player_by_name(self.thrower_name)

        if self.stuck then
            self.object:set_velocity({x = 0, y = 0, z = 0})
            if self.loyalty_level > 0 and player then
                self.loyalty_timer = self.loyalty_timer - dtime
                if self.loyalty_timer <= 0 then
                    self.stuck = false; self.returning = true; self.hit_mobs = {}
                    core.sound_play(snd_throw, {pos = pos, gain = 0.7, pitch = 1.3}, true)
                    return
                end
            end
            for _, p in ipairs(core.get_connected_players()) do
                if vector.distance(pos, vector.add(p:get_pos(), {x = 0, y = 1.0, z = 0})) <= 1.65 then if self:give_to_player(p) then return end end
            end
            return
        end

        self.time_alive = self.time_alive + dtime
        self.spin_yaw = (self.spin_yaw + dtime * (30 + self.bounces * 6)) % (math.pi * 2)
        self.object:set_rotation({x = math.pi / 2, y = 0, z = self.spin_yaw})

        if math.random() < 0.7 then fx_flight_trail(pos, self.trail_hex, self.core_type, self.time_alive, self.bounces >= 1) end
        self:update_momentum_loot(pos)

        if self.returning then
            if not player then self.returning = false; self.stuck = true; self.object:set_velocity({x = 0, y = 0, z = 0}); return end
            local ppos = vector.add(player:get_pos(), {x = 0, y = 1.2, z = 0})
            local diff = vector.subtract(ppos, pos)
            if vector.length(diff) <= 1.65 then self:give_to_player(player); return end
            if (self.core_type == "star" or self.loyalty_level > 0) and self:check_wide_blade_hits(pos, vector.add(pos, vector.multiply(self.vel, dtime)), player, true) then return end
            self.vel = vector.multiply(vector.normalize(diff), CONFIG.return_speed + (self.loyalty_level * 4))
            self.object:set_velocity(self.vel)
            return
        end

        local factor = math.pow((self.core_type == "open") and 0.994 or CONFIG.air_drag, dtime * 20)
        self.vel.x = self.vel.x * factor; self.vel.z = self.vel.z * factor; self.vel.y = (self.vel.y * factor) + (CONFIG.gravity * dtime)
        self.object:set_velocity(self.vel)

        local step_vec = vector.multiply(self.vel, dtime)
        local next_pos = vector.add(pos, step_vec)
        if self:check_wide_blade_hits(pos, next_pos, player, false) then return end

        local ray = core.raycast(pos, next_pos, false, false)
        for pointed in ray do
            if pointed.type == "node" then
                local npos = pointed.under; local nname = core.get_node(npos).name
                if player then trigger_redstone_node(npos, player, pointed, self) end

                if core.registered_nodes[nname] and core.registered_nodes[nname].walkable then
                    local hit_p = pointed.intersection_point or pos
                    if CONFIG.break_fragile and is_breakable_node(nname) then
                        if not core.is_protected(npos, self.thrower_name or "") then
                            core.dig_node(npos); if self.bounces < 1 then self.bounces = 1 end; self:update_momentum_loot(npos)
                            if self:add_disk_wear(WEAR_UNIT * CONFIG.hit_wear_cost) then return end
                        end
                        fx_wall_sparks(hit_p, pointed.intersection_normal, self.trail_hex)
                        self.vel = vector.multiply(self.vel, 0.75); self.object:set_velocity(self.vel)
                        return
                    end

                    if self.core_type == "cross" and player then
                        fx_shockwave(hit_p, self.trail_hex)
                        for _, obj in ipairs(core.get_objects_inside_radius(hit_p, 3)) do
                            local ent = obj:get_luaentity()
                            if obj ~= player and not is_projectile_entity(ent) and not (ent and ent.name == "__builtin:item") then
                                damage_target(obj, player, self.object, 3, {x = 0, y = 0.5, z = 0}, 3)
                            end
                        end
                    end

                    if self.bounces >= ((self.shape_type == "chakram") and (CONFIG.max_bounces + 2) or CONFIG.max_bounces) or vector.length(self.vel) < CONFIG.min_stick_speed then
                        fx_wall_sparks(hit_p, pointed.intersection_normal, self.trail_hex)
                        self.stuck = true; self.vel = {x = 0, y = 0, z = 0}; self.object:set_velocity(self.vel)
                        self.object:set_pos(vector.add(hit_p, vector.multiply(pointed.intersection_normal or {x = 0, y = 1, z = 0}, 0.08)))
                        self.loyalty_timer = math.max(0.2, 0.8 - (self.loyalty_level * 0.2))
                        core.sound_play(snd_bounce, {pos = hit_p, gain = 0.9, pitch = 0.85}, true)
                        return
                    end

                    local n = pointed.intersection_normal
                    if n and (n.x ~= 0 or n.y ~= 0 or n.z ~= 0) then self.vel = vector.subtract(self.vel, vector.multiply(n, 2 * vector.dot(self.vel, n))) else self.vel = vector.multiply(self.vel, -1) end
                    self.bounces = self.bounces + 1
                    self.vel = vector.multiply(vector.normalize(self.vel), vector.length(self.vel) * CONFIG.bounce_speed_keep)
                    self.hit_mobs = {}; fx_wall_sparks(hit_p, n, self.trail_hex)
                    local safe_pos = vector.add(hit_p, vector.multiply(vector.normalize(self.vel), 0.15))
                    self.object:set_pos(safe_pos); self.object:set_velocity(self.vel)
                    core.sound_play(snd_bounce, {pos = safe_pos, gain = 0.85, pitch = 1.1 + (self.bounces * 0.12)}, true)
                    return
                end
            end
        end
    end,
})

-- ============================================================================
-- FORGE GUI
-- ============================================================================
local function show_forge_formspec(player, stack, info_text)
    local shape, core_t, col = get_disk_meta(stack)
    local pname = player:get_player_name()
    local fs = {
        "formspec_version[4]", "size[10,8.2]", "label[0.5,0.5;DISK Blueprint Forge]",
        "box[0.5,0.8;2.6,2.6;#1e293b]", "image[0.8,1.1;2.0,2.0;" .. core.formspec_escape(compose_disk_texture(shape, core_t, col)) .. "]",
        "box[3.4,0.8;6.1,1.5;#0f172a]",
        string.format("textarea[3.6,0.9;5.7,1.3;;;%s]", core.formspec_escape(info_text or ("Equipped Blueprints:\n- " .. (BLUEPRINTS["shape_" .. shape] or "") .. "\n- " .. (BLUEPRINTS["core_" .. core_t] or "")))),
        "label[3.4,2.5;2. Core Module (Special Ability):]",
        "button[3.4,2.7;2.8,0.7;core_open;Hollow\n" .. UPGRADE_COSTS.core_open.label .. "]", "button[6.4,2.7;3.0,0.7;core_star;Star\n" .. UPGRADE_COSTS.core_star.label .. "]",
        "button[3.4,3.5;2.8,0.7;core_cross;Cross\n" .. UPGRADE_COSTS.core_cross.label .. "]", "button[6.4,3.5;3.0,0.7;core_tech;Tech\n" .. UPGRADE_COSTS.core_tech.label .. "]",
        string.format("label[3.4,4.5;Durability: %d%%]", math.floor(((65535 - stack:get_wear()) / 65535) * 100)),
        "button[5.2,4.3;4.2,0.65;repair_disk;Hammer Repair (1x Ingot)]",
        "label[0.5,4.8;1. Outer Shell (Flight Physics):]",
        "button[0.5,5.1;2.2,0.7;shape_chakram;Chakram\n" .. UPGRADE_COSTS.shape_chakram.label .. "]", "button[2.8,5.1;2.2,0.7;shape_shield;Shield\n" .. UPGRADE_COSTS.shape_shield.label .. "]",
        "button[5.1,5.1;2.2,0.7;shape_sawtooth;Sawtooth\n" .. UPGRADE_COSTS.shape_sawtooth.label .. "]", "button[7.4,5.1;2.0,0.7;shape_star;Shuriken\n" .. UPGRADE_COSTS.shape_star.label .. "]",
        "label[0.5,6.2;3. Structural Alloy (Dyes):]",
    }
    for i, c in ipairs(COLORS) do table.insert(fs, string.format("button[%.2f,6.5;1.4,0.65;col_%s;%s\n%s]", 0.5 + (i - 1) * 1.5, c.id, c.name:match("^%S+"), UPGRADE_COSTS["col_" .. c.id].label)) end
    core.show_formspec(pname, modname .. ":forge_gui", table.concat(fs))
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= modname .. ":forge_gui" then return end
    local stack = player:get_wielded_item()
    if not is_disk_item(stack:get_name()) then return end
    local shape, core_t, col = get_disk_meta(stack)
    local changed, info, inv = false, nil, player:get_inventory()

    if fields.repair_disk and stack:get_wear() > 0 then
        if inv and inv:contains_item("main", mat_iron) then
            inv:remove_item("main", mat_iron); stack:set_wear(math.max(0, stack:get_wear() - 32768))
            core.sound_play(snd_bounce, {pos = player:get_pos(), gain = 1.0, pitch = 0.9}, true); changed, info = true, "Repaired 50% durability!"
        else core.chat_send_player(player:get_player_name(), "Need 1 Iron/Steel Ingot to repair!") end
    end

    local function attempt_upgrade(key, current_val, new_val)
        if current_val == new_val then return current_val, false end
        local cost = UPGRADE_COSTS[key]
        if cost and cost.count > 0 and cost.item ~= "" then
            local cost_stack = ItemStack(cost.item .. " " .. cost.count)
            if not core.is_creative_enabled(player:get_player_name()) and not inv:contains_item("main", cost_stack) then
                core.chat_send_player(player:get_player_name(), "Missing materials: You need " .. cost.count .. "x " .. cost.item)
                return current_val, false
            end
            if not core.is_creative_enabled(player:get_player_name()) then inv:remove_item("main", cost_stack) end
        end
        return new_val, true
    end

    for k, _ in pairs(fields) do
        if BLUEPRINTS[k] then info = BLUEPRINTS[k] end
        if k:find("^shape_") then local new_s, success = attempt_upgrade(k, shape, k:sub(7)); if success then shape = new_s; changed = true end
        elseif k:find("^core_") then local new_c, success = attempt_upgrade(k, core_t, k:sub(6)); if success then core_t = new_c; changed = true end
        elseif k:find("^col_") then local new_col, success = attempt_upgrade(k, col, k:sub(5)); if success then col = new_col; changed = true end end
    end

    if changed or info then
        stack:set_name(get_variant_itemname(shape, core_t, col, stack:get_name():find("_enchanted$") ~= nil))
        local meta = stack:get_meta()
        meta:set_string("disk_shape", shape); meta:set_string("disk_core", core_t); meta:set_string("disk_color", col)
        meta:set_string("description", string.format("%s %s\nPassives: %s, %s\nLeft-Click: Throw | Right-Click: Tech Recall\n(Sneak + Right-Click %s to Forge)",
            get_color_def(col).name, SHAPE_NAMES[shape], BLUEPRINTS["shape_" .. shape]:match("^([%w%s]+)%s*%(Shape%)"), BLUEPRINTS["core_" .. core_t]:match("^([%w%s]+)%s*%(Core%)"), is_mcl and "Anvil" or "Steel Block"))
        if is_mcl and mcl_enchanting and mcl_enchanting.update_enchanted_itemstring then mcl_enchanting.update_enchanted_itemstring(stack) end
        player:set_wielded_item(stack)
        show_forge_formspec(player, stack, info)
    end
end)

-- ============================================================================
-- CONTROLS
-- ============================================================================
local function activate_shield_ability(player, shape)
    local ppos = vector.add(player:get_pos(), {x = 0, y = 1.4, z = 0})
    local look, r, did_parry = player:get_look_dir(), (shape == "shield") and (CONFIG.hand_parry_radius * 2) or CONFIG.hand_parry_radius, false
    fx_shockwave(vector.add(ppos, vector.multiply(look, 1.2)), "#38bdf8")
    core.sound_play(snd_bounce, {pos = ppos, gain = 1.0, pitch = 1.4}, true)

    for _, obj in ipairs(core.get_objects_inside_radius(ppos, r)) do
        if obj ~= player then
            local ent, to_obj = obj:get_luaentity(), vector.normalize(vector.subtract(obj:get_pos(), ppos))
            if vector.dot(look, to_obj) > 0.15 then
                if is_projectile_entity(ent) then
                    deflect_projectile(obj, ppos); did_parry = true
                elseif shape == "shield" and not (ent and ent.name == "__builtin:item") and not (ent and ent.name == modname .. ":flying_disk") then
                    damage_target(obj, player, player, 3, to_obj, 8); did_parry = true
                end
            end
        end
    end
    return did_parry
end

local function left_click_disk(stack, player, pointed_thing)
    local shape, core_t, col = get_disk_meta(stack)
    if player:get_player_control().sneak and shape == "shield" then activate_shield_ability(player, shape); return stack end
    local pname, creative = player:get_player_name(), core.is_creative_enabled(player:get_player_name())
    local ench_data = {sharp = 0, unbreak = 0, knock = 0, loyalty = 0, impaling = 0}
    if is_mcl and core.get_modpath("mcl_enchanting") and mcl_enchanting then
        ench_data.sharp = mcl_enchanting.get_enchantment(stack, "sharpness") or 0; ench_data.unbreak = mcl_enchanting.get_enchantment(stack, "unbreaking") or 0
        ench_data.knock = (mcl_enchanting.get_enchantment(stack, "punch") or 0) + (mcl_enchanting.get_enchantment(stack, "knockback") or 0)
        ench_data.loyalty = mcl_enchanting.get_enchantment(stack, "loyalty") or 0; ench_data.impaling = mcl_enchanting.get_enchantment(stack, "impaling") or 0
    end
    local thrown_stack = ItemStack(stack)
    if not creative then
        thrown_stack:add_wear(math.floor((WEAR_UNIT * CONFIG.throw_wear_cost) / (ench_data.unbreak + 1)))
        if thrown_stack:get_count() == 0 then core.sound_play(snd_break, {pos = player:get_pos(), gain = 0.9}, true); stack:take_item(); return stack end
    end
    local ppos, dir = player:get_pos(), player:get_look_dir()
    local spawn_pos = vector.add(vector.add(ppos, {x = 0, y = 1.45, z = 0}), vector.multiply(dir, 0.8))
    local obj = core.add_entity(spawn_pos, modname .. ":flying_disk")
    if obj and obj:get_luaentity() then
        obj:get_luaentity():setup(player, dir, thrown_stack:take_item(), get_color_def(col).hex, shape, core_t, ench_data, not creative)
        core.sound_play(snd_throw, {pos = spawn_pos, gain = 0.8, pitch = 1.0}, true); if not creative then stack:take_item() end
    end
    return stack
end

local function right_click_disk(stack, player, pointed_thing)
    if pointed_thing and pointed_thing.type == "node" and player:get_player_control().sneak and is_forge_node(core.get_node(pointed_thing.under).name) then show_forge_formspec(player, stack); return stack end
    recall_tech_disks(player); return stack
end

for _, shape in ipairs(SHAPES) do
    for _, core_t in ipairs(CORES) do
        for _, col in ipairs(COLORS) do
            local tex = compose_disk_texture(shape, core_t, col.id)
            core.register_tool(get_variant_itemname(shape, core_t, col.id, false), {
                description = SHAPE_NAMES[shape] .. "\nLeft-Click: Throw | Right-Click: Tech Recall\n(Sneak + Right-Click " .. (is_mcl and "Anvil" or "Steel Block") .. " to Forge)",
                inventory_image = tex, wield_image = tex, wield_scale = {x = 1.3, y = 1.3, z = 0.9}, stack_max = 1, _mcl_uses = CONFIG.max_uses,
                tool_capabilities = { full_punch_interval = 1.0, max_drop_level = 1, damage_groups = {fleshy = CONFIG.base_damage} },
                groups = { weapon = 1, sword = 1, disk_weapon = 1, enchantability = 15, rarity = 2, offhand_item = 1, disable_repair = 1, not_in_creative_inventory = (shape == "chakram" and core_t == "open" and col.id == "steel") and 0 or 1 },
                on_use = function(s, p, pt) return left_click_disk(s, p, pt) end,
                on_place = function(s, p, pt) return right_click_disk(s, p, pt) end,
                on_secondary_use = function(s, p, pt) return right_click_disk(s, p, pt) end,
            })
        end
    end
end

core.register_on_mods_loaded(function()
    if is_mcl and core.get_modpath("mcl_enchanting") and mcl_enchanting and mcl_enchanting.enchantments then
        for _, ench_name in ipairs({"loyalty", "impaling"}) do
            local ench_def = mcl_enchanting.enchantments[ench_name]
            if ench_def then ench_def.primary = ench_def.primary or {}; ench_def.primary.disk_weapon = true; ench_def.secondary = ench_def.secondary or {}; ench_def.secondary.disk_weapon = true end
        end
    end
end)

local rmb_held = {}
core.register_globalstep(function(dtime)
    for _, player in ipairs(core.get_connected_players()) do
        local pname = player:get_player_name()
        if player:get_player_control().RMB then
            if not rmb_held[pname] then
                rmb_held[pname] = true
                if not recall_tech_disks(player) and not is_disk_item(player:get_wielded_item():get_name()) then
                    local inv = player:get_inventory()
                    if inv and inv:get_stack("offhand", 1) and is_disk_item(inv:get_stack("offhand", 1):get_name()) then
                        inv:set_stack("offhand", 1, left_click_disk(inv:get_stack("offhand", 1), player, nil))
                    end
                end
            end
        else rmb_held[pname] = false end
    end
end)

core.register_craft({ output = modname .. ":disk_chakram", recipe = { {"", mat_iron, ""}, {mat_iron, "", mat_iron}, {"", mat_iron, ""} } })