const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const FileSystemNode = @import("./FileSystemNode.zig").FileSystemNode;

pub const Directory = struct {
    name: []const u8,
    children: std.ArrayList(FileSystemNode),
    parent: ?*Directory,

    pub fn init(allocator: Allocator, parent: ?*Directory, name: []const u8) !*Directory {
        var d = try allocator.create(Directory);
        d.name = name;
        d.children = std.ArrayList(FileSystemNode).init(allocator);
        d.parent = parent;

        return d;
    }

    pub fn append(self: *Directory, node: FileSystemNode) !void {
        try self.children.append(node);
    }

    pub fn subdir(self: *Directory, name: []const u8) ?*Directory {
        for (self.children.items) |child| {
            switch (child) {
                .directory => |dirPtr| {
                    if (std.mem.eql(u8, dirPtr.*.name, name)) {
                        return dirPtr;
                    }
                },
                else => {},
            }
        }

        return null;
    }

    pub fn get_size_with_children(self: Directory) usize {
        var size: usize = 0;
        for (self.children.items) |child| {
            size += child.get_size_with_children();
        }
        return size;
    }

    pub fn list_subdirectories(self: *const Directory, allocator: Allocator) !std.ArrayList(*const Directory) {
        var list = std.ArrayList(*const Directory).init(allocator);

        try list.append(self);
        for (self.children.items) |node| {
            switch (node) {
                .directory => |dir| {
                    const subdirs = try dir.list_subdirectories(allocator);
                    try list.appendSlice(subdirs.items);
                    subdirs.deinit();
                },
                .file => {},
            }
        }

        return list;
    }
};
