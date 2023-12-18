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

fn Array2D(comptime T: type) type {
    return struct {
        data: []T,
        width: usize,
        height: usize,

        const Self = @This();

        fn toIndex(self: Self, x: usize, y: usize) usize {
            return x + self.width * y;
        }

        pub fn init(allocator: Allocator, width: usize, height: usize, default: T) !Self {
            var data = try allocator.alloc(T, width * height);
            @memset(data[0..], default);

            return .{
                .data = data,
                .width = width,
                .height = height,
            };
        }

        pub fn set(self: *Self, x: usize, y: usize, value: T) void {
            const i = self.toIndex(x, y);
            self.data[i] = value;
        }

        pub fn get(self: Self, x: usize, y: usize) T {
            const i = self.toIndex(x, y);
            return self.data[i];
        }

        pub fn count(self: Self, value: T) usize {
            return std.mem.count(T, self.data, &[1]T{value});
        }

        pub fn hash(self: Self) u32 {
            const hasher = std.hash.uint32;

            var h: u32 = 1;
            h = hasher(h +% @as(u32, @intCast(self.width)));
            h = hasher(h +% @as(u32, @intCast(self.height)));

            for (self.data) |d| {
                h = hasher(h +% d.toU32());
            }

            return h;
        }
    };
}

const Stone = enum {
    empty,
    round,
    square,

    pub fn fromChar(char: u8) !Stone {
        return switch (char) {
            '.' => Stone.empty,
            'O' => Stone.round,
            '#' => Stone.square,
            else => {
                dprint("Unable to parse '{c}' to Stone\n", .{char});
                return ProgramError.AnyError;
            },
        };
    }

    pub fn toU32(self: Stone) u32 {
        return switch (self) {
            Stone.empty => 1,
            Stone.round => 2,
            Stone.square => 3,
        };
    }
};

const CycleData = struct {
    start: usize,
    period: usize,
};

