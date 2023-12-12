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

const List = std.ArrayList(i64);

fn parseSequence(allocator: Allocator, line: []const u8) !List {
    var num_strs = std.mem.splitScalar(u8, line, ' ');

    var sequence = List.init(allocator);
    while (num_strs.next()) |num_str| {
        const num = try std.fmt.parseInt(i64, num_str, 10);
        try sequence.append(num);
    }

    return sequence;
}

fn diff(allocator: Allocator, xs: []const i64) !List {
    var ds = List.init(allocator);

    for (0..xs.len - 1) |i| {
        try ds.append(xs[i + 1] - xs[i]);
    }

    return ds;
}

fn allZeroes(xs: []i64) bool {
    for (xs) |x| {
        if (x != 0) {
            return false;
        }
    }

    return true;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var lines = std.mem.splitScalar(u8, input, '\n');

    var extension_sum: i64 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var sequences = std.ArrayList(List).init(aa);
        const starting_sequence = try parseSequence(aa, line);
        try sequences.append(starting_sequence);

        while (!allZeroes(sequences.getLast().items)) {
            const last = sequences.getLast();
            const difference = try diff(aa, last.items);
            try sequences.append(difference);
        }

        var extension: i64 = 0;
        while (sequences.items.len >= 1) {
            var last = sequences.pop();
            const last_item = last.items[last.items.len - 1];
            const extension_next = last_item + extension;
            extension = extension_next;

            last.deinit();
        }
        extension_sum += extension;

        sequences.deinit();
    }

    return extension_sum;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var lines = std.mem.splitScalar(u8, input, '\n');

    var extension_sum: i64 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var sequences = std.ArrayList(List).init(aa);
        const starting_sequence = try parseSequence(aa, line);
        print("Input: \n{any}\n", .{starting_sequence.items});
        try sequences.append(starting_sequence);

        while (!allZeroes(sequences.getLast().items)) {
            const last = sequences.getLast();
            const difference = try diff(aa, last.items);
            try sequences.append(difference);
            print("\t{any}\n", .{last.items});
        }

        var extension: i64 = 0;
        while (sequences.items.len >= 1) {
            var last = sequences.pop();
            const first_item = last.items[0];
            const extension_next = first_item - extension;
            print("Seq: {any}: {d} + {d} = {d}\n", .{ last.items, first_item, extension, extension_next });
            extension = extension_next;

            last.deinit();
        }
        extension_sum += extension;

        sequences.deinit();
    }

    return extension_sum;
}

test "simple 1" {
    const data =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 114), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 2), try process2(allocator, data));
}
