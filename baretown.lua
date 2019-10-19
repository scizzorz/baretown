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


function dist(x1, y1, x2, y2)
  local dx = x1 - x2
  local dy = y1 - y2
  return sqrt(dx * dx + dy * dy)
end

function disto(o1, o2)
  return dist(o1.x, o1.y, o2.x, o2.y)
end

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
  local my = flr(self.y / 8 - 4) -1
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

function Char:update()
  -- move up/down
  if btn(btns.up, self.p) then self.y -= self.speed end
  if btn(btns.down, self.p) then self.y += self.speed end

  -- move left/right, adjusting face_left as necessary
  if btn(btns.left, self.p) then
    self.x -= self.speed
    self.face_left = true
  end

  if btn(btns.right, self.p) then
    self.x += self.speed
    self.face_left = false
  end

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

chars = {
  Char(0, 512 - 8, 256 - 8),
  Char(1, 512 + 8, 256 - 8),
  Char(2, 512 - 8, 256 + 8),
  Char(3, 512 + 8, 256 + 8),
}

tools = {
  Tool("bucket", 512, 256),
}

split_sep_color = colors.dark_blue

function _init()
  cls()
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
end

function _update60()
  for i, c in pairs(chars) do
    c:update()
  end
end
