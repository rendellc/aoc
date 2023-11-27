const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const LineIterator = @import("./LineIterator.zig").LineIterator;
const ConsoleOutput = @import("./ConsoleOutput.zig").ConsoleOutput;
const FileSystemNode = @import("./FileSystemNode.zig").FileSystemNode;
const DirectoryIterator = @import("./Directory.zig").DirectoryIterator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const input = try file.readToEndAlloc(allocator, 60 * 1024 * 1024);
    defer allocator.free(input);
    std.debug.print("File size: {d}\n", .{input.len});

    const output1 = try process1(allocator, input);
    std.debug.print("Result 1: {d}\n", .{output1});

    const output2 = try process2(allocator, input);
    std.debug.print("Result 2: {d}\n", .{output2});
}

const ProgramError = error{
    AnyError,
};

pub fn process1(allocator: Allocator, input: []const u8) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const lines: LineIterator = std.mem.splitSequence(u8, input, "\n");
    const console_lines = try ConsoleOutput.parse_all(aa, lines);
    const fs = try FileSystemNode.parse(aa, console_lines.items);
    const alldirs = try fs.directory.list_subdirectories(aa);

    var size_sum: usize = 0;
    for (alldirs.items) |dir| {
        const size = dir.get_size_with_children();
        if (size < 100000) {
            size_sum += size;
        }
    }
    return size_sum;
}

pub fn process2(allocator: Allocator, input: []const u8) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const lines: LineIterator = std.mem.splitSequence(u8, input, "\n");
    const console_lines = try ConsoleOutput.parse_all(aa, lines);
    const fs = try FileSystemNode.parse(aa, console_lines.items);
    const alldirs = try fs.directory.list_subdirectories(aa);

    const total_space = 70 * 1000 * 1000;
    const used_space = fs.directory.get_size_with_children();
    std.debug.assert(total_space >= used_space);
    const free_space = total_space - used_space;
    const required_space = 30 * 1000 * 1000;
    const additional_free_space_needed = required_space - free_space;

    std.debug.print("Require {d} additional space\n", .{additional_free_space_needed});

    var smallest_delete_dir_size: usize = used_space;
    for (alldirs.items) |dir| {
        const size = dir.get_size_with_children();
        if (size >= additional_free_space_needed and size < smallest_delete_dir_size) {
            std.debug.print("Found {s} with size {d}\n", .{ dir.name, size });
            smallest_delete_dir_size = size;
        }
    }

    std.debug.assert(smallest_delete_dir_size >= additional_free_space_needed);

    return smallest_delete_dir_size;
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

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 95437), try process1(allocator, data));
}
