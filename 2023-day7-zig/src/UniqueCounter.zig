const std = @import("std");

pub fn UniqueCounter(comptime n: u8) type {
    return struct {
        const Self = @This();

        counters: [n]usize = undefined,

        pub fn init() Self {
            var s: Self = .{};
            @memset(&s.counters, 0);
            return s;
        }

        pub fn count(self: *Self, value: u8) void {
            if (value >= self.counters.len) {
                return;
            }

            self.counters[value] += 1;
        }

        pub fn countItems(self: *Self, items: []const u8) void {
            for (items) |item| {
                self.count(item);
            }
        }

        pub fn getCount(self: Self, value: u8) usize {
            if (value >= self.counters.len) {
                return 0;
            }

            return self.counters[value];
        }

        pub fn getMaxCount(self: Self) usize {
            var max = 0;
            for (self.counters) |value| {
                if (value > max) {
                    max = value;
                }
            }

            return max;
        }

        pub fn countWithCount(self: Self, desired_count: usize) usize {
            var counter: usize = 0;
            for (self.counters) |value| {
                if (value == desired_count) {
                    counter += 1;
                }
            }
            return counter;
        }
    };
}
