-- ============================================================================
-- DISK - CONFIGURATION & ABILITIES
-- ============================================================================
local modname = core.get_current_modname()

local CONFIG = {
    base_damage = 6,
    bounce_damage_bonus = 1.5,
    speed = 22,
    return_speed = 28,
    max_segment_dist = 20,
    max_bounces = 4,
    pierce_follow_through = 4,
    cooldown_timeout = 6,
    break_fragile = true,
    parry_projectiles = true,
    hand_parry_radius = 3.5,
    momentum_item_pickup = true,
    pickup_radius = 1.8,

    max_uses = 250,
    throw_wear_cost = 1,
    hit_wear_cost = 2,
}

local WEAR_UNIT = math.floor(65535 / CONFIG.max_uses)
local is_mcl = core.get_modpath("mcl_core") ~= nil

-- ============================================================================
-- UPGRADE COSTS & MATERIALS (Cross-Game Support)
-- ============================================================================
local mat_iron = is_mcl and "mcl_core:iron_ingot" or "default:steel_ingot"
local mat_gold = is_mcl and "mcl_core:gold_ingot" or "default:gold_ingot"
local mat_redstone = is_mcl and "mcl_core:redstone" or "default:copper_ingot"
local dye_red = is_mcl and "mcl_dye:red" or "dye:red"
local dye_blue = is_mcl and "mcl_dye:blue" or "dye:blue"
local dye_yellow = is_mcl and "mcl_dye:yellow" or "dye:yellow"
local dye_green = is_mcl and "mcl_dye:green" or "dye:green"
local dye_black = is_mcl and "mcl_dye:black" or "dye:black"

local snd_throw = is_mcl and "mcl_throwing_throw" or "default_place_node_hard"
local snd_bounce = is_mcl and "mcl_sounds_place_stone" or "default_dig_cracky"
local snd_break = "default_tool_breaks"

local UPGRADE_COSTS = {
    -- Shapes (Cost Iron/Steel)
    shape_chakram =  {item = mat_iron, count = 1, label = "(1x Iron)"},
    shape_shield =   {item = mat_iron, count = 3, label = "(3x Iron)"},
    shape_sawtooth = {item = mat_iron, count = 2, label = "(2x Iron)"},
    shape_star =     {item = mat_iron, count = 2, label = "(2x Iron)"},

    -- Cores (Cost Special Materials)
    core_open =      {item = "", count = 0, label = "(Free)"},
    core_cross =     {item = mat_iron, count = 4, label = "(4x Iron)"},
    core_star =      {item = mat_gold, count = 2, label = "(2x Gold)"},
    core_tech =      {item = mat_redstone, count = 3, label = is_mcl and "(3x Redstone)" or "(3x Copper)"},

    -- Colors (Cost Dyes)
    col_steel =      {item = "", count = 0, label = "(Free)"},
    col_crimson =    {item = dye_red, count = 1, label = "(1x Red Dye)"},
    col_cobalt =     {item = dye_blue, count = 1, label = "(1x Blue Dye)"},
    col_gold =       {item = dye_yellow, count = 1, label = "(1x Ylw Dye)"},
    col_emerald =    {item = dye_green, count = 1, label = "(1x Grn Dye)"},
    col_void =       {item = dye_black, count = 1, label = "(1x Blk Dye)"},
}

-- ============================================================================
-- NODE HELPERS (FORGE, BREAKABLE & REDSTONE DETECTION)
-- ============================================================================
local function is_forge_node(nodename)
    if not nodename then return false end
    if is_mcl then
        return nodename:find("mcl_anvils:anvil") ~= nil
    else
        return nodename == "default:steelblock" or nodename == "default:furnace" or nodename:find("anvil") ~= nil
    end
end

local function is_breakable_node(nodename)
    local def = core.registered_nodes[nodename]
    if not def then return false end
    local g = def.groups or {}
    if g.leaves or g.glass or g.flora or g.torch or g.plant or g.dig_immediate == 3 then
        return true
    end
    if nodename:find("glass") or nodename:find("pane") or nodename:find("pot") then
        return true
    end
    return false
end

