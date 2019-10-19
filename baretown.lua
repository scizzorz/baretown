c_black = 0
c_dark_blue = 1
c_dark_purple = 2
c_dark_green = 3
c_brown = 4
c_dark_grey = 5
c_light_grey = 6
c_white = 7
c_red = 8
c_orange = 9
c_yellow = 10
c_green = 11
c_blue = 12
c_indigo = 13
c_pink = 14
c_peach = 15

b_left = 0
b_right = 1
b_up = 2
b_down = 3
b_o = 4
b_x = 5

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

char_colors = {
  c_red,
  c_blue,
  c_green,
  c_yellow,
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
  pal(8, self.color)
  spr(self.spr, self.x, self.y, 1, 1, self.face_left)
  pal()

  -- draw our tool if it exists
  if self.tool ~= nil then
    self.tool:draw_held(self.x, self.y, self.face_left)
  end
end

function Char:update()
  -- move up/down
  if btn(b_up, self.p) then self.y -= self.speed end
  if btn(b_down, self.p) then self.y += self.speed end

  -- move left/right, adjusting face_left as necessary
  if btn(b_left, self.p) then
    self.x -= self.speed
    self.face_left = true
  end

  if btn(b_right, self.p) then
    self.x += self.speed
    self.face_left = false
  end

  -- pick up or drop tools
  if btnp(b_o, self.p) then
    -- drop held tool
    if self.tool ~= nil then
      add(tools, self.tool)
      self.tool:drop(self)
      self.tool = nil

    -- pick up a new tool
    else
      for i, tool in pairs(tools) do
        -- pick up tools if distance < 8 pixels
        if disto(self, tool) < 8 then
          self.tool = tool
          del(tools, tool)
          break
        end
      end
    end
  end
end

Tool = Object:extend()

function Tool:init(name, x, y, power)
  self.name = name
  self.x = x
  self.y = y
  self.power = power or 0
end

function Tool:draw()
  spr(tool_sprites[self.name], self.x, self.y)
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
  Char(0, 256 - 8, 256 - 8),
  Char(1, 256 + 8, 256 - 8),
  Char(2, 256 - 8, 256 + 8),
  Char(3, 256 + 8, 256 + 8),
}

tools = {
  Tool("pick", 256, 256),
}

split_sep_color = c_dark_blue

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
