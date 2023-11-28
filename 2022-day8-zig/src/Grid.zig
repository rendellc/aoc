const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const GridError = error{
    IndexOutOfBounds,
};

pub fn Grid(comptime T: type) type {
    return struct {
        // Grid data
        grid_data: []T,

        // Width/Length of each side
        length: usize,

        const Self = @This();

        fn toIndex(self: Self, x: usize, y: usize) !usize {
            if (y >= self.length or x >= self.length) {
                return GridError.IndexOutOfBounds;
            }

            const i = x + y * self.length;
            return i;
        }

        pub fn set(self: *Self, x: usize, y: usize, value: T) !void {
            const i = try self.toIndex(x, y);
            self.grid_data[i] = value;
        }

        pub fn get(self: Self, x: usize, y: usize) !T {
            const i = try self.toIndex(x, y);
            return self.grid_data[i];
        }

        pub fn init(allocator: Allocator, length: usize, default: T) !Grid(T) {
            const data = try allocator.alloc(T, length * length);
            @memset(data, default);

            return .{
                .length = length,
                .grid_data = data,
            };
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.grid_data);
        }
    };
}