local function trigger_redstone_node(pos, player, pointed)
    local node = core.get_node(pos)
    local def = core.registered_nodes[node.name]
    if not def then return end

    -- Mesecons / MCL Buttons & Levers (Simulate Player Click)
    if def.on_rightclick and (node.name:find("button") or node.name:find("lever") or node.name:find("wallswitch")) then
        def.on_rightclick(pos, node, player, ItemStack(""), pointed)
    end
    -- MCL Target Block / Mesecons receptor punch
    if def.on_punch and (node.name:find("target") or node.name:find("button")) then
        def.on_punch(pos, node, player, pointed)
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
    shape_chakram =  "Agile (Shape): +1 Max Wall Bounces and flies 20% faster in the air.",
    shape_shield =   "Heavy (Shape): Double knockback on hit. Doubles your hand-parry radius to swat arrows.",
    shape_sawtooth = "Grinder (Shape): Deals +2 Bleed damage on contact, but loses 15% flight speed after hitting flesh.",
    shape_star =     "Piercer (Shape): Infinite follow-through. Slices through an endless line of enemies until it hits a wall.",

    core_open =      "Quickdraw (Core): Cuts the 6-second throwing safety cooldown in half.",
    core_cross =     "Smasher (Core): Hitting a solid wall triggers a 3x3 shockwave, damaging nearby mobs.",
    core_star =      "Loyal (Core): Two-Way Strike! The disk damages enemies on its return flight back to your hand.",
    core_tech =      "Magnetic (Core): Triples Momentum Loot Pickup radius (5 blocks) and emits light."
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

local function get_variant_itemname(shape, core_type, color_id)
    if shape == "chakram" and core_type == "open" and color_id == "steel" then return modname .. ":disk_chakram" end
    return string.format("%s:disk_%s_%s_%s", modname, shape, core_type, color_id)
end

local function get_disk_meta(stack)
    local meta = stack:get_meta()
    local s, c, col = meta:get_string("disk_shape"), meta:get_string("disk_core"), meta:get_string("disk_color")
    return (s == "" and "chakram" or s), (c == "" and "open" or c), (col == "" and "steel" or col)
end

-- ============================================================================
-- PARTICLES (WITH ADVANCED CORE TRAILS)
-- ============================================================================
local function pixel_tex(hex) return "[combine:2x2^[noalpha^[colorize:" .. hex .. ":255" end

local function fx_wall_sparks(pos, normal, hex_color)
    local n = normal or {x = 0, y = 1, z = 0}
    local base_v = vector.multiply(n, 4)
    local spark_hex = (hex_color == "#ffffff" or hex_color == "#cbd5e1") and "#fbbf24" or hex_color

    core.add_particlespawner({
        amount = 14, time = 0.04,
        minpos = vector.subtract(pos, 0.05), maxpos = vector.add(pos, 0.05),
        minvel = vector.add(base_v, {x = -3.5, y = -1.0, z = -3.5}),
        maxvel = vector.add(base_v, {x = 3.5,  y = 4.0,  z = 3.5}),
        minacc = {x = 0, y = -14, z = 0}, maxacc = {x = 0, y = -18, z = 0},
        minexptime = 0.18, maxexptime = 0.42, minsize = 0.9, maxsize = 1.8,
        texture = pixel_tex(spark_hex), glow = 14,
    })
end

local function fx_slash_hit(pos, dir, hex_color)
    local perp = {x = -dir.z, y = 0.3, z = dir.x}
    core.add_particlespawner({
        amount = 16, time = 0.05,
        minpos = vector.subtract(pos, 0.2), maxpos = vector.add(pos, 0.2),
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
            pos = pos,
            velocity = {x = math.cos(angle) * 8, y = 0, z = math.sin(angle) * 8},
            expirationtime = 0.2, size = 3, texture = pixel_tex(hex_color or "#94a3b8"), glow = 10,
        })
    end
end

