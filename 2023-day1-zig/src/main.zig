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

fn isDigit(char: u8) bool {
    if ('0' <= char and char <= '9') {
        return true;
    }

    return false;
}

fn toMaybeWordDigit(buf: []const u8, i: usize) ?u8 {
    const max_length = buf.len - i;
    if (max_length < 3) {
        return null;
    }

    if (max_length >= 4 and std.mem.eql(u8, buf[i .. i + 4], "zero")) {
        return 0;
    } else if (max_length >= 3 and std.mem.eql(u8, buf[i .. i + 3], "one")) {
        return 1;
    } else if (max_length >= 3 and std.mem.eql(u8, buf[i .. i + 3], "two")) {
        return 2;
    } else if (max_length >= 5 and std.mem.eql(u8, buf[i .. i + 5], "three")) {
        return 3;
    } else if (max_length >= 4 and std.mem.eql(u8, buf[i .. i + 4], "four")) {
        return 4;
    } else if (max_length >= 4 and std.mem.eql(u8, buf[i .. i + 4], "five")) {
        return 5;
    } else if (max_length >= 3 and std.mem.eql(u8, buf[i .. i + 3], "six")) {
        return 6;
    } else if (max_length >= 5 and std.mem.eql(u8, buf[i .. i + 5], "seven")) {
        return 7;
    } else if (max_length >= 5 and std.mem.eql(u8, buf[i .. i + 5], "eight")) {
        return 8;
    } else if (max_length >= 4 and std.mem.eql(u8, buf[i .. i + 4], "nine")) {
        return 9;
    }

    return null;
}

fn toDigit(char: u8) !u8 {
    if ('0' <= char and char <= '9') {
        return char - '0';
    }

    return ProgramError.AnyError;
}

fn process1(allocator: Allocator, input: []const u8) !usize {
    var lines = std.mem.splitScalar(u8, input, '\n');
    var calibration_values = std.ArrayList(u8).init(allocator);
    defer calibration_values.deinit();
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var first_digit: ?u8 = null;
        var last_digit: ?u8 = null;
        for (line) |c| {
            if (!isDigit(c)) {
                continue;
            }
            const digit = try toDigit(c);
            if (first_digit == null) {
                first_digit = digit;
            }
            last_digit = digit;
        }

        const calibration_value = 10 * first_digit.? + last_digit.?;
        try calibration_values.append(calibration_value);
    }

    var calibration_sum: u32 = 0;
    for (calibration_values.items) |v| {
        calibration_sum += v;
    }

    return calibration_sum;
}

fn process2(allocator: Allocator, input: []const u8) !usize {
    var lines = std.mem.splitScalar(u8, input, '\n');
    var calibration_values = std.ArrayList(u8).init(allocator);
    defer calibration_values.deinit();
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var first_digit: ?u8 = null;
        var last_digit: ?u8 = null;
        for (line, 0..) |c, i| {
            var digit: ?u8 = null;
            if (isDigit(c)) {
                digit = try toDigit(c);
            }
            if (digit == null) {
                digit = toMaybeWordDigit(line, i);
            }

            if (digit == null) {
                continue;
            }

            if (first_digit == null) {
                first_digit = digit;
            }
            last_digit = digit;
        }

        const calibration_value = 10 * first_digit.? + last_digit.?;
        try calibration_values.append(calibration_value);
    }

    var calibration_sum: u32 = 0;
    for (calibration_values.items) |v| {
        calibration_sum += v;
    }

    return calibration_sum;
}

test "simple 1" {
    const data =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 142), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 281), try process2(allocator, data));
}
