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

    const output2 = try process2_naive(allocator, input);
    try stdout.print("Result 2: {d}\n", .{output2});

    try bw.flush(); // don't forget to flush!
}

const ProgramError = error{
    AnyError,
};

const Range = struct {
    start: i64,
    length: usize,

    pub fn getStart(self: Range) i64 {
        return self.start;
    }
    pub fn getStop(self: Range) i64 {
        return self.start + @as(i64, @intCast(self.length)) - 1;
    }
};

const RangeMap = struct {
    dest_start: i64,
    src_start: i64,
    length: i64,

    pub fn parse(line: []const u8) !RangeMap {
        var num_strs = std.mem.tokenizeScalar(u8, line, ' ');
        const dest_start = try std.fmt.parseInt(i64, num_strs.next().?, 10);
        const src_start = try std.fmt.parseInt(i64, num_strs.next().?, 10);
        const length = try std.fmt.parseInt(i64, num_strs.next().?, 10);

        return .{
            .dest_start = dest_start,
            .src_start = src_start,
            .length = length,
        };
    }

    pub fn contains_src(self: RangeMap, value: i64) bool {
        if (self.src_start <= value and value < self.src_start + self.length) {
            return true;
        }

        return false;
    }

    pub fn map_src(self: RangeMap, value: i64) i64 {
        std.debug.assert(value >= self.src_start);
        std.debug.assert(value < self.src_start + self.length);
        const offset = value - self.src_start;
        return self.dest_start + offset;
    }
};

const Map = struct {
    src: []const u8,
    dest: []const u8,
    range_maps: std.ArrayList(RangeMap),

    pub fn init(allocator: Allocator, str: []const u8) !Map {

        // water-to-light map:
        const space_index = std.mem.indexOfScalar(u8, str, ' ').?;
        var map_srcdest_iter = std.mem.splitSequence(u8, str[0..space_index], "-to-");
        const src = map_srcdest_iter.next().?;
        const dest = map_srcdest_iter.next().?;

        var lines = std.mem.splitScalar(u8, str, '\n');
        _ = lines.next(); // skip src-to-dest map line
        var range_maps = std.ArrayList(RangeMap).init(allocator);
        while (lines.next()) |line| {
            if (line.len == 0) {
                continue;
            }
            try range_maps.append(try RangeMap.parse(line));
        }

        return .{
            .src = src,
            .dest = dest,
            .range_maps = range_maps,
        };
    }
    pub fn deinit(self: *Map) void {
        self.range_maps.deinit();
    }

    pub fn map_src(self: Map, value: i64) i64 {
        for (self.range_maps.items) |range| {
            if (range.contains_src(value)) {
                // std.debug.print("{d} is mapped by {s}-to-{s}: {any}\n", .{ value, self.src, self.dest, range });
                return range.map_src(value);
            }
        }
        return value;
    }

    pub fn map_range(self: Map, allocator: Allocator, range: Range) ![]Range {
        _ = range;
        var result_ranges = std.ArrayList(Range).init(allocator);

        for (self.range_maps.items) |range_map| {
            _ = range_map;
            // 6 cases
            // 1. range < range_map
            // 2. range.start < range_map, range.stop in range_map
            // 3. range.start in range_map, range.stop > range_map
            // 4. range > range_map
            // 5. range is entirely contained by range_map
            //    range_map.start <= range.start and range.stop <= range_map.stop
            // 6. range contains range_map
            //    range.start <= range_map.start and range_map.stop <= range.stop
            //
            // 1 and 4 are similar, range is unaffected by map, can return range
            // 5 is simple, return the mapped range
            // 2,3,and 6 will need creation of new ranges

        }

        return try result_ranges.toOwnedSlice();
    }
};

fn parseSeeds(allocator: Allocator, input: []const u8) ![]i64 {
    const newline_index = std.mem.indexOfScalar(u8, input, '\n').?;
    var numbers = std.mem.tokenizeScalar(u8, input[6..newline_index], ' ');

    var seeds = std.ArrayList(i64).init(allocator);
    while (numbers.next()) |number_str| {
        try seeds.append(try std.fmt.parseInt(i64, number_str, 10));
    }

    return try seeds.toOwnedSlice();
}

