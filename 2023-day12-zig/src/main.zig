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

const RecordEntry = enum {
    operational,
    damaged,
};

//
//        for (0..total_number_of_arrangements) |arr| {
//
//            dprint("Checking arrangement: {d}/{d}: {any}\n", .{ arr + 1, total_number_of_arrangements, indices_to_damage });
//
//            // increment indices for next iteration, and handle overflow
//            indices_to_damage[0] += 1;
//            var potential_overflow: bool = true;
//            var unique_checker = std.DynamicBitSet.initEmpty(allocator, unknowns);
//            defer unique_checker.deinit();
//            while (potential_overflow) {
//                potential_overflow = false;
//                dprint("\t{any}\n", .{indices_to_damage});
//                for (0..indices_to_damage.len - 1) |i| {
//                    const max_index = @min(unknowns - 1 - i, indices_to_damage[i + 1] + 2);
//
//                    if (indices_to_damage[i] > max_index) {
//                        const overflow_trickle = indices_to_damage[i] - max_index;
//                        std.debug.assert(overflow_trickle == 1);
//                        if (indices_to_damage[i + 1] < max_index - 1) {
//                            indices_to_damage[i] = indices_to_damage[i + 1] + 2;
//                        } else {
//                            indices_to_damage[i] = max_index;
//                        }
//                        indices_to_damage[i + 1] += overflow_trickle;
//                        // dprint("\t{d}: {d}\n", .{ i, overflow_trickle });
//                        potential_overflow = true;
//                    }
//                }
//            }
//        }
const BaseNumber = struct {
    value: usize,
    base: usize,

    pub fn zero(base: usize) BaseNumber {
        return .{
            .value = 0,
            .base = base,
        };
    }

    pub fn getDigit(self: BaseNumber, i: usize) usize {
        // 1base^3 + 8base^2 + 9base^1 + 3base^0
        // i = 1
        const div = std.math.powi(usize, self.base, i) catch {
            return 0;
        };

        // 1base^3 + 8base^2 + 9
        return @mod(@divFloor(self.value, div), self.base);
    }
};
const IndexCombinations = struct {
    indices: []usize,
    max_index: usize,
    is_started: bool,

    pub fn init(allocator: Allocator, max_index: usize, number_of_indices: usize) !IndexCombinations {
        var indices = try allocator.alloc(usize, number_of_indices);
        @memset(indices[0..], 0);

        // const max_counter_value = try std.math.powi(usize, max_index + 1, indices.len);

        return .{
            .indices = indices,
            .max_index = max_index,
            // .max_counter_value = max_counter_value,
            // .counter = BaseNumber.zero(max_index + 1),
            .is_started = false,
        };
    }

    fn areDigitsDecreasing(self: IndexCombinations) bool {
        // Let digit i = di
        // true if d0 > d1 > d2 ...
        var prev: ?usize = null;
        for (0..self.indices.len) |i| {
            const di = self.counter.getDigit(i);
            if (prev != null) {
                if (prev.? <= di) {
                    return false;
                }
            }

            prev = di;
        }

        return true;
    }

    pub fn reset(self: *IndexCombinations) void {
        for (0..self.indices.len) |i| {
            self.indices[i] = self.indices.len - 1 - i;
        }
        self.is_started = false;
    }

    pub fn next(self: *IndexCombinations) ?[]usize {
        if (!self.is_started) {
            self.is_started = true;
            return self.indices;
        }

        //  4 3 2 1 0
        //  5 3 2 1 0
        //  6 3 2 1 0

        for (0..self.indices.len) |i| {
            const index = self.counter.getDigit(i);
            self.indices[i] = index;
        }

        // dprint("next: {any}\n", .{self.indices});

        return self.indices;
    }
};

fn factorial(x: usize) usize {
    if (x <= 1) {
        return 1;
    }
    return x * factorial(x - 1);
}

fn nCr(n: usize, r: usize) usize {
    std.debug.assert(r <= n);

    return @divExact(factorial(n), factorial(r) * factorial(n - r));
}

const Record = struct {
    entries: []RecordEntry,

    pub fn matchesGroupCount(self: Record, counts: []i64) bool {
        var damaged_groups = std.mem.tokenizeScalar(RecordEntry, self.entries, RecordEntry.operational);
        var i: usize = 0;
        while (damaged_groups.next()) |damaged_group| {
            if (i >= counts.len) {
                return false;
            }

            if (damaged_group.len != @as(usize, @intCast(counts[i]))) {
                return false;
            }

            i += 1;
        }

        return true;
    }
};

