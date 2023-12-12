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

        return PipePart.fromChar(self.data[@intCast(index)]) catch unreachable;
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
            .y = to.y - to.x,
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

        const from_pipe = self.get(from);
        const to_pipe = self.get(to);
        print("Checking if we can travel from {c} to {c}\n", .{ self.get(from).toChar(), self.get(to).toChar() });

        var from_allows = false;
        var to_allows = false;
        if (move_east) {
            from_allows = from_pipe.allowsEastExit();
            to_allows = to_pipe.allowsWestEntry();
        }
        if (move_west) {
            from_allows = from_pipe.allowsWestExit();
            to_allows = to_pipe.allowsEastEntry();
        }
        if (move_south) {
            from_allows = from_pipe.allowsSouthExit();
            to_allows = to_pipe.allowsNorthEntry();
        }
        if (move_north) {
            from_allows = from_pipe.allowsNorthExit();
            to_allows = to_pipe.allowsSouthEntry();
        }

        return from_allows and to_allows;
    }

    pub fn init(input: []const u8) Grid {
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

    pub fn init(grid: *const Grid) PipeWalker {
        const start = grid.*.find('S').?;
        print("Start: {d} {d}\n", .{ start.x, start.y });

        var next: ?Vec2 = null;

        if (grid.*.canTravel(start, start.add(-1, 0))) {
            print("Can go west\n", .{});
            next = start.add(-1, 0);
        }
        if (grid.*.canTravel(start, start.add(1, 0))) {
            print("Can go east\n", .{});
            next = start.add(1, 0);
        }
        if (grid.*.canTravel(start, start.add(0, -1))) {
            print("Can go north\n", .{});
            next = start.add(0, -1);
        }
        if (grid.*.canTravel(start, start.add(0, 1))) {
            print("Can go south\n", .{});
            next = start.add(0, 1);
        }

        return .{
            .grid = grid,
            .start = start,
            .current = start,
            .next = next.?,
        };
    }

    pub fn step(self: *PipeWalker) void {
        _ = self;
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    const grid = Grid.init(input);
    print("Created grid with size: {d} {d}\n", .{ grid.width, grid.height });
    print("Grid: {any}\n", .{grid});
    const walker = PipeWalker.init(&grid);
    print("Walker: {any}\n", .{walker});

    return 0;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    _ = input;
    _ = allocator;

    return 0;
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
