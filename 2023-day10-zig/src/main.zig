const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const print = std.debug.print;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const input = try file.readToEndAlloc(allocator, 60 * 1024 * 1024);
    defer allocator.free(input);

    const output1 = try process1(allocator, input);
    try stdout.print("Result 1: {d}\n", .{output1});

    const output2 = try process2(allocator, input);
    try stdout.print("Result 2: {d}\n", .{output2});

    try bw.flush();
}

const ProgramError = error{
    AnyError,
};

const Vec2 = struct {
    x: i64,
    y: i64,

    pub fn add(self: Vec2, dx: i64, dy: i64) Vec2 {
        return .{
            .x = self.x + dx,
            .y = self.y + dy,
        };
    }
};

const PipePart = enum {
    vertical,
    horizontal,
    bendNE,
    bendNW,
    bendSW,
    bendSE,
    ground,
    start,

    pub fn toChar(self: PipePart) u8 {
        return switch (self) {
            PipePart.vertical => '|',
            PipePart.horizontal => '-',
            PipePart.bendNE => 'L',
            PipePart.bendNW => 'J',
            PipePart.bendSW => '7',
            PipePart.bendSE => 'F',
            PipePart.ground => '.',
            PipePart.start => 'S',
        };
    }

    pub fn fromChar(char: u8) !PipePart {
        return switch (char) {
            '|' => PipePart.vertical,
            '-' => PipePart.horizontal,
            'L' => PipePart.bendNE,
            'J' => PipePart.bendNW,
            '7' => PipePart.bendSW,
            'F' => PipePart.bendSE,
            '.' => PipePart.ground,
            'S' => PipePart.start,
            else => ProgramError.AnyError,
        };
    }

    pub fn allowsEastExit(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.horizontal => true,
            PipePart.bendNE => true,
            PipePart.bendSE => true,
            else => false,
        };
    }

    pub fn allowsWestExit(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.horizontal => true,
            PipePart.bendNW => true,
            PipePart.bendSW => true,
            else => false,
        };
    }

    pub fn allowsNorthExit(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.vertical => true,
            PipePart.bendNW => true,
            PipePart.bendNE => true,
            else => false,
        };
    }

    pub fn allowsSouthExit(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.vertical => true,
            PipePart.bendSW => true,
            PipePart.bendSE => true,
            else => false,
        };
    }

    pub fn allowsWestEntry(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.horizontal => true,
            PipePart.bendNW => true,
            PipePart.bendSW => true,
            else => false,
        };
    }

    pub fn allowsEastEntry(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.horizontal => true,
            PipePart.bendNE => true,
            PipePart.bendSE => true,
            else => false,
        };
    }

    pub fn allowsNorthEntry(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.vertical => true,
            PipePart.bendNE => true,
            PipePart.bendNW => true,
            else => false,
        };
    }

    pub fn allowsSouthEntry(pipe: PipePart) bool {
        return switch (pipe) {
            PipePart.start => true,
            PipePart.vertical => true,
            PipePart.bendSE => true,
            PipePart.bendSW => true,
            else => false,
        };
    }
};

