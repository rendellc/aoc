const std = @import("std");
const Allocator = std.mem.Allocator;

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

const HeadMove = enum {
    up,
    down,
    left,
    right,

    pub fn fromChar(char: u8) !HeadMove {
        switch (char) {
            'U' => return HeadMove.up,
            'D' => return HeadMove.down,
            'L' => return HeadMove.left,
            'R' => return HeadMove.right,
            else => {},
        }

        return ProgramError.AnyError;
    }
};

const Position = struct {
    x: i32,
    y: i32,
};

const Head = struct {
    position: Position,

    fn applyMove(self: *Head, move: HeadMove) void {
        switch (move) {
            .up => {
                self.position.y += 1;
            },
            .down => {
                self.position.y -= 1;
            },
            .left => {
                self.position.x -= 1;
            },
            .right => {
                self.position.x += 1;
            },
        }
    }
};

const Tail = struct {
    position: Position,

    fn isAdjacent(self: Tail, position: Position) bool {
        const x_error = position.x - self.position.x;
        const y_error = position.y - self.position.y;
        const x_error_abs: i8 = @intCast(@abs(x_error));
        const y_error_abs: i8 = @intCast(@abs(y_error));

        if (x_error_abs <= 1 and y_error_abs <= 1) {
            return true;
        }

        return false;
    }

    fn follow(self: *Tail, position: Position) void {
        if (self.isAdjacent(position)) {
            return;
        }

        const x_error = position.x - self.position.x;
        const y_error = position.y - self.position.y;

        self.position.x += @max(@min(x_error, 1), -1);
        self.position.y += @max(@min(y_error, 1), -1);
    }
};

fn parseHeadMoves(allocator: Allocator, input: []const u8) !std.ArrayList(HeadMove) {
    var lines = std.mem.splitScalar(u8, input, '\n');
    var head_moves = std.ArrayList(HeadMove).init(allocator);
    while (lines.next()) |line| {
        if (line.len < 3) {
            continue;
        }

        const move = try HeadMove.fromChar(line[0]);
        const count = try std.fmt.parseInt(u8, line[2..], 10);
        for (0..count) |_| {
            try head_moves.append(move);
        }
    }

    return head_moves;
}

fn boundingBox(positions: []const Position) ?Position {
    if (positions.len == 0) {
        return null;
    }

    var position_max: Position = .{ .x = 0, .y = 0 };
    for (positions) |position| {
        if (position.x > position_max.x) {
            position_max.x = position.x;
        }

        if (position.y > position_max.y) {
            position_max.y = position.y;
        }
    }

    return position_max;
}

fn countUnique(comptime T: type, allocator: Allocator, items: []const T) !u32 {
    if (items.len == 0) {
        return 0;
    }

    var set = std.AutoHashMap(T, void).init(allocator);

    defer set.deinit();
    for (items) |i| {
        try set.put(i, {});
    }

    const count = set.count();
    std.debug.print("Counted {d} out of {d} items as unique\n", .{ count, items.len });

    return count;
}

fn process1(allocator: Allocator, input: []const u8) !usize {
    const head_moves = try parseHeadMoves(allocator, input);
    defer head_moves.deinit();

    var head_positions = std.ArrayList(Position).init(allocator);
    var tail_positions = std.ArrayList(Position).init(allocator);
    defer head_positions.deinit();
    defer tail_positions.deinit();

    var head = Head{ .position = .{
        .x = 0,
        .y = 0,
    } };
    var tail = Tail{ .position = .{
        .x = 0,
        .y = 0,
    } };

    try head_positions.append(head.position);
    try tail_positions.append(tail.position);
    for (head_moves.items) |move| {
        head.applyMove(move);
        tail.follow(head.position);

        // Assert that tail still tracks the head
        std.debug.assert(@abs(head.position.x - tail.position.x) <= 1 and @abs(head.position.y - tail.position.y) <= 1);

        try head_positions.append(head.position);
        try tail_positions.append(tail.position);
    }

    const unique_tail_positions = try countUnique(Position, allocator, tail_positions.items);

    return unique_tail_positions;
}

fn process2(allocator: Allocator, input: []const u8) !usize {
    const head_moves = try parseHeadMoves(allocator, input);
    defer head_moves.deinit();

    var tails = std.ArrayList(Tail).init(allocator);
    defer tails.deinit();
    const number_of_tails = 9;
    for (0..number_of_tails) |_| {
        try tails.append(Tail{ .position = .{
            .x = 0,
            .y = 0,
        } });
    }

    var tail_positions = std.ArrayList(Position).init(allocator);
    defer tail_positions.deinit();

    var head = Head{ .position = .{
        .x = 0,
        .y = 0,
    } };

    try tail_positions.append(tails.items[number_of_tails - 1].position);
    for (head_moves.items) |move| {
        head.applyMove(move);

        tails.items[0].follow(head.position);
        for (1..number_of_tails) |i| {
            tails.items[i].follow(tails.items[i - 1].position);
        }

        try tail_positions.append(tails.items[number_of_tails - 1].position);
    }

    const unique_tail_positions = try countUnique(Position, allocator, tail_positions.items);

    return unique_tail_positions;
}

test "simple 1" {
    const data =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 13), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 1), try process2(allocator, data));
}

test "simple 3" {
    const data =
        \\D 1
        \\D 1
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 2), try process1(allocator, data));
}

test "parse headmove" {
    const data =
        \\D 4
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 4), try process1(allocator, data));
}

test "simple 4" {
    const data =
        \\D 4
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 4), try process1(allocator, data));
}

test "count unique u8" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(u32, 11), try countUnique(u8, allocator, &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }));
    try std.testing.expectEqual(@as(u32, 1), try countUnique(u8, allocator, &[_]u8{ 0, 0, 0, 0, 0 }));
    try std.testing.expectEqual(@as(u32, 3), try countUnique(u8, allocator, &[_]u8{ 0, 1, 0, 0, 2 }));
}

test "count unique Position" {
    const allocator = std.testing.allocator;
    const data = &[_]Position{
        .{
            .x = 0,
            .y = 0,
        },
        .{
            .x = 0,
            .y = 0,
        },
        .{
            .x = 1,
            .y = 0,
        },
        .{
            .x = 1,
            .y = 0,
        },
        .{
            .x = 0,
            .y = 1,
        },
        .{
            .x = 0,
            .y = 2,
        },
        .{
            .x = -1,
            .y = 0,
        },
    };
    try std.testing.expectEqual(@as(u32, 5), try countUnique(Position, allocator, data));
}

//test "simple 2" {
//    const data =
//        \\R 4
//        \\U 4
//        \\D 1
//        \\L 3
//        \\R 4
//        \\D 1
//        \\L 5
//        \\R 2
//    ;
//
//    const allocator = std.testing.allocator;
//    try std.testing.expectEqual(@as(usize, 8), try process2(allocator, data));
//}
