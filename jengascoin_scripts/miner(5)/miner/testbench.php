<?php
$x_0 = '100'; //initial x supply
$y_0 = '10'; //initial y supply
$f = '0.3'; //fee proportion
$x_in = '20'; // amount of x offered to swap
echo "user gives $x_in";

$k_0 = bcmul($x_0, $y_0, 16); //initial k value

$x_1 = bcadd($x_0, $x_in, 16);

$y_1 = bcdiv($k_0, $x_1, 16);

$y_swap = bcsub($y_0, $y_1, 16);

$y_fee = bcmul($y_swap, $f, 16);

$y_out = bcsub($y_swap, $y_fee, 16); //actual number of returned y tokens

$k_1 = bcmul($x_1, $y_1, 16); //new k value

echo "\nuser gets $y_out \nfee $y_fee\nold k $k_0\nnew k $k_1 <br>";