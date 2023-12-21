filling algorithm for insideness check


..#...####
.##...#..#
.#....#..#
.#....#..#
.##.###..#
..#####..#
......####


1a. expensive calculation to find 1 point either inside or outside

##########
#I.......#
##.......#
.#.......#
.##......#
..#####..#
......####

1b. flood fill to propogate result
##########
#IIIIIIII#
##IIIIIII#
.#IIIIIII#
.##IIIIII#
..#####II#
......####

2. select new point and repeat 1a, 1b
##########
#IIIIIIII#
##IIIIIII#
O#IIIIIII#
.##IIIIII#
..#####II#
......####

##########
#IIIIIIII#
##IIIIIII#
O#IIIIIII#
O##IIIIII#
OO#####II#
OOOOOO####


3. count up result


# Alternative
find 
##########
#........#
#######..#
....C.#..#
......#..#
......#..#
......####



