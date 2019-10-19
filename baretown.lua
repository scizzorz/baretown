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

music_songs = {
  main = 0,
}

sfx_list = {
  pick_up = 63,
  drop = 62,
}

sfx_channels = {
  tool = 1,
}

split_sep_color = colors.dark_blue
ui_corner_sprite = 110
ui_middle_sprite = 111
impassable_flag = 0

-- utilities

function dist(x1, y1, x2, y2)
  local dx = x1 - x2
  local dy = y1 - y2
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
  music(0)
end

function Char:set_clip()
  clip(self.scrx, self.scry, self.scrx + 64, self.scry + 64)
  camera(self.x - self.scrx - 32, self.y - self.scry - 32)
end

function Char:reset_clip()
  clip()
  camera()
end

function Char:draw_map()
  local mx = flr(self.x / 8 - 4) - 1
  local my = flr(self.y / 8 - 4) - 1
  local ox = self.x % 8
  local oy = self.y % 8
  map(mx, my, self.x - 40 - ox, self.y - 40 - oy, 10, 10)
end

function Char:draw_char()
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
  if dy < 0 and (collision_tl or collision_tr) then
    self.y = flr(self.y / 8) * 8 + 8
  end

  if dy > 0 and (collision_bl or collision_br) then
    self.y = flr(self.y / 8) * 8
  end

  if dx < 0 and (collision_tl or collision_bl) then
    self.x = flr(self.x / 8) * 8 + 8
  end

  if dx > 0 and (collision_tr or collision_br) then
    self.x = flr(self.x / 8) * 8
  end

  -- map bounds
  if self.x < 0 then self.x = 0 end
  if self.y < 0 then self.y = 0 end
  if self.x > 1016 then self.x = 1016 end
  if self.y > 504 then self.y = 504 end
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
        if disto(self, tool) < 8 then
          self.tool = tool
          del(tools, tool)
          sfx(sfx_list.pick_up, sfx_channels.tool)
          break
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

function Tool:draw()
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

  spr(tool_sprites[self.name], self.x, self.y)

  pal()
end

function Tool:draw_held(x, y, face_left)
  local offset = 4
  if face_left then
    offset = -offset
  end
  spr(tool_sprites[self.name], x + offset, y - 4, 1, 1, face_left)
end

function Tool:drop(owner)
  self.x = owner.x
  self.y = owner.y
end

-- game state

chars = {
  Char(0, 512 - 8, 256 - 8),
  Char(1, 512 + 8, 256 - 8),
  Char(2, 512 - 8, 256 + 8),
  Char(3, 512 + 8, 256 + 8),
}

tools = {
  Tool("bucket", 512, 256),
}

gold = 0
frame = 0

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

    cam:draw_map()
    for i, char in pairs(chars) do
      char:draw_char()
    end
    for i, tool in pairs(tools) do
      tool:draw()
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
