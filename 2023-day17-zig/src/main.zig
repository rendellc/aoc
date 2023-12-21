const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const dprint = std.debug.print;

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

const Color = struct {
    hex: []const u8,
};
const Direction = enum {
    R,
    L,
    U,
    D,

    pub fn fromChar(char: u8) !Direction {
        return switch (char) {
            'R' => Direction.R,
            'L' => Direction.L,
            'U' => Direction.U,
            'D' => Direction.D,
            else => ProgramError.AnyError,
        };
    }
};

const DigData = struct {
    direction: Direction,
    distance: u64,
    color: Color,

    pub fn parse(line: []const u8) !DigData {
        // Parse: "R 6 (#70c710)"
        // Parse: "L 10 (#70c710)"
        const direction = try Direction.fromChar(line[0]);

        var iter = std.mem.splitScalar(u8, line, ' ');
        _ = iter.next(); // skip direction
        const distance = try std.fmt.parseInt(u64, iter.next().?, 10);
        const color_str = iter.next().?;

        const hex_color = color_str[1..std.mem.indexOfScalar(u8, color_str, ')').?];

        return .{
            .direction = direction,
            .distance = distance,
            .color = Color{
                .hex = hex_color,
            },
        };
    }
};

fn parseDigInstructions(allocator: Allocator, input: []const u8) ![]DigData {
    var instructions = std.ArrayList(DigData).init(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const instruction = try DigData.parse(line);
        try instructions.append(instruction);
    }

    return instructions.toOwnedSlice();
}

const Bounds = struct {
    min_x: i64,
    min_y: i64,
    max_x: i64,
    max_y: i64,
};

fn findBounds(instructions: []const DigData) Bounds {
    var x: i64 = 0;
    var y: i64 = 0;
    var min_x: i64 = 0;
    var min_y: i64 = 0;
    var max_x: i64 = 0;
    var max_y: i64 = 0;
    for (instructions) |instruction| {
        const d = instruction.distance;
        switch (instruction.direction) {
            Direction.R => {
                x += @intCast(d);
            },
            Direction.L => {
                x -= @intCast(d);
            },
            Direction.U => {
                y -= @intCast(d);
            },
            Direction.D => {
                y += @intCast(d);
            },
        }

        if (x < min_x) {
            min_x = x;
        }
        if (x > max_x) {
            max_x = x;
        }
        if (y < min_y) {
            min_y = y;
        }
        if (y > max_y) {
            max_y = y;
        }
    }

    return .{
        .min_x = min_x,
        .min_y = min_y,
        .max_x = max_x,
        .max_y = max_y,
    };
}

const Vec2 = struct {
    x: i64,
    y: i64,
};

const Path = struct {
    instructions: []const DigData,

    const PathPositionIterator = struct {
        pos: ?Vec2,
        path: Path,
        index: u64,
        current_instruction_step: u64,

        pub fn next(self: *PathPositionIterator) ?Vec2 {
            if (self.pos == null) {
                self.pos = Vec2{ .x = 0, .y = 0 };
                return self.pos;
            }

            if (self.index >= self.path.instructions.len) {
                return null;
            }

            const i = self.path.instructions[self.index];
            const steps = i.distance;

            switch (i.direction) {
                Direction.R => {
                    self.pos.?.x += 1;
                },
                Direction.L => {
                    self.pos.?.x -= 1;
                },
                Direction.D => {
                    self.pos.?.y += 1;
                },
                Direction.U => {
                    self.pos.?.y -= 1;
                },
            }

            self.current_instruction_step += 1;
            const steps_remaining = steps - self.current_instruction_step;
            if (steps_remaining == 0) {
                self.current_instruction_step = 0;
                self.index += 1;
            }

            return self.pos;
        }
    };

    pub fn positionIterator(self: Path) PathPositionIterator {
        return .{
            .pos = null,
            .path = self,
            .index = 0,
            .current_instruction_step = 0,
        };
    }

    // pub fn create(self: Path, allocator: Allocator) !Path {
    //     var positions = std.ArrayList(Vec2).init(allocator);
    //     var x: i64 = 0;
    //     var y: i64 = 0;
    //     try positions.append(.{ .x = x, .y = y });
    //     for (self.instructions) |instruction| {
    //         const d = instruction.distance;
    //         switch (instruction.direction) {
    //             Direction.R => {
    //                 x += @intCast(d);
    //             },
    //             Direction.L => {
    //                 x -= @intCast(d);
    //             },
    //             Direction.U => {
    //                 y -= @intCast(d);
    //             },
    //             Direction.D => {
    //                 y += @intCast(d);
    //             },
    //         }
    //         try positions.append(.{ .x = x, .y = y });
    //     }
    //     return positions.toOwnedSlice();
    // }
};

