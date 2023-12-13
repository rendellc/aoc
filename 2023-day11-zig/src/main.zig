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

const Galaxy = struct {
    x: i64,
    y: i64,
    id: i64,

    pub fn sortByID(gs: *[]Galaxy) void {
        const Context = struct {
            fn lessThanFn(ctx: @This(), lhs: Galaxy, rhs: Galaxy) bool {
                _ = ctx;
                return lhs.id < rhs.id;
            }
        };

        std.sort.insertion(Galaxy, gs.*, Context{}, Context.lessThanFn);
    }

    pub fn distanceTo(self: Galaxy, other: Galaxy) i64 {
        // manhattan distance
        const dx = self.x - other.x;
        const dy = self.y - other.y;

        return @intCast(@abs(dx) + @abs(dy));
    }
};

const Universe = struct {
    galaxies: []Galaxy,
    max_x: i64,
    max_y: i64,

    pub fn init(allocator: Allocator, input: []const u8) !Universe {
        var galaxies = std.ArrayList(Galaxy).init(allocator);

        var lines = std.mem.splitScalar(u8, input, '\n');
        var max_x: i64 = 0;
        var max_y: i64 = 0;
        var y: i64 = 0;
        var id: i64 = 1;
        while (lines.next()) |line| {
            if (line.len == 0) continue;

            for (line, 0..) |c, x| {
                const _x: i64 = @intCast(x);
                const _y: i64 = @intCast(y);
                if (c == '#') {
                    try galaxies.append(Galaxy{
                        .x = _x,
                        .y = _y,
                        .id = id,
                    });
                    max_x = @max(_x, max_x);
                    max_y = @max(_y, max_y);
                    id += 1;
                }
            }

            y += 1;
        }

        return .{
            .galaxies = try galaxies.toOwnedSlice(),
            .max_x = max_x,
            .max_y = max_y,
        };
    }

    pub fn print(self: Universe, allocator: Allocator) !void {
        const stdout = std.io.getStdOut().writer();

        // max values are 0-indexed
        const n_columns = self.max_x + 1;
        const n_rows = self.max_y + 1;

        var str = try allocator.alloc(u8, @intCast((n_columns + 1) * n_rows));
        defer allocator.free(str);
        @memset(str, '.');

        var newline_index = n_columns;
        while (newline_index < str.len) : (newline_index += n_columns + 1) {
            str[@intCast(newline_index)] = '\n';
        }

        for (self.galaxies) |g| {
            const index = g.x + (n_columns + 1) * g.y;
            str[@intCast(index)] = '#';
        }

        try stdout.print("{s}\n", .{str});
    }

    pub fn isEmptyRow(self: Universe, y: i64) bool {
        for (self.galaxies) |g| {
            if (g.y == y) {
                return false;
            }
        }

        return true;
    }

    pub fn isEmptyColumn(self: Universe, x: i64) bool {
        for (self.galaxies) |g| {
            if (g.x == x) {
                return false;
            }
        }

        return true;
    }

    pub fn expandColumns(self: *Universe, from_x: i64, to_x: i64, factor: i64) void {
        const extra_columns = (factor - 1) * (from_x - to_x + 1);
        for (self.galaxies) |*g| {
            if (g.*.x < from_x) continue;

            if (from_x <= g.*.x and g.*.x <= to_x) {
                dprint("Expected expand to be called on empty column\n", .{});
                unreachable;
            }

            g.*.x += extra_columns;
        }

        self.max_x += extra_columns;
    }

    pub fn expandRows(self: *Universe, from_y: i64, to_y: i64, factor: i64) void {
        const extra_rows = (factor - 1) * (from_y - to_y + 1);
        for (self.galaxies) |*g| {
            if (g.*.y < from_y) continue;

            if (from_y <= g.*.y and g.*.y <= to_y) {
                dprint("Expected expandRows to be called on empty rows\n", .{});
                unreachable;
            }

            g.*.y += extra_rows;
        }

        self.max_y += extra_rows;
    }

    pub fn expand(self: *Universe, factor: i64) void {
        var x: i64 = 0;
        while (x <= self.max_x) : (x += 1) {
            if (!self.isEmptyColumn(x)) continue;

            // column x is empty
            // dprint("Expanding columns: {d}\n", .{x});
            self.expandColumns(x, x, factor);
            x += factor - 1;
        }

        var y: i64 = 0;
        while (y <= self.max_y) : (y += 1) {
            if (!self.isEmptyRow(y)) continue;

            // column x is empty
            // dprint("Expanding rows: {d}\n", .{y});
            self.expandRows(y, y, factor);
            y += factor - 1;
        }
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    // dprint("Input\n{s}\n", .{input});
    var universe = try Universe.init(aa, input);
    // dprint("Universe:\n", .{});
    // try universe.print(aa);

    universe.expand(2);
    // dprint("Universe expanded:\n", .{});
    // try universe.print(aa);

    const gs = universe.galaxies;
    var distance_sum: i64 = 0;
    for (gs, 0..) |g1, i| {
        if (i == gs.len - 1) continue;

        for (gs[i + 1 ..]) |g2| {
            const distance = g1.distanceTo(g2);
            // dprint("Distance {d}->{d}: {d}\n", .{ g1.id, g2.id, distance });
            distance_sum += distance;
        }
    }

    return distance_sum;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    // dprint("Input\n{s}\n", .{input});
    var universe = try Universe.init(aa, input);
    // dprint("Universe:\n", .{});
    // try universe.print(aa);

    universe.expand(1000000);
    // dprint("Universe expanded:\n", .{});
    // try universe.print(aa);

    const gs = universe.galaxies;
    var distance_sum: i64 = 0;
    for (gs, 0..) |g1, i| {
        if (i == gs.len - 1) continue;

        for (gs[i + 1 ..]) |g2| {
            const distance = g1.distanceTo(g2);
            // dprint("Distance {d}->{d}: {d}\n", .{ g1.id, g2.id, distance });
            distance_sum += distance;
        }
    }

    return distance_sum;
}

test "process 1: simple 1" {
    const data =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 374), try process1(allocator, data));
}
