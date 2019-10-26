printh("booting --------------------------------------------------------------", "log")

-- rename sfx => play_sfx
-- this lets us use sfx as a table name
_sfx = sfx
function play_sfx(n, ...)
  _sfx(n or -1, ...)
end

-- rename music => play_music
-- this lets us use music as a table name
_music = music
function play_music(n, ...)
  _music(n or -1, ...)
end

-- color palette
color = {
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

-- button
button = {
  left = 0,
  right = 1,
  up = 2,
  down = 3,
  o = 4,
  x = 5,
  start = 6,
}

-- player colors
char_colors = {
  color.red,
  color.blue,
  color.green,
  color.yellow,
}

-- graphics
gfx = {
  tool = {
    pick = 1,
    axe = 2,
    sword = 3,
    bucket = 4,
    staff = 5,
    hammer = 6,
    sickle = 7,
    anvil = 8,
  },
  node = {
    ore = 16,
    tree = 17,
    honey = 18,
  },
  loot = {
    ore = 32,
    tree = 33,
    honey = 34,
  },
  char = {
    stand = 10,
    walk = {10, 26, 10, 42},
  },
  ui = {
    arrow = 110,
  },
  map = {
    plain = 64,
    impasse = 65,
    node = 66, -- drawn behind node spawns
    decor = {80, 96, 112}, -- randomly strewn throughout world
  },
}

-- graphics flags
flag = {
  impassable = 0,
  permanent = 1,
}

-- songs
music = {
  main = 0,
}

-- sound effects
sfx = {
  tool = {
    pickup = 16,
    drop = 17,
    none = 22,
  },
  err = 22,
  die = {
    ore = 19,
    tree = 19,
    honey = 19,
  },
  smack = {
    ore = 18,
    tree = 20,
    honey = 21,
  },
  loot = {
    ore = 21,
    tree = 21,
    honey = 21,
  },
  use = {
    fail = 22,
    cant = 22,
  },
  interact = {
    fail = 22,
    cant = 22,
  },
}

node_palette_swaps = {
  {
    ore = {[color.light_grey] = color.orange, [color.white] = color.yellow},
    tree = {[color.green] = color.orange, [color.brown] = color.dark_grey},
    honey = {[color.orange] = color.pink, [color.yellow] = color.blue},
  },
  {
    ore = {[color.light_grey] = color.blue, [color.white] = color.white},
    tree = {[color.green] = color.blue, [color.brown] = color.light_grey},
    honey = {[color.orange] = color.blue, [color.yellow] = color.peach},
  },
}

-- which nodes can spawn throughout the world
spawnable_nodes = {
  "ore",
  "honey",
  "tree",
}

-- which tools can spawn throughout the world
spawnable_tools = {
  "pick",
  "axe",
  "sword",
  "staff",
  "hammer",
  "sickle",
  "anvil",
}

-- which tools can start in town
startable_tools = {
  "pick",
  "axe",
  "sword",
  "staff",
  "hammer",
  "sickle",
}

-- color of the screen border
split_sep_color = color.dark_blue

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

-- draw a sprite or an animation table
-- anim: either a spritesheet ID or an array of spritesheet IDs
--       if the latter, the animation framerate is taken from the .fps field of
--       the table, defaulting to 10
function draw_sprite(anim, ...)
  if type(anim) == "table" then
    local idx = flr(frame * (anim.fps or 10) / 60) % #anim + 1
    anim = anim[idx]
  end
  spr(anim, ...)
end

-- calculate the renderable splitscreen box for a character
-- p: 0-based player number
-- num: the number of screens being drawn
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

-- draw a single pixel around a box border indicating a direction
-- from: source object
-- to: destination object
-- box: screen box to draw the tracker in
-- color: which color to draw the tracker
function draw_tracker(from, to, box, color)
  if abs(to.x - from.x) > box.w / 2 or abs(to.y - from.y) > box.h / 2 then
    local angle = atan2(to.x - from.x, to.y - from.y)
    local dx = cos(angle)
    local dy = sin(angle)
    local x = box.x + box.w / 2
    local y = box.y + box.h / 2

    -- trace to the edge of the box
    while x > box.x and x < box.x + box.w - 1 and y > box.y and y < box.y + box.h - 1 do
      x += dx
      y += dy
    end

    -- clamp into box
    x = min(max(x, box.x), box.x + box.w - 1)
    y = min(max(y, box.y), box.y + box.h - 1)

    -- draw indicator
    pset(x, y, color)
  end
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
  self.spr = gfx.char.walk
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
  pal(color.red, self.color)
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
    rectfill(4 + self.scrx, 4 + self.scry, 60 + self.scrx, 60 + self.scry, color.dark_blue)
    rect(4 + self.scrx, 4 + self.scry, 60 + self.scrx, 60 + self.scry, color.light_grey)

    draw_sprite(gfx.ui.arrow, 4 + self.scrx, 6 + self.scry)
    draw_sprite(gfx.loot.ore, 12 + self.scrx, 8 + self.scry)
    print(inv.ore, 18 + self.scrx, 8 + self.scry, color.white)
    draw_sprite(gfx.loot.tree, 26 + self.scrx, 8 + self.scry)
    print(inv.tree, 32 + self.scrx, 8 + self.scry, color.white)
    draw_sprite(gfx.loot.honey, 40 + self.scrx, 8 + self.scry)
    print(inv.honey, 46 + self.scrx, 8 + self.scry, color.white)

    for i, char in pairs(chars) do
      pal(color.white, char.color)
      draw_sprite(gfx.ui.arrow, 4 + self.scrx, 6 + self.scry + i * 11)
      pal()

      draw_sprite(gfx.loot.ore, 12 + self.scrx, 8 + self.scry + i * 11)
      print(char.inv.ore, 18 + self.scrx, 8 + self.scry + i * 11, color.white)
      draw_sprite(gfx.loot.tree, 26 + self.scrx, 8 + self.scry + i * 11)
      print(char.inv.tree, 32 + self.scrx, 8 + self.scry + i * 11, color.white)
      draw_sprite(gfx.loot.honey, 40 + self.scrx, 8 + self.scry + i * 11)
      print(char.inv.honey, 46 + self.scrx, 8 + self.scry + i * 11, color.white)
    end
  end
end

function check_collision(x, y)
  local mx = flr(x / 8)
  local my = flr(y / 8)
  local mtile = mget(mx, my)
  return fget(mtile, flag.impassable)
end

function Char:move(dx, dy)
  -- update our facing if this movement had any x component
  if dx ~= 0 then
    self.face_left = (dx < 0)
  end

  -- diagonal movement isn't allowed because it was choppy.
  -- the button stack method prevents it.
  -- if it somehow *does* make it this far, the player should
  -- be rewarded with the 41% movespeed bonus.

  -- only move every other frame to keep speeds in check
  if (frame % 2) == 1 then
    return
  end

  -- move!
  self.x += dx
  self.y += dy

  -- check collision
  local collision_tl = check_collision(self.x, self.y)
  local collision_tr = check_collision(self.x + 7, self.y)
  local collision_bl = check_collision(self.x, self.y + 7)
  local collision_br = check_collision(self.x + 7, self.y + 7)

  -- if we are now colliding with something, undo the movement
  if collision_tl or collision_tr or collision_bl or collision_br then
    self.x -= dx
    self.y -= dy
  end

  -- check map bounds
  -- in theory, the map should have an impassable border... but... whatever.
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
  if btn(button[name], self.p) then
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
  self.menu = btn(button.o, self.p) and btn(button.x, self.p)

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
  if btnp(button.o, self.p) then
    -- drop held tool
    if self.tool ~= nil then
      add(tools, self.tool)
      self.tool:drop(self)
      self.tool = nil
      play_sfx(sfx.tool.drop, self.p)

    -- pick up a new tool
    else
      for i, tool in pairs(tools) do
        -- pick up if distance < 8 pixels
        if disto(self, tool) < pickup_dist then
          self.tool = tool
          del(tools, tool)
          play_sfx(sfx.tool.pickup, self.p)
          break
        end
      end

      if self.tool == nil then
        play_sfx(sfx.tool.none, self.p)
      end
    end
  end

  -- use our tool
  if btnp(button.x, self.p) then
    if self.tool ~= nil then
      local used = self.tool:use(self)

      -- play appropriate sfx for failures
      if used == nil then
        play_sfx(sfx.use.cant, self.p)
      elseif used == false then
        play_sfx(sfx.use.fail, self.p)
      end

    else
      local interacted = nil

      -- find all grounded tools and see if we can interact with any of them
      for i, tool in pairs(tools) do
        -- check interact distance and then try to use it
        if disto(self, tool) < pickup_dist then
          interacted = tool:interact(self)
          if interacted ~= nil then
            break
          end
        end
      end

      -- play appropriate sfx for failures
      if interacted == nil then
        play_sfx(sfx.interact.cant, self.p)
      elseif interacted == false then
        play_sfx(sfx.interact.fail, self.p)
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
    pal(color.light_grey, color.orange)
    pal(color.white, color.yellow)
    pal(color.brown, color.dark_grey)
    pal(color.dark_grey, color.brown)
  end

  if self.level == 2 then
    pal(color.light_grey, color.dark_blue)
    pal(color.white, color.blue)
    pal(color.brown, color.white)
    pal(color.dark_grey, color.indigo)
  end
end

function Tool:reset_palette()
  palt()
  pal()
end

function Tool:draw()
  self:set_palette()

  draw_sprite(gfx.tool[self.name], self.x, self.y)

  self:reset_palette()
end

function Tool:draw_held(x, y, face_left)
  local offset = 6
  if face_left then
    offset = -offset
  end

  self:set_palette()
  draw_sprite(gfx.tool[self.name], x + offset, y - 2, 1, 1, face_left)
  self:reset_palette()
end

function Tool:drop(owner)
  self.x = owner.x
  self.y = owner.y
end

-- returns true if a tool succeeded
-- returns false if a tool failed
-- returns nil if a tool can't be used
function Tool:use(char)
  if self.uses[self.name] ~= nil then
    return self.uses[self.name](self, char)
  end

  return nil
end

-- returns true if a tool interaction succeeded
-- returns false if a tool interaction failed
-- returns nil if a tool can't be interacted with
function Tool:interact(char)
  if self.interactions[self.name] ~= nil then
    return self.interactions[self.name](self, char)
  end

  return nil
end

-- tool interactions

function Smacker(node_name)
  return function(tool, char)
    for i, node in pairs(nodes) do
      if node.name == node_name and disto(char, node) < smack_dist then
        play_sfx(sfx.smack[node.name], char.p)
        node:hit(shl(1, tool.level)) -- 2^level

        if node:is_dead() then
          play_sfx(sfx.die[node.name], char.p)
          node:explode()
          del(nodes, node)
        end

        return true
      end
    end

    return false
  end
end

-- return true if the use/interaction was successful
-- return false if the use/interaction was a failure
Tool.uses = {}
Tool.uses.pick = Smacker("ore")
Tool.uses.sickle = Smacker("honey")
Tool.uses.axe = Smacker("tree")
Tool.uses.hammer = Smacker("ore")

Tool.interactions = {}
Tool.interactions.anvil = function(tool, char)
  play_sfx(sfx.smack.ore, char.p)
  return true
end

-- bucket has a fancy draw method because it's filled / empty

Bucket = Tool:extend()

function Bucket:init(x, y, level, filled)
  Tool.init(self, "bucket", x, y, level)
  self.filled = filled or false
end

function Bucket:set_palette()
  Tool.set_palette(self)

  -- buckets use black as the "empty" color, so
  -- green is set as the transparency color
  palt(color.black, false)
  palt(color.green, true)

  -- then red is swapped out to our "empty" color
  if self.filled then
    pal(color.red, color.blue)
  else
    pal(color.red, color.black)
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

  mset(x / 8, y / 8, gfx.map.node)
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
  draw_sprite(gfx.node[self.name], self.x, self.y)
  self:reset_palette()
end

function Node:spew_particle(amt)
  local sx = (gfx.node[self.name] % 16) * 8
  local sy = flr(gfx.node[self.name] / 16) * 8

  for n=0, (amt or 1) do
    local c = color.black
    while c == color.black do
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
  mset(self.x / 8, self.y / 8, gfx.map.plain)
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


-- loot

Loot = Particle:extend() -- so what

function Loot:init(name, x, y, dx, dy)
  self.name = name
  Particle.init(self, nil, x, y, dx, dy)
end

function Loot:draw()
  draw_sprite(gfx.loot[self.name], self.x - 2, self.y - 2)
end

-- player join
function add_char(p)
  if chars_enabled[p] then
    return
  end

  local x = (p % 2)
  local y = flr(p / 2)

  -- spawn the character
  chars_enabled[p] = true
  add(chars, Char(p, center_x - 8 + x * 16, center_y - 8 + y * 16))
end

-- generate a map
function build_map()
  for x=0, map_w - 1 do
    for y=0, map_h - 1 do
      -- only adjust tiles that aren't marked as impassable by the map editor
      local tile = mget(x, y)
      if not fget(tile, flag.permanent) then
        -- random decoration tiles
        if rnd(32) < 1 then
          local decor = flr(rnd(#gfx.map.decor)) + 1
          mset(x, y, gfx.map.decor[decor])

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
          mset(x, y, gfx.map.plain)

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
          mset(x, y, gfx.map.plain)
        end
      end
    end
  end
end

function spawn_tools()
  for x = 0, 1 do
    for y = 0, 1 do
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
  end
end

-- game code
function _init()
  cls()

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

  build_map()
  spawn_tools()
  add_char(0)

  play_music(music.main and nil)
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
          play_sfx(sfx.loot[lt.name], char.p)
          del(loots, lt)
          break
        end
      end
    end
  end
end

function _draw()
  cls()

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

  -- draw friend trackers
  local town = {x=center_x, y=center_y}
  for i, me in pairs(chars) do
    -- draw friend indicators
    local box = screen_box(i - 1, #chars)
    for j, you in pairs(chars) do
      if i ~= j then
        draw_tracker(me, you, box, you.color)
      end
    end

    -- draw town indicator
    draw_tracker(me, town, box, color.white)
  end

  if false then
    local mem = flr(stat(0) * 100 / 512)
    local cpu = flr(stat(1) * 100)
    local sys = flr(stat(2) * 100)
    print("mem " .. mem, 1, 1, color.black)
    print("mem " .. mem, 0, 0, color.white)

    print("cpu " .. cpu, 1, 9, color.black)
    print("cpu " .. cpu, 0, 8, color.white)

    print("sys " .. sys, 1, 17, color.black)
    print("sys " .. sys, 0, 16, color.white)
  end
end
