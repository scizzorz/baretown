printh("booting --------------------------------------------------------------", "log")
colors = {
  black = 0,
  dark_blue = 1,
  dark_purple = 2,
  dark_green = 3,
  brown = 4,
  dark_grey = 5,
  light_grey = 6,
  white = 7,
  red = 8,
  orange = 9,
  yellow = 10,
  green = 11,
  blue = 12,
  indigo = 13,
  pink = 14,
  peach = 15,
}

btns = {
  left = 0,
  right = 1,
  up = 2,
  down = 3,
  o = 4,
  x = 5,
}

char_colors = {
  colors.red,
  colors.blue,
  colors.green,
  colors.yellow,
}

tool_sprites = {
  pick = 1,
  axe = 2,
  sword = 3,
  bucket = 4,
  staff = 5,
  hammer = 6,
  sickle = 7,
  anvil = 8,
}

spawnable_tools = {
  "pick",
  "axe",
  "sword",
  "staff",
  "hammer",
  "sickle",
  "anvil",
}

startable_tools = {
  "pick",
  "axe",
  "sword",
  "staff",
  "hammer",
  "sickle",
}

music_songs = {
  main = 0,
}

sfx_list = {
  pickup_tool = 16,
  drop_tool = 17,
  ore_smack = 18,
  explode = 19,
  tree_smack = 20,
  honey_smack = 21,
  err = 22,
  pickup_loot = 21,
}

sfx_channels = {
  tool = 1,
}

map_tiles = {
  plain = 64,
  impasse = 65,
  node = 66,
}

decor_tiles = {
  80,
  96,
  112,
}

node_sprites = {
  ore = 16,
  tree = 17,
  honey = 18,
}

node_palette_swaps = {
  {
    ore = {[colors.light_grey] = colors.orange, [colors.white] = colors.yellow},
    tree = {[colors.green] = colors.orange, [colors.brown] = colors.dark_grey},
    honey = {[colors.orange] = colors.pink, [colors.yellow] = colors.blue},
  },
  {
    ore = {[colors.light_grey] = colors.blue, [colors.white] = colors.white},
    tree = {[colors.green] = colors.blue, [colors.brown] = colors.light_grey},
    honey = {[colors.orange] = colors.blue, [colors.yellow] = colors.peach},
  },
}

loot_sprites = {
  ore = 32,
  tree = 33,
  honey = 34,
}

spawnable_nodes = {
  "ore",
  "honey",
  "tree",
}

char_walk = {10, 26, 10, 42}

split_sep_color = colors.dark_blue
ui_arrow = 110
impassable_flag = 0
permanent_flag = 1
pickup_dist = 8
smack_dist = 12
collect_dist = 6

max_x = 1024
max_y = 512

map_w = max_x / 8
map_h = max_y / 8

center_x = max_x / 2
center_y = max_y / 2


-- utilities

function dist(x1, y1, x2, y2)
  -- this needs to be capped because of the Pico-8's numbers capping at like 32k.
  -- it roughly equates to having a maximum hypotenuse of 180ish
  local dx = min(abs(x1 - x2), 127)
  local dy = min(abs(y1 - y2), 127)
  return sqrt(dx * dx + dy * dy)
end

function disto(o1, o2)
  return dist(o1.x, o1.y, o2.x, o2.y)
end

function flr8(x)
  return flr(x / 8)
end

function draw_sprite(anim, ...)
  if type(anim) == "table" then
    local idx = flr(frame * (anim.fps or 10) / 60) % #anim + 1
    anim = anim[idx]
  end
  spr(anim, ...)
end

function screen_box(p, num)
  if num == 1 then
    return {x=0, y=0, w=128, h=128}
  elseif num == 2 or (num == 3 and p == 0) then
    return {x=0, y=p * 64, w=128, h=64}
  elseif num == 3 then
    return {x=(p - 1) * 64, y=64, w=64, h=64}
  end

  return {x=(p % 2) * 64, y=flr(p / 2) * 64, w=64, h=64}
end

-- base class

Object = {}
Object.__index = Object

-- constructor
function Object:__call(...)
  local this = setmetatable({}, self)
  return this, this:init(...)
