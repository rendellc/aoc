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

const Instruction = union(enum) {
    noop: void,
    addx: i64,

    pub fn parse(str: []const u8) !Instruction {
        if (hasPrefix("noop", str)) {
            return Instruction{ .noop = {} };
        } else if (hasPrefix("addx", str)) {
            const value = try std.fmt.parseInt(i64, str[5..], 10);

            return Instruction{
                .addx = value,
            };
        }

        std.debug.print("Unable to parse '{s}' to Instruction", .{str});
        return ProgramError.AnyError;
    }
};

fn hasPrefix(prefix: []const u8, str: []const u8) bool {
    if (prefix.len > str.len) {
        return false;
    }

    return std.mem.eql(u8, str, prefix);
}

fn parseInput(allocator: Allocator, input: []const u8) !std.ArrayList(Instruction) {
    var instructions = std.ArrayList(Instruction).init(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const instruction = try Instruction.parse(line);
        try instructions.append(instruction);
    }

    return instructions;
}

fn process1(allocator: Allocator, input: []const u8) !usize {
    const instructions = try parseInput(allocator, input);
    defer instructions.deinit();

    std.debug.print("\n{any}\n", .{instructions});

    return 0;
}

fn process2(allocator: Allocator, input: []const u8) !usize {
    _ = input;
    _ = allocator;
    return 0;
}

test "Instruction parser" {
    try std.testing.expectEqual(Instruction{ .noop = {} }, try Instruction.parse("noop"));
    try std.testing.expectEqual(Instruction{ .addx = 1 }, try Instruction.parse("addx 1"));
    try std.testing.expectEqual(Instruction{ .addx = 0 }, try Instruction.parse("addx 0"));
    try std.testing.expectEqual(Instruction{ .addx = -1 }, try Instruction.parse("addx -1"));
    try std.testing.expectEqual(Instruction{ .addx = 3710 }, try Instruction.parse("addx 3710"));
    try std.testing.expectEqual(Instruction{ .addx = -10123 }, try Instruction.parse("addx -10123"));
}

test "small" {
    const data =
        \\noop
        \\addx 3
        \\addx -5
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 142), try process1(allocator, data));
}