fn parseSeedRanges(allocator: Allocator, input: []const u8) ![]Range {
    const newline_index = std.mem.indexOfScalar(u8, input, '\n').?;
    var numbers = std.mem.tokenizeScalar(u8, input[6..newline_index], ' ');

    var ranges = std.ArrayList(Range).init(allocator);
    while (numbers.peek()) |_| {
        const start = try std.fmt.parseInt(i64, numbers.next().?, 10);
        const length = try std.fmt.parseInt(usize, numbers.next().?, 10);

        try ranges.append(.{ .start = start, .length = length });
    }

    return try ranges.toOwnedSlice();
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const seeds = try parseSeeds(aa, input);
    const maps = try parseMaps(aa, input);

    // std.debug.print("{any}\n", .{maps.items[0]});

    // note that maps are in sequences so
    // map[0] -> map[1] -> map[2] ...
    // can ignore src and dest names and just work with indices
    var values = try aa.alloc(i64, seeds.len);
    @memcpy(values, seeds);
    for (0..values.len) |i| {
        // std.debug.print("Mappings for {d}\n", .{values[i]});
        for (maps) |map| {
            values[i] = map.map_src(values[i]);

            // std.debug.print("\tMapped {d} -> {d}\n", .{ pre, values[i] });
        }
    }

    // std.debug.print("Locations: {any}\n", .{values});
    const index_of_min = std.mem.indexOfMin(i64, values);
    //const seed_min = seeds[index_of_min];
    const location_min = values[index_of_min];
    return location_min;
}

fn parseMaps(allocator: Allocator, input: []const u8) ![]Map {
    var blocks = std.mem.splitSequence(u8, input, "\n\n");
    _ = blocks.next().?; // skip seed line
    var maps = std.ArrayList(Map).init(allocator);
    while (blocks.next()) |block| {
        try maps.append(try Map.init(allocator, block));
    }

    return try maps.toOwnedSlice();
}

fn process2_naive(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const seed_ranges = try parseSeedRanges(aa, input);

    const maps = try parseMaps(aa, input);

    var lowest_location_seed: ?i64 = null;
    var lowest_location: ?i64 = null;

    for (seed_ranges) |seed_range| {
        std.debug.print("Checking seed range {d} {d}\n", .{ seed_range.getStart(), seed_range.getStop() });
        const seed_start: usize = @intCast(seed_range.getStart());
        const seed_stop: usize = @intCast(seed_range.getStop());
        for (seed_start..seed_stop + 1) |seed| {
            var value: i64 = @intCast(seed);
            for (maps) |map| {
                value = map.map_src(value);
            }
            const seed_location = value;

            if (lowest_location == null) {
                lowest_location = seed_location;
                lowest_location_seed = @intCast(seed);
            }

            if (seed_location < lowest_location.?) {
                lowest_location = seed_location;
                lowest_location_seed = @intCast(seed);
            }
        }
    }

    return lowest_location.?;
}

// fn process2(allocator: Allocator, input: []const u8) !i64 {
//     var arena = std.heap.ArenaAllocator.init(allocator);
//     defer arena.deinit();
//     const aa = arena.allocator();
//
//     const seed_ranges = try parseSeedRanges(aa, input);
//
//     const maps = try parseMaps(aa, input);
//
//     var lowest_location_seed_range: ?Range = null;
//     var lowest_location: ?i64 = null;
//     var value_ranges = std.ArrayList(Range).init(aa);
//     var new_value_ranges = std.ArrayList(Range).init(aa);
//
//     for (seed_ranges) |seed_range| {
//         value_ranges.resize(0);
//         try value_ranges.append(seed_range);
//         for (maps) |map| {
//             new_value_ranges.resize(0);
//             for (value_ranges.items) |range| {
//                 const mapped_ranges = try map.map_range(range);
//                 new_value_ranges.appendSlice(mapped_ranges);
//             }
//
//             value_ranges.resize(0);
//             value_ranges.appendSlice(new_value_ranges);
//         }
//
//         // After going through all the mappings for seed_range
//         // value_ranges contains the relevant location ranges
//         // that we can end up in
//         for (value_ranges.items) |location_range| {
//             if (lowest_location and location_range.getStart() < lowest_location.?) {
//                 lowest_location_seed_range = seed_range;
//                 lowest_location = location_range.getStart();
//             }
//
//             if (lowest_location and location_range.getStop() < lowest_location.?) {
//                 lowest_location_seed_range = seed_range;
//                 lowest_location = location_range.getStop();
//             }
//         }
//     }
//
//     std.debug.print("Lowest location seed range: {d}\n", .{lowest_location_seed_range.?});
//     std.debug.print("Lowest location: {d}\n", .{lowest_location});
//
//     return 0;
// }

test "simple 1" {
    const data =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 35), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 46), try process2_naive(allocator, data));
}
