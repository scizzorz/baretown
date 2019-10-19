c_black = 0
c_darkblue = 1
c_magenta = 2
c_darkgreen = 3
c_brown = 4
c_darkgrey = 5
c_grey = 6
c_white = 7
c_red = 8
c_orange = 9
c_yellow = 10
c_green = 11
c_blue = 12
c_indigo = 13
c_pink = 14
c_beige = 15

b_left = 0
b_right = 1
b_up = 2
b_down = 3
b_o = 4
b_x = 5

_object = {}
_object.__index = _object


-- constructor
function _object:__call(...)
  local this = setmetatable({}, self)
  return this, this:init(...)
end


-- methods
function _object:init() end
function _object:update() end
function _object:draw() end


-- subclassing
function _object:extend()
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

char = _object:extend()

function char:init(p, x, y)
  self.p = p
  self.scry = flr(p / 2) * 64
  self.scrx = (p % 2) * 64
  self.x = x
  self.y = y
  self.speed = 0.5
end

function char:set_clip()
  clip(self.scrx, self.scry, self.scrx + 64, self.scry + 64)
  camera(self.x - self.scrx, self.y - self.scry)
end

function char:reset_clip()
  clip()
  camera()
end

function char:draw_map()
  local mx = flr(self.x / 8 - 4) - 1
  local my = flr(self.y / 8 - 4) -1
  local ox = self.x % 8
  local oy = self.y % 8
  map(mx, my, self.x - 8 - ox, self.y - 8 - oy, 10, 10)
end

function char:draw_char()
  spr(self.p + 1, self.x + 28, self.y + 28)
end

function char:update()
  if btn(b_up, self.p) then self.y -= self.speed end
  if btn(b_down, self.p) then self.y += self.speed end
  if btn(b_left, self.p) then self.x -= self.speed end
  if btn(b_right, self.p) then self.x += self.speed end
end

chars = {
  char(0, 256 - 8, 256 - 8),
  char(1, 256 + 8, 256 - 8),
  char(2, 256 - 8, 256 + 8),
  char(3, 256 + 8, 256 + 8),
}

split_sep_color = c_darkblue

function _init()
  cls()
end

function _draw()
  for _, cam in pairs(chars) do
    cam:set_clip()
    cam:draw_map()
    for i, c in pairs(chars) do
      c:draw_char()
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
