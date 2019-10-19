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
}

spawnable_tools = {
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
  pick_up = 63,
  drop = 62,
  ore_smack = 61,
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
  ore = 74,
}

split_sep_color = colors.dark_blue
ui_corner_sprite = 110
ui_middle_sprite = 111
impassable_flag = 0
permanent_flag = 1
pickup_dist = 8
collect_dist = 12

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
  self.spr = 10
  self.color = char_colors[self.p + 1]
  self.speed = 0.5
  self.tool = nil
  self.btns = {}
  self.btnstack = {}
  music(music_songs.main)
end

function Char:set_clip()
  clip(self.scrx, self.scry, self.scrx + 64, self.scry + 64)
  camera(self.x - self.scrx - 28, self.y - self.scry - 28)
end

function Char:reset_clip()
  clip()
  camera()
end

function Char:draw()
  -- draw sprite, remapping the red color to this player's color
  pal(colors.red, self.color)
  spr(self.spr, self.x, self.y, 1, 1, self.face_left)
  pal()

  -- draw our tool if it exists
  if self.tool ~= nil then
    self.tool:draw_held(self.x, self.y, self.face_left)
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
  self.x += dx * self.speed
  self.y += dy * self.speed

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
      sfx(sfx_list.drop, sfx_channels.tool)

    -- pick up a new tool
    else
      for i, tool in pairs(tools) do
        -- pick up if distance < 8 pixels
        if disto(self, tool) < pickup_dist then
          self.tool = tool
          del(tools, tool)
          sfx(sfx_list.pick_up, sfx_channels.tool)
          break
        end
      end
    end
  end

  -- use our tool
  if btnp(btns.x, self.p) then
    if self.tool ~= nil then
      for i, node in pairs(nodes) do
        if disto(self, node) < collect_dist then
          sfx(sfx_list.ore_smack, sfx_channels.tool)
          gold += node:hit(1)

          if node:is_dead() then
            node:explode()
            del(nodes, node)
          end
        end
      end
    end
  end
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

  spr(tool_sprites[self.name], self.x, self.y)

  self:reset_palette()
end

function Tool:draw_held(x, y, face_left)
  local offset = 4
  if face_left then
    offset = -offset
  end

  self:set_palette()

  spr(tool_sprites[self.name], x + offset, y - 4, 1, 1, face_left)

  self:reset_palette()
end

function Tool:drop(owner)
  self.x = owner.x
  self.y = owner.y
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

function Node:init(name, x, y, hp, value)
  self.name = name
  self.x = x
  self.y = y
  self.hp = hp or 5
  self.value = value or 1

  mset(x / 8, y / 8, map_tiles.node)
end

function Node:draw()
  spr(node_sprites[self.name], self.x, self.y)
end

function Node:hit(amt)
  amt = amt or 1
  self.hp -= amt

  if self.hp <= 0 then
    return self.value
  end

  return 0
end

function Node:is_dead()
  return self.hp <= 0
end

function Node:explode()
  mset(self.x / 8, self.y / 8, map_tiles.plain)
end

-- map

Map = Object:extend()

function Map:draw_for(char)
  -- draw the map from a character's perspective.
  -- this is done to save on render time - no need to draw the full 128x64 map
  -- for each character's frame when we can just draw a single 10x10 and cover
  -- their entire screen
  local mx = flr(char.x / 8) - 4
  local my = flr(char.y / 8) - 4
  map(mx, my, mx * 8, my * 8, 11, 11)
end

-- game state

world = Map()

nodes = {}

chars = {
}

tools = {}

gold = 0
frame = 0

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
        local node = Node("ore", x * 8, y * 8)
        add(nodes, node)

      -- random tooll spawn
      elseif rnd(2048) < 1 then

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


add(tools, Bucket(center_x, center_y))

add(chars, Char(0, center_x - 8, center_y - 8))
add(chars, Char(1, center_x + 8, center_y - 8))
add(chars, Char(2, center_x - 8, center_y + 8))
add(chars, Char(3, center_x + 8, center_y + 8))

-- game code

function _init()
  cls()
end

function _update60()
  frame += 0

  for i, char in pairs(chars) do
    char:update()
  end
end

function _draw()
  for _, cam in pairs(chars) do
    cam:set_clip()

    world:draw_for(cam)
    for i, char in pairs(chars) do
      char:draw()
    end

    for i, tool in pairs(tools) do
      tool:draw()
    end

    for i, node in pairs(nodes) do
      node:draw()
    end

    cam:reset_clip()
  end

  -- draw split screen separators
  line(0, 63, 128, 63, split_sep_color)
  line(0, 64, 128, 64, split_sep_color)
  line(63, 0, 63, 128, split_sep_color)
  line(64, 0, 64, 128, split_sep_color)
  spr(ui_corner_sprite, 56, 56)
  spr(ui_corner_sprite, 56, 64, 1, 1, false, true)
  spr(ui_corner_sprite, 64, 56, 1, 1, true)
  spr(ui_corner_sprite, 64, 64, 1, 1, true, true)

  color(colors.orange)
  print(""..gold, 62, 61)
end