end

-- methods
function Object:init() end
function Object:update() end
function Object:draw() end

-- subclassing
function Object:extend()
  proto = {}

  -- copy meta values, since lua
  -- doesn't walk the prototype
  -- chain to find them
  for k, v in pairs(self) do
    if sub(k, 1, 2) == "__" then
      proto[k] = v
    end
  end

  proto.__index = proto
  proto.__super = self

  return setmetatable(proto, self)
end

-- characters

Char = Object:extend()

function Char:init(p, x, y)
  self.p = p
  self.scry = flr(p / 2) * 64
  self.scrx = (p % 2) * 64
  self.x = x
  self.y = y
  self.face_left = false
  self.spr = char_walk
  self.color = char_colors[self.p + 1]
  self.tool = nil
  self.menu = false
  self.inv = {
    ore=0,
    tree=0,
    honey=0,
  }
  self.btns = {}
  self.btnstack = {}
end

function Char:set_clip(p, num)
  local box = screen_box(p, num)
  clip(box.x, box.y, box.x + box.w, box.y + box.h)
  camera(self.x - box.w / 2 - box.x + 4, self.y - box.h / 2 - box.y + 4)
end

function Char:draw_border(p, num)
  local box = screen_box(p, num)
  rect(box.x, box.y, box.x + box.w - 1, box.y + box.h - 1, split_sep_color)
end

function Char:reset_clip()
  clip()
  camera()
end

function Char:draw()
  -- draw sprite, remapping the red color to this player's color
  pal(colors.red, self.color)
  draw_sprite(self.spr, self.x, self.y, 1, 1, self.face_left)
  pal()

  -- draw our tool if it exists
  if self.tool ~= nil then
    self.tool:draw_held(self.x, self.y, self.face_left)
  end
end

function Char:draw_menu()
  -- draw menu if we have it open
  if self.menu then
    color(colors.dark_blue)
    rectfill(4 + self.scrx, 4 + self.scry, 60 + self.scrx, 60 + self.scry)
    color(colors.light_grey)
    rect(4 + self.scrx, 4 + self.scry, 60 + self.scrx, 60 + self.scry)

    draw_sprite(ui_arrow, 4 + self.scrx, 6 + self.scry)
    draw_sprite(loot_sprites.ore, 12 + self.scrx, 8 + self.scry)
    print(inv.ore, 18 + self.scrx, 8 + self.scry, colors.white)
    draw_sprite(loot_sprites.tree, 26 + self.scrx, 8 + self.scry)
    print(inv.tree, 32 + self.scrx, 8 + self.scry, colors.white)
    draw_sprite(loot_sprites.honey, 40 + self.scrx, 8 + self.scry)
    print(inv.honey, 46 + self.scrx, 8 + self.scry, colors.white)

    for i, char in pairs(chars) do
      pal(colors.white, char_colors[i])
      draw_sprite(ui_arrow, 4 + self.scrx, 6 + self.scry + i * 11)
      pal()

      draw_sprite(loot_sprites.ore, 12 + self.scrx, 8 + self.scry + i * 11)
      print(char.inv.ore, 18 + self.scrx, 8 + self.scry + i * 11, colors.white)
      draw_sprite(loot_sprites.tree, 26 + self.scrx, 8 + self.scry + i * 11)
      print(char.inv.tree, 32 + self.scrx, 8 + self.scry + i * 11, colors.white)
      draw_sprite(loot_sprites.honey, 40 + self.scrx, 8 + self.scry + i * 11)
      print(char.inv.honey, 46 + self.scrx, 8 + self.scry + i * 11, colors.white)
    end
  end
end

function check_collision(x, y)
  local mx = flr(x / 8)
  local my = flr(y / 8)
  local mtile = mget(mx, my)
  return fget(mtile, impassable_flag)
end

