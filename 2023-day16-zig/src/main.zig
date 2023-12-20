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

const Mirror = enum {
    vertical, // |
    horizontal, // -
    up, // /
    down, // \

    pub fn toChar(self: Mirror) u8 {
        return switch (self) {
            Mirror.vertical => '|',
            Mirror.horizontal => '-',
            Mirror.up => '/',
            Mirror.down => '\\',
        };
    }

    pub fn fromChar(char: u8) ?Mirror {
        return switch (char) {
            '|' => Mirror.vertical,
            '-' => Mirror.horizontal,
            '/' => Mirror.up,
            '\\' => Mirror.down,
            else => null,
        };
    }
};

const Vec2 = struct {
    x: i64,
    y: i64,

    pub fn up() Vec2 {
        return .{
            .x = 0,
            .y = -1,
        };
    }
    pub fn down() Vec2 {
        return .{
            .x = 0,
            .y = 1,
        };
    }
    pub fn left() Vec2 {
        return .{
            .x = -1,
            .y = 0,
        };
    }
    pub fn right() Vec2 {
        return .{
            .x = 1,
            .y = 0,
        };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }
};

const Beam = struct {
    position: Vec2,
    direction: Vec2,

    pub fn isLeft(self: Beam) bool {
        return self.direction.x < 0;
    }
    pub fn isRight(self: Beam) bool {
        return self.direction.x > 0;
    }
    pub fn isUp(self: Beam) bool {
        return self.direction.y < 0;
    }
    pub fn isDown(self: Beam) bool {
        return self.direction.y > 0;
    }

    pub fn toChar(self: Beam) u8 {
        if (self.isLeft()) {
            return '<';
        }
        if (self.isRight()) {
            return '>';
        }
        if (self.isDown()) {
            return 'V';
        }
        if (self.isUp()) {
            return '^';
        }

        unreachable;
    }
};