const Grid = struct {
    data: []const u8,
    height: i64,
    width: i64,

    pub fn find(self: Grid, char: u8) ?Vec2 {
        const index = std.mem.indexOfScalar(u8, self.data, char);
        if (index == null) {
            return null;
        }

        return .{
            .x = @rem(@as(i64, @intCast(index.?)), self.width + 1),
            .y = @divFloor(@as(i64, @intCast(index.?)), self.width + 1),
        };
    }

    pub fn get(self: Grid, xy: Vec2) PipePart {
        std.debug.assert(xy.x < self.width);
        std.debug.assert(xy.y < self.height);
        const index = xy.x + (self.width + 1) * xy.y;
        const char = self.data[@intCast(index)];

        return PipePart.fromChar(char) catch {
            print("Failed to get ({d},{d}) at index {d} ({c}) \n", .{ xy.x, xy.y, index, char });
            unreachable;
        };
    }

    pub fn canTravel(self: Grid, from: Vec2, to: Vec2) bool {
        if (to.x < 0 or to.x >= self.width) {
            return false;
        }
        if (to.y < 0 or to.y >= self.height) {
            return false;
        }
        const step = Vec2{
            .x = to.x - from.x,
            .y = to.y - from.y,
        };
        const step_length = @abs(step.x) + @abs(step.y);
        // Only allow direction.x or direction.y, not both or zero
        if (step_length == 0 or step_length > 1) {
            return false;
        }

        const move_east = step.x > 0;
        const move_west = step.x < 0;
        const move_north = step.y < 0;
        const move_south = step.y > 0;

        var from_allows = false;
        const from_char = self.get(from).toChar();
        if (move_east) {
            from_allows = from_char == '-' or from_char == 'F' or from_char == 'L' or from_char == 'S';
        } else if (move_west) {
            from_allows = from_char == '-' or from_char == 'J' or from_char == '7' or from_char == 'S';
        } else if (move_north) {
            from_allows = from_char == '|' or from_char == 'J' or from_char == 'L' or from_char == 'S';
        } else if (move_south) {
            from_allows = from_char == '|' or from_char == 'F' or from_char == '7' or from_char == 'S';
        }

        var to_allows = false;

        const to_char = self.get(to).toChar();
        if (move_east) {
            to_allows = to_char == '-' or to_char == 'J' or to_char == '7' or to_char == 'S';
        } else if (move_west) {
            to_allows = to_char == '-' or to_char == 'L' or to_char == 'F' or to_char == 'S';
        } else if (move_north) {
            to_allows = to_char == '|' or to_char == 'F' or to_char == '7' or to_char == 'S';
        } else if (move_south) {
            to_allows = to_char == '|' or to_char == 'L' or to_char == 'J' or to_char == 'S';
        }

        return from_allows and to_allows;
    }

    pub fn init(input: []const u8) Grid {
        // print("Initializing grid\n{s}\n", .{input});
        var lines = std.mem.splitScalar(u8, input, '\n');
        const width = lines.peek().?.len;

        var height: i64 = 0;
        while (lines.next()) |line| {
            if (line.len == 0) continue;

            height += 1;
        }

        return .{
            .data = input,
            .height = height,
            .width = @intCast(width),
        };
    }
};

const PipeWalker = struct {
    grid: *const Grid,
    start: Vec2,
    current: Vec2,
    next: Vec2,
    is_finished: bool,

    pub fn init(grid: *const Grid) PipeWalker {
        const start = grid.*.find('S').?;
        // print("Start: {d} {d}\n", .{ start.x, start.y });

        var next: ?Vec2 = null;

        if (grid.*.canTravel(start, start.add(-1, 0))) {
            next = start.add(-1, 0);
        } else if (grid.*.canTravel(start, start.add(1, 0))) {
            next = start.add(1, 0);
        } else if (grid.*.canTravel(start, start.add(0, -1))) {
            next = start.add(0, -1);
        } else if (grid.*.canTravel(start, start.add(0, 1))) {
            next = start.add(0, 1);
        } else {
            unreachable;
        }

        return .{
            .grid = grid,
            .start = start,
            .current = start,
            .next = next.?,
            .is_finished = false,
        };
    }

    pub fn step(self: *PipeWalker) void {
        const move_step = Vec2{
            .x = self.next.x - self.current.x,
            .y = self.next.y - self.current.y,
        };
        self.current = self.next;

        var possible_steps: [3]Vec2 = undefined;

        possible_steps[0] = move_step; // keep going in the same direction
        possible_steps[1] = Vec2{
            .x = -move_step.y,
            .y = move_step.x,
        };
        possible_steps[2] = Vec2{
            .x = move_step.y,
            .y = -move_step.x,
        };

        var next: ?Vec2 = null;
        for (possible_steps) |s| {
            if (self.grid.*.canTravel(self.current, self.current.add(s.x, s.y))) {
                next = self.current.add(s.x, s.y);
            }
        }

        std.debug.assert(next != null);
        self.next = next.?;

        if (self.grid.get(self.current) == PipePart.start) {
            self.is_finished = true;
        }
    }
};

fn ssa(angle: f64) f64 {
    return std.math.atan2(f64, std.math.sin(angle), std.math.cos(angle));
}

