const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Directory = @import("./Directory.zig").Directory;
const File = @import("./File.zig").File;
const ConsoleOutput = @import("./ConsoleOutput.zig").ConsoleOutput;

pub const FileSystemNode = union(enum) {
    directory: *Directory,
    file: *File,

    pub fn parse(allocator: Allocator, console_lines: []const ConsoleOutput) !FileSystemNode {
        var root: ?*Directory = null;
        var current_directory: ?*Directory = null;
        for (console_lines) |console_line| {
            switch (console_line) {
                .cd => |cd| {
                    switch (cd.target) {
                        .relative => |target| {
                            // std.debug.print("cd: (relative) {s}\n", .{target});
                            if (std.mem.eql(u8, target, "..")) {
                                current_directory = current_directory.?.*.parent;
                                std.debug.assert(current_directory != null);
                            } else {
                                // std.debug.print("cd: (relative,target) {s}\n", .{target});
                                current_directory = current_directory.?.subdir(target);
                                std.debug.assert(current_directory != null);
                            }
                        },
                        .absolute => |target| {
                            std.debug.assert(root == null);
                            // std.debug.print("cd: (absolute) {s}\n", .{target});
                            root = try Directory.init(allocator, null, target);
                            current_directory = root;
                        },
                    }
                },
                .ls => {
                    // Nothing to do here, add the next replies to current_directory
                    std.debug.assert(current_directory != null);
                },
                .dir => |dir| {
                    // Add dir to current directory
                    // std.debug.print("reply dir: {s}\n", .{dir.name});
                    std.debug.assert(current_directory != null);
                    try current_directory.?.append(FileSystemNode{
                        .directory = try Directory.init(allocator, current_directory, dir.name),
                    });
                },
                .file => |file| {
                    // Add files to current directory
                    // std.debug.print("reply file: {s} {d}\n", .{ file.name, file.size });
                    std.debug.assert(current_directory != null);
                    try current_directory.?.append(FileSystemNode{
                        .file = try File.init(allocator, file.name, file.size),
                    });
                },
            }
        }

        return FileSystemNode{
            .directory = root.?,
        };
    }

    pub fn get_size_with_children(self: FileSystemNode) usize {
        switch (self) {
            .directory => |dir| return dir.get_size_with_children(),
            .file => |file| return file.size,
        }

        return 0;
    }
};
