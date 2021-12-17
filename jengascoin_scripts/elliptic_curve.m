pkg load symbolic

field_size = 191;
curve_length = 128;

# "fixed" base point
% x1 = field_size * pi/10;
% y1 = field_size * e/10;

x1 = mod(123,field_size);
y1 = mod(53,field_size);

# "random" seed
% x2 = field_size * rand();
x2 = sym(randi([0,2^32]))
y2_sign = randi([0,1]) # "random" y seed signbit
%y2 = mod(sqrt(x^3 + 4*x + 20), field_size);
y2 = round(mod(sqrt(x^3 + 4*x + 20), field_size));
if ~y2_sign
  y2 = -y2;
end

points = zeros(curve_length,2); # x,y pairs
points(1,:) = [x1, y1];
points(2,:) = [x2, y2];

for i = 3:curve_length % first two values are pre-computed
  y_inter = (points(2,2)-points(1,2))/(points(2,1)-points(1,1)) * points(2,1) + points(2,2)
  % "x"
  %points(i, 
  % "y"
  points(i,2) = mod(sqrt((points(i,1))^3 + 4*(points(i,1)) + 20), field_size);
end
