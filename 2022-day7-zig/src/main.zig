const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const LineIterator = std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence);

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

const File = struct { name: []const u8, size: usize };
const Directory = struct {
    name: []const u8,
    children: std.ArrayList(FileSystemNode),

    pub fn deinit(self: *Directory) void {
        self.children.deinit();
    }
};

const CommandCD = struct {
    target: []const u8,
};
const CommandLS = void;
const ReplyDir = struct {
    name: []const u8,
};
const ReplyFile = struct {
    name: []const u8,
    size: usize,
};

const ConsoleOutput = union(enum) {
    cd: CommandCD,
    ls: CommandLS,
    dir: ReplyDir,
    file: ReplyFile,

    pub fn parse(line: []const u8) !ConsoleOutput {
        if (line[0] == '$') {
            if (line[2] == 'c') {
                const target = line[4..];
                return ConsoleOutput{ .cd = CommandCD{
                    .target = target,
                } };
            }
            if (line[2] == 'l') {
                return ConsoleOutput{ .ls = CommandLS{} };
            }
        } else {
            if (line[0] == 'd') {
                // assume its a dir in the form "dir kfalksa"
                const name = line[4..];
                return ConsoleOutput{ .dir = ReplyDir{
                    .name = name,
                } };
            }

            // assume its a file int the form "123124 asdfskd.txt"
            var words = std.mem.split(u8, line, " ");
            const size_str = words.next();
            const name = words.next();
            if (size_str == null or name == null) {
                return ProgramError.AnyError;
            }
            const size = try std.fmt.parseInt(usize, size_str.?, 10);

            return ConsoleOutput{ .file = ReplyFile{
                .name = name.?,
                .size = size,
            } };
        }

        return ProgramError.AnyError;
    }

    pub fn parse_all(lines: LineIterator, allocator: Allocator) !std.ArrayList(ConsoleOutput) {
        var lines_mut = lines;
        var console_lines = std.ArrayList(ConsoleOutput).init(allocator);

        while (lines_mut.next()) |line| {
            const output = try ConsoleOutput.parse(line);
            try console_lines.append(output);
        }

        return console_lines;
    }
};

const FileSystemNode = union(enum) {
    directory: Directory,
    file: File,

    fn is_command(line: []const u8) bool {
        if (line.len > 0 and line[0] == '$') {
            return true;
        }
        return false;
    }

    pub fn parse(lines: LineIterator, allocator: Allocator) !FileSystemNode {
        _ = allocator;
        _ = lines;
        // var root: ?FileSystemNode = null;
        // var current_directory: ?FileSystemNode = null;

        //         if (root == null) {
        //             root = FileSystemNode{
        //                 .directory = Directory{
        //                     .name=name,
        //                     .children=std.ArrayList(FilesystemNode).init(allocator),
        //                 },
        //             };
        //         }

        //     }
        // }
        return ProgramError.AnyError;
    }

    pub fn deinit(self: FileSystemNode) void {
        switch (self) {
            .directory => |*directory| {
                for (directory) |*d| {
                    d.children.deinit();
                }
            },
            .file => {},
        }
    }

    pub fn get_node_size(node: FileSystemNode) usize {
        switch (node) {
            .directory => return 0,
            .file => |file| return file.size,
        }
    }

    pub fn get_size_with_children(node: FileSystemNode) usize {
        _ = node;
        return 0;
    }
};

pub fn process1(input: []const u8) !usize {
    const allocator = std.heap.page_allocator;

    const lines: LineIterator = std.mem.split(u8, input, "\n");
    const console_lines = try ConsoleOutput.parse_all(lines, allocator);
    defer console_lines.deinit();

    for (console_lines.items) |console_line| {
        switch (console_line) {
            .cd => |cd| std.debug.print("cd: {s}\n", .{cd.target}),
            .ls => std.debug.print("ls:\n", .{}),
            .dir => |dir| std.debug.print("dir: {s}\n", .{dir.name}),
            .file => |file| std.debug.print("file: {s} {d}\n", .{ file.name, file.size }),
        }
    }

    //const root = try FileSystemNode.parse(lines);
    //defer root.deinit();

    //return root.get_size_with_children();
    return ProgramError.AnyError;
}

pub fn process2(input: []const u8) !usize {
    _ = input;
    return 0;
}

test "simple 1" {
    const data =
        \\$ cd /
        \\$ ls
        \\dir a
        \\14848514 b.txt
        \\8504156 c.dat
        \\dir d
        \\$ cd a
        \\$ ls
        \\dir e
        \\29116 f
        \\2557 g
        \\62596 h.lst
        \\$ cd e
        \\$ ls
        \\584 i
        \\$ cd ..
        \\$ cd ..
        \\$ cd d
        \\$ ls
        \\4060174 j
        \\8033020 d.log
        \\5626152 d.ext
        \\7214296 k
    ;

    try std.testing.expectEqual(@as(usize, 95437), try process1(data));
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
    _ = data;

    // try std.testing.expectEqual(@as(usize, 70), try process2(data));
}