local function fx_flight_trail(pos, hex_color, core_type, time_offset, high_momentum)
    local tex = pixel_tex(hex_color or "#e2e8f0")
    local p_vel = {x = 0, y = 0.25, z = 0}
    local spread = (core_type == "tech") and 0.8 or 0.45

    if core_type == "cross" then
        p_vel.x = math.cos(time_offset * 15) * 2.0
        p_vel.z = math.sin(time_offset * 15) * 2.0
    elseif core_type == "star" then
        p_vel.y = 1.5
    end

    local base_size = (core_type == "tech") and 2.2 or (high_momentum and 1.6 or 1.2)

    core.add_particle({
        pos = {
            x = pos.x + (math.random() - 0.5) * spread,
            y = pos.y + (math.random() - 0.5) * 0.1,
            z = pos.z + (math.random() - 0.5) * spread
        },
        velocity = p_vel,
        acceleration = (core_type == "star") and {x = 0, y = 2, z = 0} or {x = 0, y = 0, z = 0},
        expirationtime = (core_type == "tech") and 0.3 or (high_momentum and 0.20 or 0.15),
        size = base_size,
        texture = tex,
        glow = 14,
    })
end

-- ============================================================================
-- PROJECTILE PARRY
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
    if v and vector.length(v) > 0.5 then obj:set_velocity(vector.multiply(v, -1.2))
    elseif deflector_pos and obj:get_pos() then obj:set_velocity(vector.multiply(vector.normalize(vector.subtract(obj:get_pos(), deflector_pos)), 20)) end
    core.sound_play(snd_bounce, {pos = obj:get_pos(), gain = 1.0, pitch = 1.6}, true)
end

-- ============================================================================
-- ACTIVE THROWS
-- ============================================================================
local active_throws = {}
local function can_player_throw(pname, core_type)
    local data = active_throws[pname]
    if not data then return true end
    local cd = (core_type == "open") and (CONFIG.cooldown_timeout / 2) or CONFIG.cooldown_timeout
    if os.clock() - data.time > cd then
        active_throws[pname] = nil
        return true
    end
    if data.obj and data.obj.object and data.obj.object:get_pos() then return false end
    active_throws[pname] = nil
    return true
end