const Map = struct {
    mirrors: std.AutoHashMap(Vec2, Mirror),
    size: Vec2,

    pub fn getMirror(self: Map, position: Vec2) ?Mirror {
        return self.mirrors.get(position);
    }

    pub fn printWithBeams(self: Map, allocator: Allocator, beams: []const Beam) !void {
        const stdout = std.io.getStdOut().writer();
        _ = stdout;

        var str = try allocator.alloc(u8, @intCast((self.size.x + 1) * self.size.y));
        defer allocator.free(str);
        @memset(str[0..], '.');
        for (0..@as(usize, @intCast(self.size.y))) |y| {
            const end_of_line_index: usize = @as(usize, @intCast(self.size.x + 1)) * y + @as(usize, @intCast(self.size.x));
            str[end_of_line_index] = '\n';
        }

        var iter = self.mirrors.iterator();
        while (iter.next()) |entry| {
            const x: usize = @intCast(entry.key_ptr.*.x);
            const y: usize = @intCast(entry.key_ptr.*.y);
            const mirror = entry.value_ptr.*;

            const index: usize = (@as(usize, @intCast(self.size.x)) + 1) * y + x;
            str[index] = mirror.toChar();
        }

        for (beams) |beam| {
            const x = beam.position.x;
            const y = beam.position.y;
            if (x < 0 or x >= self.size.x or y < 0 or y >= self.size.y) {
                continue;
            }
            const index = (self.size.x + 1) * y + x;

            str[@intCast(index)] = beam.toChar();
        }

        // try stdout.print("{s}\n", .{str});
    }

    pub fn simulateBeams(self: Map, allocator: Allocator, starting_beam: Beam) ![]Beam {
        var beam_history = std.AutoHashMap(Beam, void).init(allocator);
        defer beam_history.deinit();
        var beams = std.ArrayList(Beam).init(allocator);
        defer beams.deinit();

        try beams.append(starting_beam);

        while (beams.popOrNull()) |beam| {
            if (beam_history.contains(beam)) {
                // beam is already simulated
                continue;
            }

            // dprint("Queue size {d}: Simulate beam {any}\n", .{ beams.items.len, beam });

            const outside_x = beam.position.x < 0 or beam.position.x >= self.size.x;
            const outside_y = beam.position.y < 0 or beam.position.y >= self.size.y;
            if (outside_x or outside_y) {
                // dprint("Beam {any} is outside domain\n", .{beam});
                continue;
            }

            try beam_history.put(beam, {});
            const mirror = self.getMirror(beam.position);
            const beam_is_horizontal = beam.isLeft() or beam.isRight();
            const beam_is_vertical = beam.isUp() or beam.isDown();
            if (mirror) |m| {
                switch (m) {
                    Mirror.horizontal => {
                        if (beam_is_horizontal) {
                            try beams.append(Beam{
                                .position = beam.position.add(beam.direction),
                                .direction = beam.direction,
                            });
                        }
                        if (beam_is_vertical) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.left()),
                                .direction = Vec2.left(),
                            });
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.right()),
                                .direction = Vec2.right(),
                            });
                        }
                    },
                    Mirror.vertical => {
                        if (beam_is_horizontal) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.up()),
                                .direction = Vec2.up(),
                            });
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.down()),
                                .direction = Vec2.down(),
                            });
                        }
                        if (beam_is_vertical) {
                            try beams.append(Beam{
                                .position = beam.position.add(beam.direction),
                                .direction = beam.direction,
                            });
                        }
                    },
                    Mirror.up => {
                        if (beam.isLeft()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.down()),
                                .direction = Vec2.down(),
                            });
                        }
                        if (beam.isRight()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.up()),
                                .direction = Vec2.up(),
                            });
                        }
                        if (beam.isUp()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.right()),
                                .direction = Vec2.right(),
                            });
                        }
                        if (beam.isDown()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.left()),
                                .direction = Vec2.left(),
                            });
                        }
                    },
                    Mirror.down => {
                        if (beam.isLeft()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.up()),
                                .direction = Vec2.up(),
                            });
                        }
                        if (beam.isRight()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.down()),
                                .direction = Vec2.down(),
                            });
                        }
                        if (beam.isUp()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.left()),
                                .direction = Vec2.left(),
                            });
                        }
                        if (beam.isDown()) {
                            try beams.append(Beam{
                                .position = beam.position.add(Vec2.right()),
                                .direction = Vec2.right(),
                            });
                        }
                    },
                }
            } else {
                try beams.append(Beam{
                    .position = beam.position.add(beam.direction),
                    .direction = beam.direction,
                });
            }

            // try self.printWithBeams(allocator, beams.items);
        }

        var beam_states = try allocator.alloc(Beam, beam_history.count());
        var iter = beam_history.keyIterator();
        var i: usize = 0;
        while (iter.next()) |b| {
            beam_states[i] = b.*;

            i += 1;
        }

        return beam_states;
    }

    pub fn parse(allocator: Allocator, input: []const u8) !Map {
        var mirrors = std.AutoHashMap(Vec2, Mirror).init(allocator);

        var lines = std.mem.splitScalar(u8, input, '\n');
        var y: i64 = 0;

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            for (line, 0..) |c, x| {
                const mirror = Mirror.fromChar(c);
                const position = Vec2{
                    .x = @intCast(x),
                    .y = y,
                };
                if (mirror != null) {
                    try mirrors.put(position, mirror.?);
                }
            }

            y += 1;
        }

        lines.reset();
        const size = Vec2{
            .x = @intCast(lines.next().?.len),
            .y = y,
        };

        return .{
            .mirrors = mirrors,
            .size = size,
        };
    }
};

fn calculateEnergizedTiles(allocator: Allocator, map: Map, starting_beam: Beam) !usize {
    const beam_states = try map.simulateBeams(allocator, starting_beam);
    defer allocator.free(beam_states);
    var unique_positions = std.AutoHashMap(Vec2, void).init(allocator);
    defer unique_positions.deinit();
    for (beam_states) |b| {
        try unique_positions.put(b.position, {});
    }
    const num_positions = unique_positions.count();

    // try stdout.print("Found {d} unique beam states\n", .{beam_states.len});
    // try stdout.print("Found {d} unique positions\n", .{num_positions});

    return num_positions;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const map = try Map.parse(aa, input);
    const energized_tiles = try calculateEnergizedTiles(allocator, map, Beam{
        .position = .{
            .x = 0,
            .y = 0,
        },
        .direction = Vec2.right(),
    });

    return @intCast(energized_tiles);
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const map = try Map.parse(aa, input);

    var highest_energized_tiles: usize = 0;
    // top row
    for (0..@as(usize, @intCast(map.size.x))) |x| {
        const beam = Beam{
            .position = .{
                .x = @intCast(x),
                .y = 0,
            },
            .direction = Vec2.down(),
        };
        const energized_tiles = try calculateEnergizedTiles(allocator, map, beam);

        if (energized_tiles > highest_energized_tiles) {
            highest_energized_tiles = energized_tiles;
            try stdout.print("Found new optimum {d} with {any}\n", .{ highest_energized_tiles, beam });
        }
    }

    return @intCast(highest_energized_tiles);
}

test "simple 1" {
    const data =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 46), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 51), try process2(allocator, data));
}