const DamagedRecord = struct {
    entries: []?RecordEntry,
    groups: []i64,

    pub fn parse(allocator: Allocator, line: []const u8) !DamagedRecord {
        const space_index = std.mem.indexOfScalar(u8, line, ' ').?;

        var entries = std.ArrayList(?RecordEntry).init(allocator);
        for (line[0..space_index]) |c| {
            if (c == '.') {
                try entries.append(RecordEntry.operational);
            } else if (c == '#') {
                try entries.append(RecordEntry.damaged);
            } else if (c == '?') {
                try entries.append(null);
            } else {
                dprint("Unexpected char in {s}\n", .{line});
                return ProgramError.AnyError;
            }
        }

        var group_strs = std.mem.splitScalar(u8, line[space_index + 1 ..], ',');
        var groups = std.ArrayList(i64).init(allocator);
        while (group_strs.next()) |group_str| {
            const group = try std.fmt.parseInt(i64, group_str, 10);
            try groups.append(group);
        }

        return .{
            .entries = try entries.toOwnedSlice(),
            .groups = try groups.toOwnedSlice(),
        };
    }

    pub fn getDamagedCount(self: DamagedRecord) usize {
        var count: usize = 0;
        for (self.groups) |g| {
            count += @intCast(g);
        }
        return count;
    }

    pub fn countEntries(self: DamagedRecord, entry: ?RecordEntry) usize {
        const count = std.mem.count(?RecordEntry, self.entries, &[1]?RecordEntry{entry});
        return count;
    }

    pub fn createComplete(self: DamagedRecord, allocator: Allocator, values: []RecordEntry) !Record {
        var entries = try allocator.alloc(RecordEntry, self.entries.len);
        var insert_i: usize = 0;
        for (0..entries.len) |i| {
            if (self.entries[i] != null) {
                entries[i] = self.entries[i].?;
            } else {
                entries[i] = values[insert_i];
                insert_i += 1;
            }
        }
        return .{
            .entries = entries,
        };
    }

    pub fn countNumberOfPossibleArrangements(self: DamagedRecord, allocator: Allocator) !usize {
        const unknowns = self.countEntries(null);
        const damaged = self.countEntries(RecordEntry.damaged);
        const required_damage_count = self.getDamagedCount();
        const damaged_to_insert = required_damage_count - damaged;

        const total_number_of_arrangements = nCr(unknowns, damaged_to_insert);
        dprint("Total number of arrangements: {d} ({d}, {d})\n", .{ total_number_of_arrangements, unknowns, damaged_to_insert });

        var index_combinations = try IndexCombinations.init(allocator, unknowns - 1, damaged_to_insert);

        var entries = try allocator.alloc(RecordEntry, unknowns);
        defer allocator.free(entries);
        var number_of_matching_entries: usize = 0;
        var arrangement_counter: usize = 0;
        while (index_combinations.next()) |indices_to_damage| {
            arrangement_counter += 1;
            @memset(entries, RecordEntry.operational);
            for (indices_to_damage) |i| {
                entries[i] = RecordEntry.damaged;
            }

            const completed_record = try self.createComplete(allocator, entries);
            const is_match = completed_record.matchesGroupCount(self.groups);
            if (is_match) {
                number_of_matching_entries += 1;
            }
        }

        dprint("Number of valid arrangements: {d}\n", .{number_of_matching_entries});
        return number_of_matching_entries;
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var arrangement_sum: usize = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        dprint("Damaged record: {s}\n", .{line});
        const record = try DamagedRecord.parse(aa, line);
        const count = try record.countNumberOfPossibleArrangements(aa);
        arrangement_sum += count;
    }

    return @intCast(arrangement_sum);
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    _ = input;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    return 0;
}

test "simple 1 : individual cases" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 1), try process1(allocator, "???.### 1,1,3"));
    try std.testing.expectEqual(@as(i64, 4), try process1(allocator, ".??..??...?##. 1,1,3"));
    try std.testing.expectEqual(@as(i64, 1), try process1(allocator, "?#?#?#?#?#?#?#? 1,3,1,6"));
    try std.testing.expectEqual(@as(i64, 1), try process1(allocator, "????.#...#... 4,1,1"));
    try std.testing.expectEqual(@as(i64, 4), try process1(allocator, "????.######..#####. 1,6,5"));
    try std.testing.expectEqual(@as(i64, 10), try process1(allocator, "?###???????? 3,2,1"));
}

test "simple 1" {
    const data =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 21), try process1(allocator, data));
}