-- ============================================================================
-- 3D FLYING DISK ENTITY (ABILITIES ENABLED)
-- ============================================================================
core.register_entity(modname .. ":flying_disk", {
    initial_properties = {
        visual = "wielditem",
        visual_size = {x = 0.42, y = 0.42, z = 0.42},
        wield_item = modname .. ":disk_chakram",
        physical = false,
        pointable = false,
        glow = 5,
        static_save = false
    },
    thrower_name = nil, hand_list = "main", hand_idx = 1, extra_wear = 0, trail_hex = "#e2e8f0",
    shape_type = "chakram", core_type = "open", vel = {x = 0, y = 0, z = 0}, start_speed = 22,
    bounces = 0, segment_dist = 0, pierce_dist = nil,
    returning = false, hit_mobs = {}, carried_items = {}, spin_yaw = 0, time_alive = 0,

    -- Enchantment Hooks
    ench_sharpness = 0, ench_unbreaking = 0, ench_knockback = 0,

    on_activate = function(self)
        self.hit_mobs = {}
        self.carried_items = {}
    end,

    setup = function(self, player, dir, item_name, color_hex, listname, idx, shape_id, core_id, ench_data)
        self.thrower_name = player:get_player_name()
        self.hand_list = listname or "main"
        self.hand_idx = idx or player:get_wield_index()
        self.shape_type = shape_id
        self.core_type = core_id
        self.trail_hex = (color_hex ~= "#ffffff") and color_hex or "#cbd5e1"

        ench_data = ench_data or {}
        self.ench_sharpness = ench_data.sharp or 0
        self.ench_unbreaking = ench_data.unbreak or 0
        self.ench_knockback = ench_data.knock or 0

        -- SHAPE: Chakram (Agile) Speed Boost
        self.start_speed = (self.shape_type == "chakram") and (CONFIG.speed * 1.2) or CONFIG.speed
        self.vel = vector.multiply(dir, self.start_speed)

        self.object:set_velocity(self.vel)
        self.object:set_properties({ wield_item = item_name, glow = (self.core_type == "tech") and 14 or 5 })
        self.object:set_rotation({x = math.pi / 2, y = 0, z = 0})
    end,

    update_momentum_loot = function(self, pos)
        if not CONFIG.momentum_item_pickup or self.bounces < 1 then return end
        -- CORE: Tech (Magnetic) triples pickup radius
        local pr = (self.core_type == "tech") and (CONFIG.pickup_radius * 3) or CONFIG.pickup_radius
        for _, obj in ipairs(core.get_objects_inside_radius(pos, pr)) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "__builtin:item" then self.carried_items[tostring(obj)] = obj end
        end
        for id, item_obj in pairs(self.carried_items) do
            if item_obj and item_obj:get_pos() then
                item_obj:set_pos(pos)
                item_obj:set_velocity(self.vel)
            else
                self.carried_items[id] = nil
            end
        end
    end,

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end
        local player = self.thrower_name and core.get_player_by_name(self.thrower_name)
        if not player then self.object:remove(); return end

        self.time_alive = self.time_alive + dtime
        self.spin_yaw = (self.spin_yaw + dtime * (30 + self.bounces * 6)) % (math.pi * 2)
        self.object:set_rotation({x = math.pi / 2, y = 0, z = self.spin_yaw})

        if math.random() < 0.7 then
            fx_flight_trail(pos, self.trail_hex, self.core_type, self.time_alive, self.bounces >= 1)
        end

        self:update_momentum_loot(pos)

        if CONFIG.parry_projectiles then
            for _, obj in ipairs(core.get_objects_inside_radius(pos, 1.4)) do
                if obj ~= self.object and obj ~= player and is_projectile_entity(obj:get_luaentity()) then
                    deflect_projectile(obj, pos)
                end
            end
        end

        -- FEATURE: Boomerang Flight Vectors (curves outward flight before first bounce)
        if not self.returning and self.bounces == 0 then
            local right = vector.cross(vector.normalize(self.vel), {x = 0, y = 1, z = 0})
            if vector.length(right) > 0 then
                self.vel = vector.add(self.vel, vector.multiply(right, dtime * 3.5))
                self.vel = vector.multiply(vector.normalize(self.vel), self.start_speed)
                self.object:set_velocity(self.vel)
            end
        end

        -- 1. HOMING RETURN
        if self.returning then
            local ppos = vector.add(player:get_pos(), {x = 0, y = 1.2, z = 0})
            local diff = vector.subtract(ppos, pos)

            if vector.length(diff) <= 1.5 then
                local inv = player:get_inventory()
                for _, item_obj in pairs(self.carried_items) do
                    if item_obj and item_obj:get_pos() then
                        local ent = item_obj:get_luaentity()
                        if ent and ent.itemstring and inv then
                            local leftover = inv:add_item("main", ItemStack(ent.itemstring))
                            if leftover:is_empty() then
                                item_obj:remove()
                            else
                                ent.itemstring = leftover:to_string()
                                item_obj:set_pos(ppos)
                            end
                        end
                    end
                end
                if self.extra_wear > 0 and inv and not core.is_creative_enabled(self.thrower_name) then
                    local stack = inv:get_stack(self.hand_list, self.hand_idx)
                    if stack:get_name():find("^" .. modname .. ":disk_") then
                        local final_wear = math.floor(self.extra_wear / (self.ench_unbreaking + 1))
                        stack:add_wear(final_wear)
                        if stack:get_count() == 0 then core.sound_play(snd_break, {pos = ppos, gain = 0.9}, true) end
                        inv:set_stack(self.hand_list, self.hand_idx, stack)
                    end
                end
                core.sound_play(snd_throw, {pos = ppos, gain = 0.6, pitch = 1.4}, true)
                active_throws[self.thrower_name] = nil
                self.object:remove()
                return
            end

            -- CORE: Star (Loyal) Two-Way Strike hit detection
            if self.core_type == "star" then
                local ret_ray = core.raycast(pos, vector.add(pos, vector.multiply(self.vel, dtime)), true, false)
                for pointed in ret_ray do
                    if pointed.type == "object" and pointed.ref ~= self.object and pointed.ref ~= player then
                        local obj = pointed.ref
                        local ent = obj:get_luaentity()
                        if not is_projectile_entity(ent) and not (ent and ent.name == "__builtin:item") then
                            local id = tostring(obj)
                            if not self.hit_mobs[id] then
                                self.hit_mobs[id] = true
                                local ret_dmg = CONFIG.base_damage + (self.ench_sharpness * 1.5)
                                obj:punch(player, 1.0, { full_punch_interval = 1.0, damage_groups = {fleshy = ret_dmg} }, vector.normalize(self.vel))
                                fx_slash_hit(pointed.intersection_point or pos, vector.normalize(self.vel), self.trail_hex)
                            end
                        end
                    end
                end
            end

            self.vel = vector.multiply(vector.normalize(diff), CONFIG.return_speed + (self.bounces * 2))
            self.object:set_velocity(self.vel)
            return
        end

        -- 2. OUTWARD FLIGHT & COLLISION
        local step_vec = vector.multiply(self.vel, dtime)
        local step_dist = vector.length(step_vec)
        local ray = core.raycast(pos, vector.add(pos, step_vec), true, false)

        for pointed in ray do
            if pointed.type == "object" and pointed.ref ~= self.object and pointed.ref ~= player then
                local obj = pointed.ref
                local ent = obj:get_luaentity()
                if is_projectile_entity(ent) then
                    deflect_projectile(obj, pos)
                elseif not (ent and ent.name == "__builtin:item") then
                    local id = tostring(obj)
                    if not self.hit_mobs[id] then
                        self.hit_mobs[id] = true

                        -- Base + Bounce + Sharpness Hook + Sawtooth Bleed
                        local dmg = CONFIG.base_damage + math.floor(self.bounces * CONFIG.bounce_damage_bonus) + (self.ench_sharpness * 1.5)
                        if self.shape_type == "sawtooth" then
                            dmg = dmg + 2
                            self.vel = vector.multiply(self.vel, 0.85)
                            self.start_speed = self.start_speed * 0.85
                        end

                        -- Knockback Hook & Shield passive
                        local kb = ((self.shape_type == "shield") and 6 or 3) + (self.ench_knockback * 2)

                        obj:punch(player, 1.0, { full_punch_interval = 1.0, damage_groups = {fleshy = dmg} }, vector.multiply(vector.normalize(self.vel), kb))
                        self.extra_wear = self.extra_wear + (WEAR_UNIT * CONFIG.hit_wear_cost)
                        fx_slash_hit(pointed.intersection_point or pos, vector.normalize(self.vel), self.trail_hex)
                        self:update_momentum_loot(pointed.intersection_point or pos)

                        -- SHAPE: Star (Piercer) ignores pierce distance limits!
                        if self.shape_type ~= "star" and not self.pierce_dist then self.pierce_dist = 0 end
                    end
                end
            elseif pointed.type == "node" then
                local npos = pointed.under
                local nname = core.get_node(npos).name

                -- FEATURE: Remote Redstone / Mesecons Trigger
                trigger_redstone_node(npos, player, pointed)

                if core.registered_nodes[nname] and core.registered_nodes[nname].walkable then
                    local hit_p = pointed.intersection_point or pos

                    if CONFIG.break_fragile and is_breakable_node(nname) then
                        if not core.is_protected(npos, self.thrower_name) then
                            core.dig_node(npos)
                            self.extra_wear = self.extra_wear + (WEAR_UNIT * CONFIG.hit_wear_cost)
                            if self.bounces < 1 then self.bounces = 1 end
                            self:update_momentum_loot(npos)
                        end
                        fx_wall_sparks(hit_p, pointed.intersection_normal, self.trail_hex)
                        self.returning = true
                        return
                    end

                    -- CORE: Cross (Smasher) Wall Shockwave
                    if self.core_type == "cross" then
                        fx_shockwave(hit_p, self.trail_hex)
                        for _, obj in ipairs(core.get_objects_inside_radius(hit_p, 3)) do
                            local ent = obj:get_luaentity()
                            if obj ~= player and not is_projectile_entity(ent) and not (ent and ent.name == "__builtin:item") then
                                obj:punch(player, 1.0, { full_punch_interval = 1.0, damage_groups = {fleshy = 3} }, nil)
                            end
                        end
                    end

                    -- SHAPE: Chakram (Agile) gets +1 Bounce
                    local max_b = (self.shape_type == "chakram") and (CONFIG.max_bounces + 1) or CONFIG.max_bounces
                    if self.bounces >= max_b then
                        fx_wall_sparks(hit_p, pointed.intersection_normal, self.trail_hex)
                        self.returning = true
                        return
                    end

                    local n = pointed.intersection_normal
                    if n and (n.x ~= 0 or n.y ~= 0 or n.z ~= 0) then
                        self.vel = vector.subtract(self.vel, vector.multiply(n, 2 * vector.dot(self.vel, n)))
                    else
                        self.vel = vector.multiply(self.vel, -1)
                    end

                    self.bounces = self.bounces + 1
                    self.vel = vector.multiply(vector.normalize(self.vel), CONFIG.speed + (self.bounces * 1.5))
                    self.segment_dist = 0
                    self.hit_mobs = {}
                    fx_wall_sparks(hit_p, n, self.trail_hex)

                    local safe_pos = vector.add(hit_p, vector.multiply(vector.normalize(self.vel), 0.15))
                    self.object:set_pos(safe_pos)
                    self.object:set_velocity(self.vel)
                    core.sound_play(snd_bounce, {pos = safe_pos, gain = 0.85, pitch = 1.1 + (self.bounces * 0.15)}, true)
                    return
                end
            end
        end

        self.segment_dist = self.segment_dist + step_dist
        if self.pierce_dist then
            self.pierce_dist = self.pierce_dist + step_dist
            if self.pierce_dist >= CONFIG.pierce_follow_through then self.returning = true; return end
        end
        if self.segment_dist >= CONFIG.max_segment_dist then self.returning = true end
    end,
})

