const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("Open file\n", .{});
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    std.debug.print("Read file\n", .{});
    const input = try file.readToEndAlloc(allocator, 60 * 1024 * 1024);

    const output1 = try process1(input);
    std.debug.print("Result 1: {d}\n", .{output1});

    const output2 = try process2(input);
    std.debug.print("Result 2: {d}\n", .{output2});
}

const GroupSumsError = error{
    NoItems,
};

fn lessThan(lhs: i32, rhs: i32) bool {
    return lhs < rhs;
}

const GroupSums = struct {
    list: std.ArrayList(i32),

    pub fn init(allocator: Allocator) GroupSums {
        return GroupSums{
            .list = std.ArrayList(i32).init(allocator),
        };
    }
    pub fn deinit(self: GroupSums) void {
        self.list.deinit();
    }

    pub fn append(self: *GroupSums, item: i32) Allocator.Error!void {
        return self.list.append(item);
    }

    pub fn max(self: GroupSums) !i32 {
        if (self.list.items.len == 0) {
            return error.NoItems;
        }

        const sums = self.list.items;
        var max_sum: i32 = 0;
        for (sums) |sum| {
            if (sum > max_sum) {
                max_sum = sum;
            }
        }

        return max_sum;
    }

    pub fn sort(self: *GroupSums) void {
        // std.sort.insertion(i32, self.list.items, GroupSums, lessThan);
        std.sort.insertionContext(0, self.list.items.len, self);
    }

    pub fn swap(self: GroupSums, a: usize, b: usize) void {
        std.mem.swap(i32, &self.list.items[a], &self.list.items[b]);
    }

    pub fn lessThan(self: GroupSums, a: usize, b: usize) bool {
        return self.list.items[a] > self.list.items[b];
    }
};

pub fn process1(input: []const u8) !i32 {
    const allocator = std.heap.page_allocator;
    var lines = std.mem.split(u8, input, "\n");
    var group_sums = GroupSums.init(allocator);
    defer group_sums.deinit();

    var current_group_sum: i32 = 0;
    while (lines.next()) |line| {
        const line_value = std.fmt.parseInt(i32, line, 10) catch {
            try group_sums.append(current_group_sum);
            current_group_sum = 0;
            continue;
        };
        current_group_sum += line_value;
    }
    try group_sums.append(current_group_sum);

    return group_sums.max();
}

pub fn process2(input: []const u8) !i32 {
    const allocator = std.heap.page_allocator;
    var lines = std.mem.split(u8, input, "\n");
    var group_sums = GroupSums.init(allocator);
    defer group_sums.deinit();

    var current_group_sum: i32 = 0;
    while (lines.next()) |line| {
        const line_value = std.fmt.parseInt(i32, line, 10) catch {
            try group_sums.append(current_group_sum);
            current_group_sum = 0;
            continue;
        };
        current_group_sum += line_value;
    }
    try group_sums.append(current_group_sum);

    group_sums.sort();
    var top_sum: i32 = 0;
    for (0..3) |i| {
        top_sum += group_sums.list.items[i];
    }

    return top_sum;
}

test "simple 1" {
    const data =
        \\1000
        \\
        \\2000
        \\
        \\3000
        \\
        \\4000
        \\
        \\2500
    ;

    try std.testing.expectEqual(@as(i32, 4000), try process1(data));
}

test "simple 2" {
    const data =
        \\1000
        \\
        \\2000
        \\
        \\3000
        \\
        \\4000
        \\
        \\2500
    ;

    try std.testing.expectEqual(@as(i32, 9500), try process2(data));
}

test "test case" {
    const data =
        \\1000
        \\2000
        \\3000
        \\
        \\4000
        \\
        \\5000
        \\6000
        \\
        \\7000
        \\8000
        \\9000
        \\
        \\10000
    ;

    try std.testing.expectEqual(@as(i32, 24000), try process1(data));
    try std.testing.expectEqual(@as(i32, 45000), try process2(data));
}
