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

    const file2 = try std.fs.cwd().openFile("input2.txt", .{});
    defer file2.close();
    const input2 = try file2.readToEndAlloc(allocator, 60 * 1024 * 1024);
    defer allocator.free(input2);
    const output2 = try process1(allocator, input2);
    try stdout.print("Result 2: {d}\n", .{output2});

    try bw.flush(); // don't forget to flush!
}

const ProgramError = error{
    AnyError,
};

fn parseList(comptime T: type, allocator: Allocator, line: []const u8, prefix: []const u8) ![]T {
    var number_strs = std.mem.tokenizeScalar(u8, line[prefix.len..], ' ');

    var numbers = std.ArrayList(T).init(allocator);
    while (number_strs.next()) |number_str| {
        try numbers.append(try std.fmt.parseInt(T, number_str, 10));
    }

    return try numbers.toOwnedSlice();
}

fn simulateRace(hold_time: usize, race_time: usize) usize {
    const speed = hold_time;
    const distance = (race_time - hold_time) * speed;
    return distance;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var lines = std.mem.splitScalar(u8, input, '\n');
    const times = try parseList(usize, aa, lines.next().?, "Time:");
    const distances = try parseList(usize, aa, lines.next().?, "Distance:");
    const number_of_races = times.len;

    std.debug.print("Times: {any}\n", .{times});
    std.debug.print("Distances: {any}\n", .{distances});
    var margin: usize = 1;
    for (0..number_of_races) |i| {
        const race_time = times[i];
        const distance_to_beat = distances[i];

        var ways_to_beat: usize = 0;
        for (0..race_time) |hold_time| {
            const distance = simulateRace(hold_time, race_time);
            if (distance > distance_to_beat) {
                ways_to_beat += 1;
            }
        }

        margin *= ways_to_beat;
    }

    return @intCast(margin);
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    _ = input;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    return 0;
}

test "simple 1" {
    const data =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 288), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\Time:      71530
        \\Distance:  940200
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 71503), try process1(allocator, data));
}

// test "simple 2" {
//     const data =
//         \\Time:      7  15   30
//         \\Distance:  9  40  200
//     ;
//
//     const allocator = std.testing.allocator;
//     try std.testing.expectEqual(@as(i64, 288), try process2(allocator, data));
// }