-- ============================================================================
-- FORGE GUI WITH IN-GAME BLUEPRINT GUIDE
-- ============================================================================
local function show_forge_formspec(player, stack, info_text)
    local shape, core_t, col = get_disk_meta(stack)
    local pname = player:get_player_name()
    local tex = core.formspec_escape(compose_disk_texture(shape, core_t, col))

    local p_s = BLUEPRINTS["shape_" .. shape] or ""
    local p_c = BLUEPRINTS["core_" .. core_t] or ""
    local default_txt = "Equipped Blueprints:\n- " .. p_s .. "\n- " .. p_c
    local txt = info_text or default_txt

    local fs = {
        "formspec_version[4]", "size[10,8.2]",
        "label[0.5,0.5;DISK Blueprint Forge]",
        "box[0.5,0.8;2.6,2.6;#1e293b]", "image[0.8,1.1;2.0,2.0;" .. tex .. "]",
        "box[3.4,0.8;6.1,1.5;#0f172a]",
        string.format("textarea[3.6,0.9;5.7,1.3;;;%s]", core.formspec_escape(txt)),

        "label[3.4,2.5;2. Core Module (Requires Gold/Redstone):]",
        "button[3.4,2.7;2.8,0.7;core_open;Hollow\n" .. UPGRADE_COSTS.core_open.label .. "]",
        "button[6.4,2.7;3.0,0.7;core_star;Star\n" .. UPGRADE_COSTS.core_star.label .. "]",
        "button[3.4,3.5;2.8,0.7;core_cross;Cross\n" .. UPGRADE_COSTS.core_cross.label .. "]",
        "button[6.4,3.5;3.0,0.7;core_tech;Tech\n" .. UPGRADE_COSTS.core_tech.label .. "]",

        string.format("label[3.4,4.5;Durability: %d%%]", math.floor(((65535 - stack:get_wear()) / 65535) * 100)),
        "button[5.2,4.3;4.2,0.65;repair_disk;Hammer Repair (1x Ingot)]",

        "label[0.5,4.8;1. Outer Shell (Requires Iron/Steel):]",
        "button[0.5,5.1;2.2,0.7;shape_chakram;Chakram\n" .. UPGRADE_COSTS.shape_chakram.label .. "]",
        "button[2.8,5.1;2.2,0.7;shape_shield;Shield\n" .. UPGRADE_COSTS.shape_shield.label .. "]",
        "button[5.1,5.1;2.2,0.7;shape_sawtooth;Sawtooth\n" .. UPGRADE_COSTS.shape_sawtooth.label .. "]",
        "button[7.4,5.1;2.0,0.7;shape_star;Shuriken\n" .. UPGRADE_COSTS.shape_star.label .. "]",

        "label[0.5,6.2;3. Structural Alloy (Requires Dyes):]",
    }

    for i, c in ipairs(COLORS) do
        local cost_label = UPGRADE_COSTS["col_" .. c.id].label
        table.insert(fs, string.format("button[%.2f,6.5;1.4,0.65;col_%s;%s\n%s]", 0.5 + (i - 1) * 1.5, c.id, c.name:match("^%S+"), cost_label))
    end

    core.show_formspec(pname, modname .. ":forge_gui", table.concat(fs))
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= modname .. ":forge_gui" then return end
    local stack = player:get_wielded_item()
    if not stack:get_name():find("^" .. modname .. ":disk_") then return end

    local shape, core_t, col = get_disk_meta(stack)
    local changed, info = false, nil
    local inv = player:get_inventory()

    if fields.repair_disk and stack:get_wear() > 0 then
        if inv and inv:contains_item("main", mat_iron) then
            inv:remove_item("main", mat_iron)
            stack:set_wear(math.max(0, stack:get_wear() - 32768))
            core.sound_play(snd_bounce, {pos = player:get_pos(), gain = 1.0, pitch = 0.9}, true)
            changed = true; info = "Repaired 50% durability!"
        else
            core.chat_send_player(player:get_player_name(), "Need 1 Iron/Steel Ingot to repair!")
        end
    end

    local function attempt_upgrade(key, current_val, new_val)
        if current_val == new_val then return current_val, false end
        local cost = UPGRADE_COSTS[key]
        if cost and cost.count > 0 then
            local cost_stack = ItemStack(cost.item .. " " .. cost.count)
            if not core.is_creative_enabled(player:get_player_name()) and not inv:contains_item("main", cost_stack) then
                core.chat_send_player(player:get_player_name(), "Missing materials: You need " .. cost.count .. "x " .. cost.item)
                return current_val, false
            end
            if not core.is_creative_enabled(player:get_player_name()) then
                inv:remove_item("main", cost_stack)
            end
        end
        return new_val, true
    end

    for k, _ in pairs(fields) do
        if BLUEPRINTS[k] then info = BLUEPRINTS[k] end
        if k:find("^shape_") then
            local new_s, success = attempt_upgrade(k, shape, k:sub(7))
            if success then shape = new_s; changed = true end
        elseif k:find("^core_") then
            local new_c, success = attempt_upgrade(k, core_t, k:sub(6))
            if success then core_t = new_c; changed = true end
        elseif k:find("^col_") then
            local new_col, success = attempt_upgrade(k, col, k:sub(5))
            if success then col = new_col; changed = true end
        end
    end

    if changed or info then
        stack:set_name(get_variant_itemname(shape, core_t, col))
        local meta = stack:get_meta()
        meta:set_string("disk_shape", shape)
        meta:set_string("disk_core", core_t)
        meta:set_string("disk_color", col)

        local p_s = BLUEPRINTS["shape_" .. shape]:match("^([%w%s]+)%s*%(Shape%)")
        local p_c = BLUEPRINTS["core_" .. core_t]:match("^([%w%s]+)%s*%(Core%)")
        meta:set_string("description", string.format("%s %s\nPassives: %s, %s\n(Sneak + Right-Click %s to Forge)",
            get_color_def(col).name, SHAPE_NAMES[shape], p_s, p_c, is_mcl and "Anvil" or "Steel Block"))

        player:set_wielded_item(stack)
        show_forge_formspec(player, stack, info)
    end