fn computeWindingNumber(pos: Vec2, path: []const Vec2) i64 {
    // print("Compute winding number: ({d},{d})\n", .{ pos.x, pos.y });
    std.debug.assert(path.len > 0);

    var dx = path[0].x - pos.x;
    var dy = path[0].y - pos.y;
    var previous_angle = std.math.atan2(f64, @floatFromInt(dy), @floatFromInt(dx));
    // print("\tStarting angle: {d}, ({d},{d})\n", .{ previous_angle, pos.x, pos.y });

    var angle_steps_sum: f64 = 0;

    for (path, 0..) |path_pos, i| {
        if (i >= path.len - 1) {
            continue;
        }
        dx = path_pos.x - pos.x;
        dy = path_pos.y - pos.y;
        if (dx == 0 and dy == 0) {
            // path crosses pos, so its winding number is 0
            // print("\twinding number: {d} (path)\n", .{0});
            return 0;
        }

        const angle = std.math.atan2(f64, @floatFromInt(dy), @floatFromInt(dx));
        const angle_step = ssa(angle - previous_angle);
        // print("\tangle: {d}, {d} ({d},{d})\n", .{ angle, angle_step, dx, dy });
        previous_angle = angle;

        angle_steps_sum += angle_step;
    }

    // read first path
    dx = path[0].x - pos.x;
    dy = path[0].y - pos.y;
    const angle = std.math.atan2(f64, @floatFromInt(dy), @floatFromInt(dx));
    const angle_step = ssa(angle - previous_angle);
    angle_steps_sum += angle_step;

    const winding_number_approx = angle_steps_sum / (2 * std.math.pi);
    //print("\twinding number: {d}\n", .{winding_number_approx});
    return @intFromFloat(@round(winding_number_approx));
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    const grid = Grid.init(input);
    var walker = PipeWalker.init(&grid);

    var walker_steps: i64 = 0;
    while (!walker.is_finished) {
        // print("Walker: ({d},{d})\n", .{ walker.current.x, walker.current.y });
        walker.step();
        walker_steps += 1;
    }

    return @divExact(walker_steps, 2);
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const grid = Grid.init(input);
    var walker = PipeWalker.init(&grid);

    var pipe_path = std.ArrayList(Vec2).init(aa);
    try pipe_path.append(walker.current);

    while (!walker.is_finished) {
        walker.step();
        try pipe_path.append(walker.current);
    }

    // print("Created pipe path: {d}\n", .{pipe_path.items.len});
    // print("Grid size: {d} {d}\n", .{ grid.width, grid.height });
    // print("Steps: {d}\n", .{grid.width * grid.height * @as(i64, @intCast(pipe_path.items.len))});
    var loops: i64 = 0;
    for (0..@as(usize, @intCast(grid.width))) |x| {
        for (0..@as(usize, @intCast(grid.height))) |y| {
            const pos = Vec2{ .x = @intCast(x), .y = @intCast(y) };
            const winding_number = computeWindingNumber(pos, pipe_path.items);
            if (winding_number != 0) {
                loops += 1;
            }
        }
    }

    return loops;
}

test "process 1: simple 1" {
    const data =
        \\-L|F7
        \\7S-7|
        \\L|7||
        \\-L-J|
        \\L|-JF
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 4), try process1(allocator, data));
}

test "process1: simple 2" {
    const data =
        \\..F7.
        \\.FJ|.
        \\SJ.L7
        \\|F--J
        \\LJ...
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 8), try process1(allocator, data));
}

test "process2: simple 0" {
    const data =
        \\-L|F7
        \\7S-7|
        \\L|7||
        \\-L-J|
        \\L|-JF
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 1), try process2(allocator, data));
}

test "process2: simple 1" {
    const data =
        \\...........
        \\.S-------7.
        \\.|F-----7|.
        \\.||.....||.
        \\.||.....||.
        \\.|L-7.F-J|.
        \\.|..|.|..|.
        \\.L--J.L--J.
        \\...........
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 4), try process2(allocator, data));
}

test "process2: simple 2" {
    const data =
        \\..........
        \\.S------7.
        \\.|F----7|.
        \\.||....||.
        \\.||....||.
        \\.|L-7F-J|.
        \\.|..||..|.
        \\.L--JL--J.
        \\..........
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 4), try process2(allocator, data));
}

test "process2: simple 3" {
    const data =
        \\.F----7F7F7F7F-7....
        \\.|F--7||||||||FJ....
        \\.||.FJ||||||||L7....
        \\FJL7L7LJLJ||LJ.L-7..
        \\L--J.L7...LJS7F-7L7.
        \\....F-J..F7FJ|L7L7L7
        \\....L7.F7||L7|.L7L7|
        \\.....|FJLJ|FJ|F7|.LJ
        \\....FJL-7.||.||||...
        \\....L---J.LJ.LJLJ...
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 8), try process2(allocator, data));
}