fn findPositionsInsidePath(allocator: Allocator, path: []const Vec2, bounds: Bounds) ![]Vec2 {
    var all_path_positions = std.AutoHashMap(Vec2, void).init(allocator);
    defer all_path_positions.deinit();

    var prev: Vec2 = Vec2{ .x = 0, .y = 0 };
    for (path) |p| {
        var x: i64 = prev.x;
        const x_step: i64 = if (p.x > prev.x) 1 else -1;
        while (x != p.x) {
            try all_path_positions.put(Vec2{ .x = x, .y = p.y }, {});
            x += x_step;
        }
        try all_path_positions.put(Vec2{ .x = x, .y = p.y }, {});
        var y: i64 = prev.y;
        const y_step: i64 = if (p.y > prev.y) 1 else -1;
        while (y != p.y) {
            try all_path_positions.put(Vec2{ .x = p.x, .y = y }, {});
            y += y_step;
        }
        try all_path_positions.put(Vec2{ .x = p.x, .y = y }, {});

        prev = p;
    }

    const positions_to_check: usize = @intCast((bounds.max_x - bounds.min_x + 2) * (bounds.max_y - bounds.min_y + 1));
    var str = try allocator.alloc(u8, positions_to_check);
    defer allocator.free(str);
    @memset(str, '.');
    var y: i64 = bounds.min_y;
    while (y <= bounds.max_y) : (y += 1) {
        var x: i64 = bounds.min_x;
        while (x <= bounds.max_x) : (x += 1) {
            const p_curr = Vec2{ .x = x, .y = y };
            const is_on_path = all_path_positions.contains(p_curr);

            const index: usize = @intCast((bounds.max_x - bounds.min_x + 2) * y + x);
            if (is_on_path) {
                str[index] = '#';
            }
        }

        //const index: usize = @intCast((@as(i64, @intCast(x)) - bounds.min_x) * (@as(i64, @intCast(y)) - bounds.min_y));
        //const index: usize = @as(usize, @intCast(bounds.max_x - bounds.min_x + 2)) * y + x;
        const index: usize = @intCast((bounds.max_x - bounds.min_x + 2) * (y - bounds.min_y) + x);
        if (y <= bounds.max_y) {
            str[index] = '\n';
        }
    }
    dprint("{s}\n", .{str});

    // const ScanState = enum { enter, exit, inside, outside };

    var inside_positions = std.ArrayList(Vec2).init(allocator);
    // var y = bounds.min_y;
    // while (y <= bounds.max_y) : (y += 1) {
    //     var scan_state = ScanState.outside;
    //     var x = bounds.min_x;
    //     while (x <= bounds.max_x) : (x += 1) {
    //         const p_curr = Vec2{ .x = x, .y = y };
    //         const p_next = Vec2{ .x = x+1, .y = y };
    //         const is_on_path = all_path_positions.contains(p_curr);
    //         const is_next_on_path = all_path_positions.contains(p_next);
    //         _ = is_next_on_path;
    //         if (!is_on_path) {
    //             if (scan_state == ScanState.enter) {
    //                 scan_state = ScanState.inside;
    //             }
    //             if (scan_state == ScanState.exit) {
    //                 scan_state = ScanState.outside;
    //             }
    //         }
    //         if (is_on_path) {
    //             if (scan_state == ScanState.enter or scan_state == ScanState.inside) {
    //                 scan_state = ScanState.exit;
    //             } else if (scan_state == ScanState.exit or scan_state == ScanState.outside) {
    //                 scan_state = ScanState.enter;
    //             }
    //         }

    //         dprint("Checking ({d}, {d}) ... ", .{ x, y });
    //         if (scan_state != ScanState.outside) {
    //             dprint("inside\n", .{});
    //             try inside_positions.append(p_curr);
    //         } else {
    //             dprint("\n", .{});
    //         }
    //     }
    // }

    return inside_positions.toOwnedSlice();
}

fn ssa(angle: f64) f64 {
    return std.math.atan2(f64, std.math.sin(angle), std.math.cos(angle));
}

fn onOrInsidePath(pos: Vec2, path: Path) bool {
    var positions = path.positionIterator();

    var angle_sum: f64 = 0;
    var previous_angle: ?f64 = null;
    while (positions.next()) |p| {
        const dx = p.x - pos.x;
        const dy = p.y - pos.y;
        if (dx == 0 and dy == 0) {
            return true;
        }

        const angle = std.math.atan2(f64, @floatFromInt(dy), @floatFromInt(dx));
        if (previous_angle == null) {
            previous_angle = angle;
        }
        const angle_step = ssa(angle - previous_angle.?);
        previous_angle = angle;
        angle_sum += angle_step;
    }

    const winding_number_approx = angle_sum / (2 * std.math.pi);
    const winding_number_rounded: i64 = @intFromFloat(@round(winding_number_approx));
    // dprint("Position {any}: winding number: {d}\n", .{ pos, winding_number_rounded });
    if (winding_number_rounded == 0) {
        return false;
    }

    return true;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const instructions = try parseDigInstructions(aa, input);
    try stdout.print("Found {d} instructions\n", .{instructions.len});
    const bounds = findBounds(instructions);
    try stdout.print("Bounds are {any}\n", .{bounds});
    // const path = try Path.create(aa, instructions);
    const path = Path{
        .instructions = instructions,
    };
    // try stdout.print("Path length {d}\n", .{path.len});

    const positions_to_check = (bounds.max_x - bounds.min_x) * (bounds.max_y - bounds.min_y);
    try stdout.print("Positions to check: {d}\n", .{positions_to_check});

    const count_x: usize = @intCast(bounds.max_x - bounds.min_x + 1);
    const count_y: usize = @intCast(bounds.max_y - bounds.min_y + 1);

    var inside_count: u64 = 0;
    for (0..count_y) |i| {
        const y: i64 = bounds.min_y + @as(i64, @intCast(i));
        for (0..count_x) |j| {
            const x: i64 = bounds.min_x + @as(i64, @intCast(j));

            if (onOrInsidePath(Vec2{ .x = x, .y = y }, path)) {
                inside_count += 1;
            }
        }
    }

    return @intCast(inside_count);
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    _ = input;
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    return 0;
}

test "simple 1" {
    const data =
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 62), try process1(allocator, data));
}
