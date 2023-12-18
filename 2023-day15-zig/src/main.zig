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

fn computeHash(str: []const u8) u8 {
    var x: u8 = 0;

    for (str) |c| {
        if (c == '\n') {
            continue;
        }
        x +%= c;
        x *%= 17;

        // dont need this, because it already captured by u8 data type
        // x = @rem(x, 256);
    }

    return x;
}

const Op = enum { remove, modify };
const Operation = union(Op) {
    remove: void,
    modify: u8,

    pub fn fromStr(str: []const u8) !Operation {
        const op_index = std.mem.indexOfAny(u8, str, "-=");
        if (op_index == null) {
            return ProgramError.AnyError;
        }

        const op_char = str[op_index.?];
        if (op_char == '-') {
            return Operation.remove;
        }

        dprint("Parsing: {s} {c} {?}\n", .{ str, op_char, op_index });
        const value = try std.fmt.parseInt(u8, str[op_index.? + 1 ..], 10);
        return Operation{ .modify = value };
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    var sequence = std.mem.splitScalar(u8, input, ',');
    var hash_sum: i64 = 0;
    while (sequence.next()) |str| {
        if (str.len == 0) continue;

        const hash = computeHash(str);

        dprint("'{s}' becomes {d}\n", .{ str, hash });
        hash_sum += hash;
    }

    return hash_sum;
}

const BoxContent = struct {
    label: []const u8,
    value: u8,
};

const Box = struct {
    number: u8,
    contents: std.ArrayList(BoxContent),

    pub fn init(allocator: Allocator, number: u8) Box {
        return .{
            .number = number,
            .contents = std.ArrayList(BoxContent).init(allocator),
        };
    }

    fn findIndexByLabel(self: Box, label: []const u8) ?usize {
        var index: ?usize = null;
        for (self.contents.items, 0..) |bc, i| {
            if (std.mem.eql(u8, bc.label, label)) {
                index = i;
                break;
            }
        }

        return index;
    }

    pub fn remove(self: *Box, label: []const u8) void {
        const index = self.findIndexByLabel(label);
        if (index != null) {
            _ = self.contents.orderedRemove(index.?);
        }
    }

    pub fn modify(self: *Box, label: []const u8, value: u8) void {
        const index = self.findIndexByLabel(label);
        if (index != null) {
            const i = index.?;
            self.contents.items[i].value = value;
        } else {
            self.contents.append(BoxContent{
                .label = label,
                .value = value,
            }) catch unreachable;
        }
    }
};

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var boxes = std.ArrayList(Box).init(aa);
    for (0..256) |i| {
        try boxes.append(Box.init(aa, @intCast(i)));
    }

    // remove final newline
    var _input = input;
    if (input[input.len - 1] == '\n') {
        _input = _input[0 .. input.len - 1];
    }

    var sequence = std.mem.splitScalar(u8, _input, ',');
    while (sequence.next()) |str| {
        if (str.len == 0) continue;

        const op_index = std.mem.indexOfAny(u8, str, "-=").?;
        const label = str[0..op_index];
        const box_index = computeHash(label);

        const op = try Operation.fromStr(str);

        dprint("Box: {d}, label: '{s}', operation: {any}\n", .{ box_index, label, op });
        switch (op) {
            .remove => {
                boxes.items[box_index].remove(label);
            },
            .modify => |value| {
                boxes.items[box_index].modify(label, value);
            },
        }
    }

    var score: usize = 0;
    for (boxes.items) |box| {
        const number = @as(usize, box.number) + 1;
        for (box.contents.items, 1..) |box_content, slot| {
            dprint("{s}: {d} * {d} * {d}\n", .{ box_content.label, number, slot, box_content.value });
            score += number * slot * box_content.value;
        }
    }

    return @intCast(score);
}

test "simple 1: hash" {
    try std.testing.expectEqual(@as(i64, 52), computeHash("HASH"));
}

test "simple 1" {
    const data = "rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7";

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 1320), try process1(allocator, data));
}

test "simple 2" {
    const data = "rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7";

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 145), try process2(allocator, data));
}
