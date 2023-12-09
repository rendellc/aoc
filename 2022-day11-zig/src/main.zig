const std = @import("std");
const Allocator = std.mem.Allocator;
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

    try bw.flush(); // don't forget to flush!
}

const ProgramError = error{
    AnyError,
};

fn parseList(comptime T: type, allocator: Allocator, line: []const u8, tokens: []const u8) !std.ArrayList(T) {
    var number_strs = std.mem.tokenizeAny(u8, line, tokens);

    var numbers = std.ArrayList(T).init(allocator);
    while (number_strs.next()) |number_str| {
        try numbers.append(try std.fmt.parseInt(T, number_str, 10));
    }

    return numbers;
}

fn findLineAfter(input: []const u8, prefix: []const u8) ?[]const u8 {
    const prefix_start = std.mem.indexOf(u8, input, prefix);
    if (prefix_start == null) {
        return null;
    }

    const content_start = prefix_start.? + prefix.len;
    const length = std.mem.indexOfScalar(u8, input[content_start..], '\n');
    if (length == null) {
        return input[content_start..];
    }

    const content = input[content_start .. content_start + length.?];
    return content;
}

const OpValue = union(enum) {
    constant: i64,
    variable: void, // (always old)

    pub fn parse(str: []const u8) OpValue {
        const value = std.fmt.parseInt(i64, str, 10) catch {
            return .{
                .variable = {},
            };
        };

        return .{
            .constant = value,
        };
    }
};

const OpValues = struct {
    v1: OpValue,
    v2: OpValue,
};

const Operation = union(enum) {
    add: OpValues,
    multiply: OpValues,

    pub fn do(self: Operation, variable: i64) i64 {
        switch (self) {
            .add => |values| {
                const v1 = switch (values.v1) {
                    .constant => |v| {
                        return v;
                    },
                    .variable => {
                        return variable;
                    },
                };
                const v2 = switch (values.v2) {
                    .constant => |v| {
                        return v;
                    },
                    .variable => {
                        return variable;
                    },
                };
                return v1 + v2;
            },
            .multiply => |values| {
                const v1 = switch (values.v1) {
                    .constant => |v| {
                        return v;
                    },
                    .variable => {
                        return variable;
                    },
                };
                const v2 = switch (values.v2) {
                    .constant => |v| {
                        return v;
                    },
                    .variable => {
                        return variable;
                    },
                };
                return v1 * v2;
            },
        }
    }

    pub fn parse(str: []const u8) !Operation {
        print("\tstr: {s}\n", .{str});
        const op_str = findLineAfter(str, "new =").?;
        var value_strs = std.mem.tokenizeAny(u8, op_str, " *+");
        const v1 = OpValue.parse(value_strs.next().?);
        const v2 = OpValue.parse(value_strs.next().?);

        const is_add = std.mem.indexOfScalar(u8, op_str, '+') != null;
        const is_multiply = std.mem.indexOfScalar(u8, op_str, '*') != null;

        if (is_add) {
            return .{
                .add = .{
                    .v1 = v1,
                    .v2 = v2,
                },
            };
        }
        if (is_multiply) {
            return .{
                .multiply = .{
                    .v1 = v1,
                    .v2 = v2,
                },
            };
        }

        return ProgramError.AnyError;
    }
};

const Monkey = struct {
    items: std.ArrayList(i64),
    operation: Operation,
    test_divisor: i64,
    inspect_counter: i64,

    pub fn parse(allocator: Allocator, monkey_block: []const u8) !Monkey {
        const item_line = findLineAfter(monkey_block, "Starting items:").?;
        const operation_line = findLineAfter(monkey_block, "Operation:").?;
        const items = try parseList(i64, allocator, item_line, ", ");
        const operation = try Operation.parse(operation_line);
        const div_content = findLineAfter(monkey_block, "divisible by ").?;
        const divisor = try std.fmt.parseInt(i64, div_content, 10);

        return .{
            .items = items,
            .operation = operation,
            .test_divisor = divisor,
            .inspect_counter = 0,
        };
    }

    pub fn inspect_items(self: *Monkey, monkeys: []Monkey) void {
        _ = monkeys;

        while (self.items.items) |*item| {
            self.inspect_counter += 1;
            item.* = self.operationFn(item.*);
        }
    }
};

fn parseInput(allocator: Allocator, input: []const u8) ![]Monkey {
    var monkeys = std.ArrayList(Monkey).init(allocator);
    var monkey_blocks = std.mem.splitSequence(u8, input, "\n\n");
    while (monkey_blocks.next()) |monkey_block| {
        if (monkey_block.len == 0) {
            continue;
        }

        try monkeys.append(try Monkey.parse(allocator, monkey_block));
    }

    return try monkeys.toOwnedSlice();
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const monkeys = try parseInput(aa, input);
    print("{any}\n", .{monkeys});

    // for (0..20) |_| {
    //     for (monkeys) |*monkey| {
    //         monkey.inspect_items(monkeys);
    //     }
    // }

    return 0;
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
        \\Monkey 0:
        \\  Starting items: 79, 98
        \\  Operation: new = old * 19
        \\  Test: divisible by 23
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 3
        \\
        \\Monkey 1:
        \\  Starting items: 54, 65, 75, 74
        \\  Operation: new = old + 6
        \\  Test: divisible by 19
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 0
        \\
        \\Monkey 2:
        \\  Starting items: 79, 60, 97
        \\  Operation: new = old * old
        \\  Test: divisible by 13
        \\    If true: throw to monkey 1
        \\    If false: throw to monkey 3
        \\
        \\Monkey 3:
        \\  Starting items: 74
        \\  Operation: new = old + 3
        \\  Test: divisible by 17
        \\    If true: throw to monkey 0
        \\    If false: throw to monkey 1
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 10605), try process1(allocator, data));
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