end)

-- ============================================================================
-- HAND-PARRY & THROW
-- ============================================================================
local function try_hand_parry(player, shape)
    if not CONFIG.parry_projectiles then return false end
    local ppos = vector.add(player:get_pos(), {x = 0, y = 1.4, z = 0})
    local r = (shape == "shield") and (CONFIG.hand_parry_radius * 2) or CONFIG.hand_parry_radius
    local parried = false

    for _, obj in ipairs(core.get_objects_inside_radius(ppos, r)) do
        if obj ~= player and is_projectile_entity(obj:get_luaentity()) then
            if vector.dot(player:get_look_dir(), vector.normalize(vector.subtract(obj:get_pos(), ppos))) > 0.2 then
                deflect_projectile(obj, ppos)
                parried = true
            end
        end
    end
    return parried
end

local function throw_disk(stack, player, pointed_thing, listname, idx)
    if pointed_thing and pointed_thing.type == "node" and player:get_player_control().sneak and is_forge_node(core.get_node(pointed_thing.under).name) then
        show_forge_formspec(player, stack)
        return stack
    end

    local shape, core_t, col = get_disk_meta(stack)
    if try_hand_parry(player, shape) and player:get_player_control().sneak then return stack end

    local pname = player:get_player_name()
    if not can_player_throw(pname, core_t) then return stack end

    -- Read Enchantment API Hooks
    local ench_data = {sharp = 0, unbreak = 0, knock = 0}
    if is_mcl and core.get_modpath("mcl_enchanting") and mcl_enchanting then
        ench_data.sharp = mcl_enchanting.get_enchantment(stack, "sharpness") or 0
        ench_data.unbreak = mcl_enchanting.get_enchantment(stack, "unbreaking") or 0
        ench_data.knock = (mcl_enchanting.get_enchantment(stack, "punch") or 0) + (mcl_enchanting.get_enchantment(stack, "knockback") or 0)
    end

    if not core.is_creative_enabled(pname) then
        local throw_wear = math.floor((WEAR_UNIT * CONFIG.throw_wear_cost) / (ench_data.unbreak + 1))
        stack:add_wear(throw_wear)
        if stack:get_count() == 0 then
            core.sound_play(snd_break, {pos = player:get_pos(), gain = 0.9}, true)
            return stack
        end
    end

    local ppos = player:get_pos()
    local dir = player:get_look_dir()
    local spawn_pos = vector.add(vector.add(ppos, {x = 0, y = 1.45, z = 0}), vector.multiply(dir, 0.8))

    local obj = core.add_entity(spawn_pos, modname .. ":flying_disk")
    if obj then
        local ent = obj:get_luaentity()
        if ent then
            ent:setup(player, dir, get_variant_itemname(shape, core_t, col), get_color_def(col).hex, listname or "main", idx or player:get_wield_index(), shape, core_t, ench_data)
            active_throws[pname] = {time = os.clock(), obj = ent}
            core.sound_play(snd_throw, {pos = spawn_pos, gain = 0.8, pitch = 1.0}, true)
        end
    end

    return stack