function Char:move(dx, dy)
  -- update our facing if this movement had any x component
  if dx ~= 0 then
    self.face_left = (dx < 0)
  end

  -- diagonal movement isn't allowed because it was choppy.
  -- with the button stack method prevents it.
  -- if it somehow *does* make it this far, the player should
  -- be rewarded with the 41% movespeed bonus.

  -- move!
  if (frame % 2) == 0 then
    self.x += dx
    self.y += dy
  end

  -- check collision
  local collision_tl = check_collision(self.x, self.y)
  local collision_tr = check_collision(self.x + 8, self.y)
  local collision_bl = check_collision(self.x, self.y + 8)
  local collision_br = check_collision(self.x + 8, self.y + 8)

  -- only fix collision in a direction we're moving
  -- FIXME some weird collision failure when moving right or down inline with
  -- an impassable block... probably because of the weird nested collision
  -- rules I had to add... fuc
  if dy < 0 and (collision_tl or collision_tr) then
    -- don't adjust Y position if *both* corners are blocked!
    if not (collision_tl and collision_bl) and not (collision_tr and collision_br) then
      self.y = flr(self.y / 8) * 8 + 8
    end
  end

  if dy > 0 and (collision_bl or collision_br) then
    -- see above
    if not (collision_tl and collision_bl) and not (collision_tr and collision_br) then
      self.y = flr(self.y / 8) * 8
    end
  end

  if dx < 0 and (collision_tl or collision_bl) then
    -- see above
    if not (collision_tl and collision_tr) and not (collision_bl and collision_br) then
      self.x = flr(self.x / 8) * 8 + 8
    end
  end

  if dx > 0 and (collision_tr or collision_br) then
    -- see above
    if not (collision_tl and collision_tr) and not (collision_bl and collision_br) then
      self.x = flr(self.x / 8) * 8
    end
  end

  -- map bounds
  -- in theory, the map should have a 4-block impassable border... but... whatever.
  if self.x < 0 then self.x = 0 end
  if self.y < 0 then self.y = 0 end
  if self.x > max_x - 8 then self.x = max_x - 8 end
  if self.y > max_y - 8 then self.y = max_y - 8 end
end

function Char:check_buttons()
  self:check_button("up")
  self:check_button("down")
  self:check_button("left")
  self:check_button("right")
end

function Char:check_button(name)
  if btn(btns[name], self.p) then
    -- if this is the first frame we've seen this button press, save the
    -- frame number and add it to our button press stack.
    -- this is nested because we don't want to reset it until the
    -- button is let go
    if self.btns[name] == nil then
      self.btns[name] = frame
      add(self.btnstack, name)
    end

  else
    -- the button is no longer pressed, reset its frame count and remove it
    -- from our stack
    self.btns[name] = nil
    del(self.btnstack, name)
  end
end

