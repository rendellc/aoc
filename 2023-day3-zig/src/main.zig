const std = @import("std");
const Allocator = std.mem.Allocator;

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

    try bw.flush(); // don't forget to flush!
}

const ProgramError = error{
    AnyError,
};

const Symbol = struct {
    x: i64,
    y: i64,
    s: u8,
};

const Number = struct {
    n: i64, // the number
    x_min: i64,
    x_max: i64,
    y: i64,
    index: usize, // the number

    /// .s...
    /// .nnn.
    /// .....
    fn is_adjacent(n: Number, s: Symbol) bool {
        if (s.y < n.y - 1 or s.y > n.y + 1) {
            return false;
        }

        if (s.x < n.x_min - 1 or s.x > n.x_max + 1) {
            return false;
        }

        return true;
    }
};

fn is_symbol(c: u8) bool {
    if (c == '.') {
        return false;
    }
    if ('0' <= c and c <= '9') {
        return false;
    }

    return true;
}

fn parse_symbols(allocator: Allocator, input: []const u8) !std.ArrayList(Symbol) {
    var symbols = std.ArrayList(Symbol).init(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    var y: i64 = 0;
    while (lines.next()) |line| {
        for (line, 0..) |c, x| {
            if (is_symbol(c)) {
                try symbols.append(.{
                    .x = @intCast(x),
                    .y = y,
                    .s = c,
                });
            }
        }
        y += 1;
    }

    return symbols;
}

const non_numbers = ".+-@/$%*#&=\n";

fn parse_numbers(allocator: Allocator, input: []const u8) !std.ArrayList(Number) {
    var numbers = std.ArrayList(Number).init(allocator);
    const row_len = std.mem.indexOfScalar(u8, input, '\n').?;
    std.debug.print("Line width: {d}\n", .{row_len});

    var tokens = std.mem.tokenizeAny(u8, input, non_numbers);
    while (tokens.next()) |token| {
        const begin_index = tokens.index - token.len;
        const end_index = tokens.index - 1;
        const row = std.mem.count(u8, input[0..begin_index], "\n");

        const column_begin = begin_index - row * (row_len + 1); // +1 to account for newline
        const column_end = end_index - row * (row_len + 1);

        std.debug.print("token: {s}\n", .{token});
        std.debug.print("\tIndex {d}..{d}\n", .{ begin_index, end_index });
        std.debug.print("\tRow {d}\n", .{row});
        std.debug.print("\tColumn {d}..={d}\n", .{ column_begin, column_end });
        std.debug.assert(column_begin < row_len);
        std.debug.assert(column_end < row_len);

        try numbers.append(.{
            .n = try std.fmt.parseInt(i64, token, 10),
            .x_min = @intCast(column_begin),
            .x_max = @intCast(column_end),
            .y = @intCast(row),
            .index = begin_index,
        });
    }

    return numbers;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const symbols = try parse_symbols(aa, input);
    const numbers = try parse_numbers(aa, input);

    for (symbols.items) |symbol| {
        std.debug.print("Symbol: ({d}, {d}): {c}\n", .{ symbol.x, symbol.y, symbol.s });
    }

    var sum_of_ids: i64 = 0;
    outer: for (numbers.items) |number| {
        for (symbols.items) |symbol| {
            if (number.is_adjacent(symbol)) {
                std.debug.print("Part: {d}\n", .{number.n});
                sum_of_ids += number.n;
                continue :outer;
            }
        }
        std.debug.print("Not part: {d}\n", .{number.n});
        std.debug.print("{any}\n", .{number});
    }

    return sum_of_ids;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const symbols = try parse_symbols(aa, input);
    const numbers = try parse_numbers(aa, input);

    var sum_of_gear_ratios: i64 = 0;
    var adjacent_numbers = std.ArrayList(Number).init(allocator);
    defer adjacent_numbers.deinit();

    for (symbols.items) |symbol| {
        if (symbol.s != '*') {
            continue;
        }

        for (numbers.items) |number| {
            if (number.is_adjacent(symbol)) {
                try adjacent_numbers.append(number);
            }
        }

        if (adjacent_numbers.items.len == 2) {
            const gear_ratio = adjacent_numbers.items[0].n * adjacent_numbers.items[1].n;
            sum_of_gear_ratios += gear_ratio;
        }

        adjacent_numbers.clearRetainingCapacity();
    }

    return sum_of_gear_ratios;
}

test "parse symbols" {
    const data =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const allocator = std.testing.allocator;
    const symbols = try parse_symbols(allocator, data);
    defer symbols.deinit();

    try std.testing.expectEqual(@as(usize, 6), symbols.items.len);

    try std.testing.expectEqual(@as(i64, 3), symbols.items[0].x);
    try std.testing.expectEqual(@as(i64, 1), symbols.items[0].y);
    try std.testing.expectEqual(@as(u8, '*'), symbols.items[0].s);

    try std.testing.expectEqual(@as(i64, 6), symbols.items[1].x);
    try std.testing.expectEqual(@as(i64, 3), symbols.items[1].y);
    try std.testing.expectEqual(@as(u8, '#'), symbols.items[1].s);

    try std.testing.expectEqual(@as(i64, 3), symbols.items[2].x);
    try std.testing.expectEqual(@as(i64, 4), symbols.items[2].y);
    try std.testing.expectEqual(@as(u8, '*'), symbols.items[2].s);

    try std.testing.expectEqual(@as(i64, 5), symbols.items[3].x);
    try std.testing.expectEqual(@as(i64, 5), symbols.items[3].y);
    try std.testing.expectEqual(@as(u8, '+'), symbols.items[3].s);

    try std.testing.expectEqual(@as(i64, 3), symbols.items[4].x);
    try std.testing.expectEqual(@as(i64, 8), symbols.items[4].y);
    try std.testing.expectEqual(@as(u8, '$'), symbols.items[4].s);

    try std.testing.expectEqual(@as(i64, 5), symbols.items[5].x);
    try std.testing.expectEqual(@as(i64, 8), symbols.items[5].y);
    try std.testing.expectEqual(@as(u8, '*'), symbols.items[5].s);
}

test "simple 1" {
    const data =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 4361), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 467835), try process2(allocator, data));
}
