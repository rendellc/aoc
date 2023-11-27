const Allocator = @import("std").mem.Allocator;
const Directory = @import("./Directory.zig").Directory;

pub const File = struct {
    name: []const u8,
    size: usize,

    pub fn init(allocator: Allocator, name: []const u8, size: usize) !*File {
        const file = try allocator.create(File);
        file.* = .{
            .name = name,
            .size = size,
        };

        return file;
    }
};
