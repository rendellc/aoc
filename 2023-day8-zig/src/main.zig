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

    try bw.flush();
}

const ProgramError = error{
    AnyError,
};

fn nodeId(name: []const u8) i64 {
    var id: i64 = 0;
    for (name) |c| {
        id = 30 * id + c - 'A';
    }
    // print("nodeId: {s} -> {d}\n", .{ name, id });
    return id;
}

fn isNodeIdFinal(id: i64) bool {
    // node = "XYZ"
    // node_id = 30*(30*'X' + 'Z') + 'Z'
    const is_final = @rem(id, 30) == @as(i64, @intCast('Z' - 'A'));
    // print("isFinal: {d} -> {any}\n", .{ id, is_final });
    return is_final;
}

const Move = enum {
    left,
    right,

    pub fn parse(allocator: Allocator, str: []const u8) ![]Move {
        var moves = std.ArrayList(Move).init(allocator);

        for (str) |c| {
            if (c == 'L') {
                try moves.append(Move.left);
            } else if (c == 'R') {
                try moves.append(Move.right);
            }
        }

        return try moves.toOwnedSlice();
    }
};

const TableLookup = struct {
    table: []i64,

    pub fn get(self: TableLookup, key: i64) ?i64 {
        const index = @as(usize, @intCast(key));
        std.debug.assert(index < self.table.len);
        return self.table[index];
    }

    pub fn put(self: *TableLookup, key: i64, value: i64) !void {
        const index = @as(usize, @intCast(key));
        std.debug.assert(index < self.table.len);

        self.table[index] = value;
    }

    pub fn init(allocator: Allocator) TableLookup {
        const table = allocator.alloc(i64, 30 * 30 * 30) catch unreachable;
        @memset(table, undefined);

        return .{
            .table = table,
        };
    }
};

fn lcm(p1: u64, p2: u64) u64 {
    return p1 * @divExact(p2, std.math.gcd(p1, p2));
}

const NodeMoves = struct {
    const IdLookup = TableLookup;
    // const IdLookup = std.AutoHashMap(i64, i64);

    starting_nodes: []const i64,
    left_nodes: IdLookup,
    right_nodes: IdLookup,

    pub fn getLeft(self: NodeMoves, id: i64) i64 {
        return self.left_nodes.get(id).?;
    }
    pub fn getRight(self: NodeMoves, id: i64) i64 {
        return self.right_nodes.get(id).?;
    }

    pub fn parse(allocator: Allocator, input: []const u8) !NodeMoves {
        var starting_nodes = std.ArrayList(i64).init(allocator);
        var left_nodes = IdLookup.init(allocator);
        var right_nodes = IdLookup.init(allocator);
        var lines = std.mem.splitScalar(u8, input, '\n');
        _ = lines.next();
        _ = lines.next();
        while (lines.next()) |line| {
            if (line.len == 0) continue;

            const id = nodeId(line[0..3]);
            const left_id = nodeId(line[7..10]);
            const right_id = nodeId(line[12..15]);

            if (line[2] == 'A') {
                try starting_nodes.append(id);
            }

            try left_nodes.put(id, left_id);
            try right_nodes.put(id, right_id);
        }

        return .{
            .starting_nodes = try starting_nodes.toOwnedSlice(),
            .left_nodes = left_nodes,
            .right_nodes = right_nodes,
        };
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var lines = std.mem.splitScalar(u8, input, '\n');
    const moves = try Move.parse(aa, lines.next().?);
    const node_moves = try NodeMoves.parse(aa, input);
    const target_node_id = nodeId("ZZZ");

    var node_id = nodeId("AAA");
    var move_counter: i64 = 0;
    while (node_id != target_node_id) {
        for (moves) |move| {
            move_counter += 1;
            switch (move) {
                .left => {
                    node_id = node_moves.getLeft(node_id);
                },
                .right => {
                    node_id = node_moves.getRight(node_id);
                },
            }
        }
    }

    return move_counter;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var lines = std.mem.splitScalar(u8, input, '\n');
    const moves = try Move.parse(aa, lines.next().?);
    const node_moves = try NodeMoves.parse(aa, input);
    const nodes = node_moves.starting_nodes;

    print("Starting nodes: {any}\n", .{nodes});
    const NodePeriod = struct {
        start_offset: i64 = 0,
        period: i64 = 1,
    };

    var periods = try aa.alloc(NodePeriod, nodes.len);
    @memset(periods, .{});

    for (nodes, 0..) |node, i| {
        var n = node;
        var move_counter: i64 = 0;
        var start_offset: ?i64 = null;
        var period: ?i64 = null;
        while (period == null) {
            for (moves) |move| {
                move_counter += 1;
                switch (move) {
                    .left => {
                        n = node_moves.getLeft(n);
                    },
                    .right => {
                        n = node_moves.getRight(n);
                    },
                }

                if (isNodeIdFinal(n)) {
                    if (start_offset == null) {
                        start_offset = move_counter;
                    } else {
                        period = move_counter - start_offset.?;
                        break;
                    }
                }
            }
        }

        periods[i].start_offset = start_offset.?;
        periods[i].period = period.?;

        print("Computed Period for node id {d}: {any}\n", .{ nodes[i], periods[i] });
    }

    var period_all: u64 = 1;
    for (periods) |p| {
        period_all = lcm(@intCast(period_all), @intCast(p.period));
    }

    return @intCast(period_all);
}

test "simple 1" {
    const data =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 2), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 6), try process1(allocator, data));
}

test "example part 2" {
    const data =
        \\LR
        \\
        \\AAA = (AAB, XXX)
        \\AAB = (XXX, AAZ)
        \\AAZ = (AAB, XXX)
        \\BBA = (BBB, XXX)
        \\BBB = (BBC, BBC)
        \\BBC = (BBZ, BBZ)
        \\BBZ = (BBB, BBB)
        \\XXX = (XXX, XXX)
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 6), try process2(allocator, data));
}

test "final check false" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(false, isNodeIdFinal(nodeId("AAA")));
    try expectEqual(false, isNodeIdFinal(nodeId("AZA")));
    try expectEqual(false, isNodeIdFinal(nodeId("ZBA")));
    try expectEqual(false, isNodeIdFinal(nodeId("ZBA")));
    try expectEqual(false, isNodeIdFinal(nodeId("LSF")));
}

test "final check true" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(true, isNodeIdFinal(nodeId("AAZ")));
    try expectEqual(true, isNodeIdFinal(nodeId("AZZ")));
    try expectEqual(true, isNodeIdFinal(nodeId("ZBZ")));
    try expectEqual(true, isNodeIdFinal(nodeId("ZBZ")));
    try expectEqual(true, isNodeIdFinal(nodeId("LSZ")));
}