end

-- ============================================================================
-- REGISTER TOOL VARIANTS & OFFHAND LOGIC
-- ============================================================================
for _, shape in ipairs(SHAPES) do
    for _, core_t in ipairs(CORES) do
        for _, col in ipairs(COLORS) do
            local tex = compose_disk_texture(shape, core_t, col.id)
            core.register_tool(get_variant_itemname(shape, core_t, col.id), {
                description = SHAPE_NAMES[shape] .. "\n(Sneak + Right-Click " .. (is_mcl and "Anvil" or "Steel Block") .. " to Forge)",
                inventory_image = tex, wield_image = tex, wield_scale = {x = 1.3, y = 1.3, z = 0.9},
                groups = {
                    weapon = 1,
                    sword = 1, -- Allows Sword enchantments at enchanting tables/anvils in Mineclonia
                    offhand_item = 1,
                    disable_repair = 1,
                    not_in_creative_inventory = (shape == "chakram" and core_t == "open" and col.id == "steel") and 0 or 1
                },
                on_use = function(s, p, pt) return throw_disk(s, p, pt, "main", p:get_wield_index()) end,
                on_place = function(s, p, pt) return throw_disk(s, p, pt, "main", p:get_wield_index()) end,
                on_secondary_use = function(s, p, pt) return throw_disk(s, p, pt, "main", p:get_wield_index()) end,
            })
        end
    end
end

core.register_globalstep(function(dtime)
    for _, player in ipairs(core.get_connected_players()) do
        if player:get_player_control().RMB and not player:get_wielded_item():get_name():find("^" .. modname .. ":disk_") then
            local inv = player:get_inventory()
            if inv then
                local o_stack = inv:get_stack("offhand", 1)
                if o_stack and o_stack:get_name():find("^" .. modname .. ":disk_") then
                    inv:set_stack("offhand", 1, throw_disk(o_stack, player, nil, "offhand", 1))
                end
            end
        end
    end
end)

core.register_craft({
    output = modname .. ":disk_chakram",
    recipe = {
        {"", mat_iron, ""},
        {mat_iron, "", mat_iron},
        {"", mat_iron, ""}
    }
})