const Map = struct {
    layout: Array2D(Stone),
    cycle_count: usize,

    pub fn tiltSouth(self: *Map) void {
        for (0..self.layout.width) |x| {
            var current_tilt_y = self.layout.height - 1;
            for (0..self.layout.height) |y| {
                const y_rev = self.layout.height - 1 - y;
                const stone = self.layout.get(x, y_rev);
                switch (stone) {
                    Stone.round => {
                        self.layout.set(x, y_rev, Stone.empty);
                        self.layout.set(x, current_tilt_y, Stone.round);
                        if (current_tilt_y > 0) {
                            current_tilt_y -= 1;
                        }
                    },
                    Stone.square => {
                        if (y_rev > 0) {
                            current_tilt_y = y_rev - 1;
                        }
                    },
                    Stone.empty => {},
                }
            }
        }
    }

    pub fn tiltNorth(self: *Map) void {
        for (0..self.layout.width) |x| {
            var current_tilt_y: usize = 0;
            for (0..self.layout.height) |y| {
                const stone = self.layout.get(x, y);
                switch (stone) {
                    Stone.round => {
                        self.layout.set(x, y, Stone.empty);
                        self.layout.set(x, current_tilt_y, Stone.round);
                        current_tilt_y += 1;
                    },
                    Stone.square => {
                        current_tilt_y = y + 1;
                    },
                    Stone.empty => {},
                }
            }
        }
    }

    pub fn tiltEast(self: *Map) void {
        for (0..self.layout.height) |y| {
            var current_tilt_x = self.layout.width - 1;
            for (0..self.layout.width) |x| {
                const x_rev = self.layout.width - 1 - x;
                const stone = self.layout.get(x_rev, y);
                switch (stone) {
                    Stone.round => {
                        self.layout.set(x_rev, y, Stone.empty);
                        self.layout.set(current_tilt_x, y, Stone.round);
                        if (current_tilt_x > 0) {
                            current_tilt_x -= 1;
                        }
                    },
                    Stone.square => {
                        if (x_rev > 0) {
                            current_tilt_x = x_rev - 1;
                        }
                    },
                    Stone.empty => {},
                }
            }
        }
    }

    pub fn tiltWest(self: *Map) void {
        for (0..self.layout.height) |y| {
            var current_tilt_x: usize = 0;
            for (0..self.layout.width) |x| {
                const stone = self.layout.get(x, y);
                switch (stone) {
                    Stone.round => {
                        self.layout.set(x, y, Stone.empty);
                        self.layout.set(current_tilt_x, y, Stone.round);
                        current_tilt_x += 1;
                    },
                    Stone.square => {
                        current_tilt_x = x + 1;
                    },
                    Stone.empty => {},
                }
            }
        }
    }

    pub fn tiltCycle(self: *Map) void {
        self.cycle_count += 1;
        self.tiltNorth();
        self.tiltWest();
        self.tiltSouth();
        self.tiltEast();
    }

    pub fn findTiltCycleData(self: *Map, allocator: Allocator) CycleData {
        std.debug.assert(self.cycle_count == 0);

        var history = std.AutoHashMap(u32, usize).init(allocator);
        defer history.deinit();
        var history_match: ?usize = null;
        while (history_match == null) {
            self.tiltCycle();
            history_match = history.get(self.layout.hash());
            if (history_match == null) {
                history.put(self.layout.hash(), self.cycle_count) catch unreachable;
            }
        }

        dprint("Current cycle {d}: {d} in history matches\n", .{ self.cycle_count, history_match.? });
        const first_repeated_cycle = history_match.?;
        const length = self.cycle_count - first_repeated_cycle;

        return .{
            .start = first_repeated_cycle,
            .period = length,
        };
    }

    pub fn init(allocator: Allocator, input: []const u8) !Map {
        const width = std.mem.indexOfScalar(u8, input, '\n').?;
        const height = try std.math.divCeil(usize, input.len, width + 1);

        var layout = try Array2D(Stone).init(allocator, width, height, Stone.empty);

        var lines = std.mem.splitScalar(u8, input, '\n');
        var y: usize = 0;
        while (lines.next()) |line| : (y += 1) {
            if (line.len == 0) continue;

            for (line, 0..) |c, x| {
                const stone = try Stone.fromChar(c);
                layout.set(x, y, stone);
            }
        }

        return .{
            .layout = layout,
            .cycle_count = 0,
        };
    }

    pub fn printMap(self: Map) void {
        const stdout = std.io.getStdOut().writer();
        for (0..self.layout.height) |y| {
            for (0..self.layout.width) |x| {
                const stone = self.layout.get(x, y);
                switch (stone) {
                    Stone.empty => stdout.print(" ", .{}) catch unreachable,
                    Stone.round => stdout.print("O", .{}) catch unreachable,
                    Stone.square => stdout.print("#", .{}) catch unreachable,
                }
            }
            stdout.print("\n", .{}) catch unreachable;
        }
    }

    pub fn calculateNorthLoad(self: Map) i64 {
        var load: i64 = 0;
        for (0..self.layout.height) |y| {
            for (0..self.layout.width) |x| {
                const stone = self.layout.get(x, y);
                if (stone == Stone.round) {
                    load += @intCast(self.layout.height - y);
                }
            }
        }

        return load;
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var map = try Map.init(aa, input);
    map.tiltNorth();
    const load = map.calculateNorthLoad();

    return load;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var map = try Map.init(aa, input);

    const number_of_cycles = 1000 * 1000 * 1000;
    const cycle_data = map.findTiltCycleData(aa);
    const remaining_cycles = @mod(number_of_cycles - map.cycle_count, cycle_data.period);

    for (0..remaining_cycles) |_| {
        map.tiltCycle();
    }

    dprint("After {d} cycles: {d}\n", .{ map.cycle_count, map.calculateNorthLoad() });
    // map.printMap();
    dprint("\n", .{});
    // std.debug.assert(map.cycle_count == reduced_number_of_cycles);
    const load = map.calculateNorthLoad();
    // map.printMap();

    return load;
}

test "simple 1" {
    const data =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 136), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 64), try process2(allocator, data));
}