function Char:top_button()
  -- return the topmost item in the button stack
  if #self.btnstack > 0 then
    return self.btnstack[#self.btnstack]
  end

  return nil
end

function Char:update()
  self.menu = btn(btns.o, self.p) and btn(btns.x, self.p)

  if self.menu then
    self:update_menu()
  else
    self:update_world()
  end
end

function Char:update_world()
  -- movement
  local dx = 0
  local dy = 0

  -- check which buttons are pressed, figure out which is the most
  -- recently pressed, then move that way
  self:check_buttons()
  local move = self:top_button()
  if move == "up" then dy = -1 end
  if move == "down" then dy = 1 end
  if move == "left" then dx = -1 end
  if move == "right" then dx = 1 end
  self:move(dx, dy)

  -- pick up or drop tools
  if btnp(btns.o, self.p) then
    -- drop held tool
    if self.tool ~= nil then
      add(tools, self.tool)
      self.tool:drop(self)
      self.tool = nil
      sfx(sfx_list.drop_tool, sfx_channels.tool)

    -- pick up a new tool
    else
      for i, tool in pairs(tools) do
        -- pick up if distance < 8 pixels
        if disto(self, tool) < pickup_dist then
          self.tool = tool
          del(tools, tool)
          sfx(sfx_list.pickup_tool, sfx_channels.tool)
          break
        end
      end

      if self.tool == nil then
        sfx(sfx_list.err, sfx_channels.tool)
      end
    end
  end

  -- use our tool
  if btnp(btns.x, self.p) then
    if self.tool ~= nil then
      if not self.tool:use(self) then
        sfx(sfx_list.err, sfx_channels.tool)
      end
    else
      local interacted = false

      -- find all grounded tools and see if we can interact with any of them
      for i, tool in pairs(tools) do
        -- check interact distance
        if disto(self, tool) < pickup_dist and tool_interacts[tool.name] ~= nil then
          interacted = tool_interacts[tool.name](tool, self)
          if interacted then
            break
          end
        end
      end

      if not interacted then
        sfx(sfx_list.err, sfx_channels.tool)
      end

    end
  end
end

function Char:update_menu()
end

-- tools

Tool = Object:extend()

function Tool:init(name, x, y, level)
  self.name = name
  self.x = x
  self.y = y
  self.level = level or 0
end

function Tool:set_palette()
  if self.level == 1 then
    pal(colors.light_grey, colors.orange)
    pal(colors.white, colors.yellow)
    pal(colors.brown, colors.dark_grey)
    pal(colors.dark_grey, colors.brown)
  end

  if self.level == 2 then
    pal(colors.light_grey, colors.dark_blue)
    pal(colors.white, colors.blue)
    pal(colors.brown, colors.white)
    pal(colors.dark_grey, colors.indigo)
  end
end

function Tool:reset_palette()
  palt()
  pal()
end

function Tool:draw()
  self:set_palette()

  draw_sprite(tool_sprites[self.name], self.x, self.y)

  self:reset_palette()
end

function Tool:draw_held(x, y, face_left)
  local offset = 6
  if face_left then
    offset = -offset
  end

  self:set_palette()
  draw_sprite(tool_sprites[self.name], x + offset, y - 2, 1, 1, face_left)
  self:reset_palette()
end

function Tool:drop(owner)
  self.x = owner.x
  self.y = owner.y
end

function Tool:use(char)
  if tool_uses[self.name] ~= nil then
    return tool_uses[self.name](self, char)
  end

  return false
end

function Smacker(node_name)
  return function(tool, char)
    for i, node in pairs(nodes) do
      if node.name == node_name and disto(char, node) < smack_dist then
        sfx(sfx_list[node.name.."_smack"], sfx_channels.tool)
        node:hit(shl(1, tool.level)) -- 2^level

        if node:is_dead() then
          sfx(sfx_list.explode, sfx_channels.tool)
          node:explode()
          del(nodes, node)
        end

        return true
      end
    end

    return false
  end
end

tool_uses = {}
tool_uses.pick = Smacker("ore")
tool_uses.sickle = Smacker("honey")
tool_uses.axe = Smacker("tree")
tool_uses.hammer = Smacker("ore")

tool_interacts = {}
tool_interacts.anvil = function()
  sfx(sfx_list.ore, sfx_channels.tool)
  return true
end


Bucket = Tool:extend()

function Bucket:init(x, y, level, filled)
  Tool.init(self, "bucket", x, y, level)
  self.filled = filled or false
end

function Bucket:set_palette()
  Tool.set_palette(self)

  -- buckets use black as the "empty" color, so
  -- green is set as the transparency color
  palt(colors.black, false)
  palt(colors.green, true)

  -- then red is swapped out to our "empty" color
  if self.filled then
    pal(colors.red, colors.blue)
  else
    pal(colors.red, colors.black)
  end
end

-- resources

Node = Object:extend()

function Node:init(name, x, y, level)
  self.name = name
  self.x = x
  self.y = y
  self.level = level or 0
  self.hp = shl(hp or 8, self.level * 2) -- 8 * 2^(2 * level)

  mset(x / 8, y / 8, map_tiles.node)
end

function Node:set_palette()
  if self.level > 0 then
    local swap = node_palette_swaps[self.level][self.name]
    for from, to in pairs(swap) do
      pal(from, to)
    end
  end
end

function Node:reset_palette()
  pal()
  palt()
end

function Node:draw()
  self:set_palette()
  draw_sprite(node_sprites[self.name], self.x, self.y)
  self:reset_palette()
end

function Node:spew_particle(amt)
  local sx = (node_sprites[self.name] % 16) * 8
  local sy = flr(node_sprites[self.name] / 16) * 8

  for n=0, (amt or 1) do
    local c = colors.black
    while c == colors.black do
      c = sget(sx + rnd(8), sy + rnd(8))
    end
    local pt = Particle(c, self.x + 4, self.y + 4)
    add(particles, pt)
  end
end

function Node:spew_loot(amt)
  for n=1, (amt or 1) do
    local lt = Loot(self.name, self.x + 4, self.y + 4)
    add(loots, lt)
  end
end

function Node:hit(amt)
  self:spew_particle(amt)

  amt = amt or 1
  while amt > 0 do
    amt -= 1
    self.hp -= 1

    if self.hp % 2 == 0 then
      self:spew_loot()
    end

    if self.hp == 0 then
      self:spew_loot(1 + self.level * 2)
    end
  end
end

function Node:is_dead()
  return self.hp <= 0
end

function Node:explode()
  mset(self.x / 8, self.y / 8, map_tiles.plain)
  self:spew_particle(16)
end

-- map

Map = Object:extend()

function Map:draw_for(char)
  -- draw the map from a character's perspective.
  -- this is done to save on render time - no need to draw the full 128x64 map
  -- for each character's frame when we can just draw a single 10x10 and cover
  -- their entire screen
  local mx = flr(char.x / 8) - 8
  local my = flr(char.y / 8) - 8
  map(mx, my, mx * 8, my * 8, 19, 19)
end

-- particle effects

Particle = Object:extend()

function Particle:init(c, x, y, dx, dy)
  self.c = c
  self.x = x
  self.y = y
  self.dx = dx or (rnd(2) - 1)
  self.dy = dy or (rnd(2) - 1)
end

function Particle:update()
  if abs(self.dx) >= 0.1 then
    self.x += self.dx
  end
  if abs(self.dy) >= 0.1 then
    self.y += self.dy
  end
  self.dx *= 0.9
  self.dy *= 0.9
end

function Particle:is_dead()
  return abs(self.dx) < 0.1 or abs(self.dy) < 0.1
end

function Particle:draw()
  pset(self.x, self.y, self.c)
end


Loot = Particle:extend() -- so what

function Loot:init(name, x, y, dx, dy)
  self.name = name
  Particle.init(self, nil, x, y, dx, dy)
end

function Loot:draw()
  draw_sprite(loot_sprites[self.name], self.x - 2, self.y - 2)
end

-- game state

world = Map()
nodes = {}
chars = {}
chars_enabled = {}
tools = {}
particles = {}
loots = {}
frame = 0
inv = {
  ore = 0,
  tree = 0,
  honey = 0,
}

for x=0, map_w - 1 do
  for y=0, map_h - 1 do
    -- only adjust tiles that aren't marked as impassable by the map editor
    local tile = mget(x, y)
    if not fget(tile, permanent_flag) then
      -- random decoration tiles
      if rnd(32) < 1 then
        local decor = flr(rnd(#decor_tiles)) + 1
        mset(x, y, decor_tiles[decor])

      -- random node spawns
      elseif rnd(32) < 1 then
        -- choose a random power level
        local level = 0
        if rnd(128) < 1 then
          level = 2
        elseif rnd(64) < 1 then
          level = 1
        end

        -- choose a random node
        local name = spawnable_nodes[flr(rnd(#spawnable_nodes)) + 1]
        local node = Node(name, x * 8, y * 8, level)
        add(nodes, node)

      -- random tooll spawn
      elseif rnd(2048) < 1 then

        mset(x, y, map_tiles.plain)

        -- choose a random power level
        local level = 0
        if rnd(64) < 1 then
          level = 2
        elseif rnd(32) < 1 then
          level = 1
        end

        -- choose a random tool
        local name = spawnable_tools[flr(rnd(#spawnable_tools)) + 1]
        local tool = Tool(name, x * 8, y * 8, level)
        printh("Spawning a "..name, "log")

        add(tools, tool)

      -- plain
      else
        mset(x, y, map_tiles.plain)
      end
    end
  end
end

-- create players
function add_char(p)
  if chars_enabled[p] then
    return
  end

  local x = (p % 2)
  local y = flr(p / 2)

  -- spawn the character
  chars_enabled[p] = true
  add(chars, Char(p, center_x - 8 + x * 16, center_y - 8 + y * 16))

  -- spawn a tool for them
  local level = 0
  if rnd(128) < 1 then
    level = 2
  elseif rnd(64) < 1 then
    level = 1
  end

  local name = startable_tools[flr(rnd(#startable_tools)) + 1]
  local tool = Tool(name, center_x - 16 + x * 32, center_y - 16 + y * 32, level)
  add(tools, tool)
end

add_char(0)

-- game code
function _init()
  cls()

  -- music(music_songs.main)
end

function _update60()
  frame += 1

  -- check to see if any new players have pushed a button to join
  for i = 1, 3 do
    if not chars_enabled[i] then
      for j = 0, 5 do
        if btn(j, i) then
          add_char(i)
          break
        end
      end
    end
  end

  for i, char in pairs(chars) do
    char:update()
  end

  for i, pt in pairs(particles) do
    pt:update()
    if pt:is_dead() then
      del(particles, pt)
    end
  end

  for i, lt in pairs(loots) do
    lt:update()
    if lt:is_dead() then
      for j, char in pairs(chars) do
        if dist(lt.x, lt.y, char.x + 4, char.y + 4) < collect_dist then
          char.inv[lt.name] += 1
          sfx(sfx_list.pickup_loot, sfx_channels.tool)
          del(loots, lt)
          break
        end
      end
    end
  end
end

function _draw()
  for p, cam in pairs(chars) do
    cam:set_clip(p - 1, #chars)

    world:draw_for(cam)

    for i, tool in pairs(tools) do
      tool:draw()
    end

    for i, node in pairs(nodes) do
      node:draw()
    end

    for i, lt in pairs(loots) do
      lt:draw()
    end

    for i, pt in pairs(particles) do
      pt:draw()
    end

    for i, char in pairs(chars) do
      char:draw(i, #chars)
    end

    cam:reset_clip()

    if cam.menu then
      cam:draw_menu()
    end

    cam:draw_border(p - 1, #chars)
  end

  -- draw split screen separators
  -- rect(0, 0, 63, 63, split_sep_color)
  -- rect(64, 0, 127, 63, split_sep_color)
  -- rect(0, 64, 63, 127, split_sep_color)
  -- rect(64, 64, 127, 127, split_sep_color)

  --[[
  -- draw friend trackers
  for i, me in pairs(chars) do
    -- draw friend indicators
    for j, you in pairs(chars) do
      if i ~= j then
        if abs(you.x - me.x) > 32 or abs(you.y - me.y) > 32 then
          local angle = atan2(you.x - me.x, you.y - me.y)
          local offx = min(max(cos(angle) * 45, -32), 31)
          local offy = min(max(sin(angle) * 45, -32), 31)
          pset(me.scrx + 32 + offx, me.scry + 32 + offy, char_colors[j])

          offx = min(max(cos(angle) * 45, -31), 30)
          offy = min(max(sin(angle) * 45, -31), 30)
          pset(me.scrx + 32 + offx, me.scry + 32 + offy, char_colors[j])
        end
      end
    end

    -- draw town indicator
    if abs(center_x - me.x) > 32 or abs(center_y - me.y) > 32 then
      local angle = atan2(center_x - me.x, center_y - me.y)
      local offx = min(max(cos(angle) * 45, -32), 31)
      local offy = min(max(sin(angle) * 45, -32), 31)
      pset(me.scrx + 32 + offx, me.scry + 32 + offy, colors.white)

      offx = min(max(cos(angle) * 45, -31), 30)
      offy = min(max(sin(angle) * 45, -31), 30)
      pset(me.scrx + 32 + offx, me.scry + 32 + offy, colors.white)
    end
  end
  ]]

  if false then
    local mem = flr(stat(0) * 100 / 512)
    local cpu = flr(stat(1) * 100)
    local sys = flr(stat(2) * 100)
    print("mem " .. mem, 1, 1, colors.black)
    print("mem " .. mem, 0, 0, colors.white)

    print("cpu " .. cpu, 1, 9, colors.black)
    print("cpu " .. cpu, 0, 8, colors.white)

    print("sys " .. sys, 1, 17, colors.black)
    print("sys " .. sys, 0, 16, colors.white)
  end
end
