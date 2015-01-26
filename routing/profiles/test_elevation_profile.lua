require("elevation")

local mway = {}
mway.forward_speed = 1
mway.backward_speed = 1
if table.getn(arg) > 1 then
  mway.id = 318961491
else
  mway.id = arg[1]
end
Elevation.compute_speed(mway);
print('Speeds: ' ..mway.forward_speed .. '  ' .. mway.backward_speed)
