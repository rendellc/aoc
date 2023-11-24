const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const input = try file.readToEndAlloc(allocator, 60 * 1024 * 1024);

    const output1 = try process1(input);
    std.debug.print("Result 1: {d}\n", .{output1});

    const output2 = try process2(input);
    std.debug.print("Result 2: {d}\n", .{output2});
}

const ProgramError = error{
    AnyError,
};

const CharSet = std.bit_set.StaticBitSet(52);

fn getScore(char: u8) i32 {
    const index = getCharIndex(char);
    if (index == null) {
        return 0;
    }

    const signed_index: i32 = @intCast(index.?);
    const score = signed_index + 1;
    return score;
}

fn getCharIndex(char: u8) ?usize {
    if ('a' <= char and char <= 'z') {
        return @as(usize, char - 'a');
    }
    if ('A' <= char and char <= 'Z') {
        return 26 + @as(usize, char - 'A');
    }

    return null;
}

fn fromCharIndex(char_index: usize) ?u8 {
    if (char_index >= 52) {
        return null;
    }

    const index: u8 = @intCast(char_index);

    if (index < 26) {
        const offset: u8 = index;
        return 'a' + offset;
    } else if (index < 52) {
        const offset: u8 = index - 26;
        return 'A' + offset;
    }

    return null;
}

fn createCharSet(seq: []const u8) CharSet {
    var set = CharSet.initEmpty();
    for (seq) |char| {
        const index = getCharIndex(char);
        if (index != null) {
            set.set(index.?);
        }
    }

    return set;
}

pub fn charFromSet(set: CharSet) ?u8 {
    const char_index: ?usize = set.findFirstSet();
    if (char_index == null) {
        return null;
    }
    const char: ?u8 = fromCharIndex(char_index.?);
    return char;
}

pub fn findOverlappingChar(seq1: []const u8, seq2: []const u8) ?u8 {
    // std.debug.print("{s} ({d}) {s} ({d}): ", .{ seq1, seq1.len, seq2, seq2.len });
    const seq1_set = createCharSet(seq1);
    const seq2_set = createCharSet(seq2);
    const intersection = seq1_set.intersectWith(seq2_set);
    return charFromSet(intersection);
}

pub fn process1(input: []const u8) !i32 {
    var lines = std.mem.split(u8, input, "\n");
    var score_total: i32 = 0;
    while (lines.next()) |line| {
        const len = line.len;
        const seq1 = line[0 .. len / 2];
        const seq2 = line[len / 2 ..];
        const duplicate = findOverlappingChar(seq1, seq2);
        if (duplicate == null) {
            continue;
        }
        const duplicate_score = getScore(duplicate.?);
        // std.debug.print("{s}/{s} ({d}): {c} {d}\n", .{ seq1, seq2, len, duplicate.?, duplicate_score });
        score_total += duplicate_score;
    }
    return score_total;
}

pub fn process2(input: []const u8) !i32 {
    var lines = std.mem.split(u8, input, "\n");
    var score_total: i32 = 0;
    while (true) {
        const seq1 = lines.next();
        const seq2 = lines.next();
        const seq3 = lines.next();

        if (seq1 == null or seq2 == null or seq3 == null) {
            break;
        }

        const seq1_set = createCharSet(seq1.?);
        const seq2_set = createCharSet(seq2.?);
        const seq3_set = createCharSet(seq3.?);

        const intersection = seq1_set.intersectWith(seq2_set).intersectWith(seq3_set);
        const overlap = charFromSet(intersection);
        if (overlap == null) {
            continue;
        }

        const duplicate_score = getScore(overlap.?);
        score_total += duplicate_score;
    }
    return score_total;
}

test "fromCharIndex" {
    var char_index: usize = 0;
    var char: u8 = 'a';
    while (char_index < 26) {
        try std.testing.expectEqual(fromCharIndex(char_index).?, char);

        char_index += 1;
        char += 1;
    }

    char_index = 26;
    char = 'A';
    while (char_index < 52) {
        // std.debug.print("{c}: index: {d}\n", .{ char, char_index });
        try std.testing.expectEqual(fromCharIndex(char_index).?, char);

        char_index += 1;
        char += 1;
    }
}

test "easy 1" {
    const data =
        \\abcdaBCD
        \\abcdAbCD
    ;

    try std.testing.expectEqual(@as(i32, 1 + 2), try process1(data));
}
test "simple 1" {
    const data =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    try std.testing.expectEqual(@as(i32, 157), try process1(data));
}
test "simple 2" {
    const data =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    try std.testing.expectEqual(@as(i32, 70), try process2(data));
}
