const std = @import("std");
const Allocator = std.mem.Allocator;

const Grid = @import("./Grid.zig").Grid;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const input = try file.readToEndAlloc(allocator, 60 * 1024 * 1024);
    defer allocator.free(input);

    const output1 = try process1(allocator, input);
    std.debug.print("Result 1: {d}\n", .{output1});

    const output2 = try process2(allocator, input);
    std.debug.print("Result 2: {d}\n", .{output2});
}

const ProgramError = error{
    AnyError,
};

const HeightGrid = Grid(i8);
const VisibilityMap = Grid(bool);

fn toInt(char: u8) !i8 {
    if ('0' <= char and char <= '9') {
        return @intCast(char - '0');
    }

    return ProgramError.AnyError;
}

pub fn parse(allocator: Allocator, input: []const u8) !HeightGrid {
    var lines = std.mem.splitScalar(u8, input, '\n');
    const length = lines.peek().?.len;

    var height_grid = try HeightGrid.init(allocator, length, 0);

    var y: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        for (line, 0..) |char, x| {
            const height = try toInt(char);
            try height_grid.set(x, y, height);
        }
        y += 1;
    }

    return height_grid;
}

pub fn print(self: HeightGrid) !void {
    for (0..self.length) |y| {
        for (0..self.length) |x| {
            const height = try self.get(x, y);
            std.debug.print("{d}", .{height});
        }
        std.debug.print("\n", .{});
    }
}

pub fn print_visibility(self: VisibilityMap) !void {
    for (0..self.length) |y| {
        for (0..self.length) |x| {
            const visible = try self.get(x, y);
            if (visible) {
                std.debug.print("1", .{});
            } else {
                std.debug.print("0", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

pub fn process1(allocator: Allocator, input: []const u8) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const height_map = try parse(aa, input);
    const length = height_map.length;

    std.debug.print("-------\n", .{});
    try print(height_map);

    var visibility_map = try VisibilityMap.init(aa, length, false);

    // Find visible trees from north
    for (0..length) |x| {
        var max_height: i8 = -1;
        for (0..length) |y| {
            const h = try height_map.get(x, y);
            if (h > max_height) {
                try visibility_map.set(x, y, true);
                max_height = h;
            }
        }
    }

    // Find visible trees from west
    for (0..length) |y| {
        var max_height: i8 = -1;
        for (0..length) |x| {
            const h = try height_map.get(x, y);
            if (h > max_height) {
                try visibility_map.set(x, y, true);
                max_height = h;
            }
        }
    }
    // // Find visible trees from east
    for (0..length) |y| {
        var max_height: i8 = -1;
        for (0..length) |xrev| {
            const x = length - 1 - xrev;
            const h = try height_map.get(x, y);
            if (h > max_height) {
                try visibility_map.set(x, y, true);
                max_height = h;
            }
        }
    }

    // // Find visible trees from south
    for (0..length) |x| {
        var max_height: i8 = -1;
        for (0..length) |yrev| {
            const y = length - 1 - yrev;
            const h = try height_map.get(x, y);
            if (h > max_height) {
                try visibility_map.set(x, y, true);
                max_height = h;
            }
        }
    }

    // Count number of visible cells
    var visible_counter: usize = 0;
    for (0..length) |x| {
        for (0..length) |y| {
            const visible = try visibility_map.get(x, y);
            if (visible) {
                visible_counter += 1;
            }
        }
    }

    std.debug.print("-------\n", .{});
    try print_visibility(visibility_map);

    return visible_counter;
}

pub fn calculate_scenic_score_for_direction(xc: usize, yc: usize, xstep: isize, ystep: isize, grid: HeightGrid) !usize {
    const hc = try grid.get(xc, yc);
    const _xc: isize = @intCast(xc);
    const _yc: isize = @intCast(yc);

    var score: usize = 0;
    const max_steps = grid.length;
    for (1..max_steps) |i| {
        const _i: isize = @intCast(i);
        const x: isize = _xc + _i * xstep;
        const y: isize = _yc + _i * ystep;
        if (x < 0 or x >= grid.length or y < 0 or y >= grid.length) {
            break;
        }

        const h = try grid.get(@intCast(x), @intCast(y));

        if (h < hc) {
            score += 1;
        } else {
            score += 1;
            break;
        }
    }

    return score;
}

pub fn process2(allocator: Allocator, input: []const u8) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const height_map = try parse(aa, input);
    const length = height_map.length;

    // Find visible trees from north
    var best_scenic_score: usize = 0;
    for (0..length) |x| {
        for (0..length) |y| {
            const score_north = try calculate_scenic_score_for_direction(x, y, 0, -1, height_map);
            const score_south = try calculate_scenic_score_for_direction(x, y, 0, 1, height_map);
            const score_east = try calculate_scenic_score_for_direction(x, y, 1, 0, height_map);
            const score_west = try calculate_scenic_score_for_direction(x, y, -1, 0, height_map);

            const scenic_score = score_north * score_south * score_east * score_west;
            if (scenic_score > best_scenic_score) {
                std.debug.print("Found new best scenic score: {d}\n", .{scenic_score});
                best_scenic_score = scenic_score;
            }
        }
    }

    return best_scenic_score;
}

test "simple 1" {
    const data =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 21), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 8), try process2(allocator, data));
}
