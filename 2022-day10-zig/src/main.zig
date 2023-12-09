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
    try stdout.print("Result 2:\n{s}\n", .{output2});

    try bw.flush();
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

const Processor = struct {
    cycle: i64,
    x: i64,
    signal_strength_sum: i64,
    crt_position: i64,
    crt: std.ArrayList(u8),

    pub fn init(allocator: Allocator) Processor {
        return .{
            .cycle = 0,
            .x = 1,
            .signal_strength_sum = 0,
            .crt_position = 0,
            .crt = std.ArrayList(u8).init(allocator),
        };
    }
    pub fn deinit(self: *Processor) void {
        self.crt.deinit();
    }

    fn is_signal_strength_cycle(cycle: i64) bool {
        if (@mod(cycle - 20, 40) == 0) {
            return true;
        }

        return false;
    }

    fn draw_crt(self: *Processor) !void {
        if (@mod(self.cycle - 1, 40) == 0 and self.cycle > 0) {
            try self.crt.append('\n');
        }

        const is_visible = @abs(self.x - self.crt_position) <= 1;
        if (is_visible) {
            try self.crt.append('#');
        } else {
            try self.crt.append(' ');
        }

        self.crt_position = @mod(self.crt_position + 1, 40);
    }

    fn increment_cycle(self: *Processor) !void {
        self.cycle += 1;

        if (Processor.is_signal_strength_cycle(self.cycle)) {
            const signal_strength = self.cycle * self.x;
            std.debug.print("Cycle {d}: {d}*{d} = {d} -> ", .{ self.cycle, self.cycle, self.x, signal_strength });
            self.signal_strength_sum += signal_strength;
            std.debug.print("{d}\n", .{self.signal_strength_sum});
        }

        try self.draw_crt();
    }

    pub fn execute(self: *Processor, i: Instruction) !void {
        switch (i) {
            .noop => {
                try self.increment_cycle();
            },
            .addx => |value| {
                try self.increment_cycle();
                try self.increment_cycle();
                self.x += value;
            },
        }
    }
};

fn hasPrefix(prefix: []const u8, str: []const u8) bool {
    if (prefix.len > str.len) {
        return false;
    }

    return std.mem.eql(u8, str[0..prefix.len], prefix);
}

fn parseInput(allocator: Allocator, input: []const u8) !std.ArrayList(Instruction) {
    var lines = std.mem.splitScalar(u8, input, '\n');
    var instructions = std.ArrayList(Instruction).init(allocator);
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const instruction = try Instruction.parse(line);
        try instructions.append(instruction);
    }

    return instructions;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    const instructions = try parseInput(allocator, input);
    defer instructions.deinit();

    var proc = Processor.init(allocator);
    defer proc.deinit();

    var i: i64 = 0;
    for (instructions.items) |instruction| {
        std.debug.print("Instruction {d}: {any}\n", .{ i, instruction });
        try proc.execute(instruction);
        i += 1;
    }
    return proc.signal_strength_sum;
}

fn process2(allocator: Allocator, input: []const u8) ![]const u8 {
    const instructions = try parseInput(allocator, input);
    defer instructions.deinit();

    var proc = Processor.init(allocator);
    defer proc.deinit();
    for (instructions.items) |instruction| {
        try proc.execute(instruction);
    }

    return try proc.crt.toOwnedSlice();
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
        \\addx 15
        \\addx -11
        \\addx 6
        \\addx -3
        \\addx 5
        \\addx -1
        \\addx -8
        \\addx 13
        \\addx 4
        \\noop
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx -35
        \\addx 1
        \\addx 24
        \\addx -19
        \\addx 1
        \\addx 16
        \\addx -11
        \\noop
        \\noop
        \\addx 21
        \\addx -15
        \\noop
        \\noop
        \\addx -3
        \\addx 9
        \\addx 1
        \\addx -3
        \\addx 8
        \\addx 1
        \\addx 5
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx -36
        \\noop
        \\addx 1
        \\addx 7
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\addx 6
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx 7
        \\addx 1
        \\noop
        \\addx -13
        \\addx 13
        \\addx 7
        \\noop
        \\addx 1
        \\addx -33
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\noop
        \\noop
        \\noop
        \\addx 8
        \\noop
        \\addx -1
        \\addx 2
        \\addx 1
        \\noop
        \\addx 17
        \\addx -9
        \\addx 1
        \\addx 1
        \\addx -3
        \\addx 11
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx -13
        \\addx -19
        \\addx 1
        \\addx 3
        \\addx 26
        \\addx -30
        \\addx 12
        \\addx -1
        \\addx 3
        \\addx 1
        \\noop
        \\noop
        \\noop
        \\addx -9
        \\addx 18
        \\addx 1
        \\addx 2
        \\noop
        \\noop
        \\addx 9
        \\noop
        \\noop
        \\noop
        \\addx -1
        \\addx 2
        \\addx -37
        \\addx 1
        \\addx 3
        \\noop
        \\addx 15
        \\addx -21
        \\addx 22
        \\addx -6
        \\addx 1
        \\noop
        \\addx 2
        \\addx 1
        \\noop
        \\addx -10
        \\noop
        \\noop
        \\addx 20
        \\addx 1
        \\addx 2
        \\addx 2
        \\addx -6
        \\addx -11
        \\noop
        \\noop
        \\noop
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 13140), try process1(allocator, data));
}
