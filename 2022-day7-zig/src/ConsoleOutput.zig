const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const LineIterator = @import("./LineIterator.zig").LineIterator;

const Error = error{InvalidInput};

const CDTarget = union(enum) {
    relative: []const u8,
    absolute: []const u8,
};

const CommandCD = struct {
    target: CDTarget,
};
const CommandLS = void;
const ReplyDir = struct {
    name: []const u8,
};
const ReplyFile = struct {
    name: []const u8,
    size: usize,
};

pub const ConsoleOutput = union(enum) {
    cd: CommandCD,
    ls: CommandLS,
    dir: ReplyDir,
    file: ReplyFile,

    pub fn parse(line: []const u8) !ConsoleOutput {
        if (line[0] == '$') {
            if (line[2] == 'c') {
                const target = line[5..];
                if (target[0] == '/') {
                    return ConsoleOutput{ .cd = CommandCD{
                        .target = CDTarget{
                            .absolute = target,
                        },
                    } };
                } else {
                    return ConsoleOutput{ .cd = CommandCD{
                        .target = CDTarget{
                            .relative = target,
                        },
                    } };
                }
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
                return Error.InvalidInput;
            }
            const size = try std.fmt.parseInt(usize, size_str.?, 10);

            return ConsoleOutput{ .file = ReplyFile{
                .name = name.?,
                .size = size,
            } };
        }

        return Error.InvalidInput;
    }

    pub fn parse_all(allocator: Allocator, lines: LineIterator) !std.ArrayList(ConsoleOutput) {
        var lines_mut = lines;
        var console_lines = std.ArrayList(ConsoleOutput).init(allocator);

        while (lines_mut.next()) |line| {
            if (line.len == 0) {
                continue;
            }
            const output = try ConsoleOutput.parse(line);
            try console_lines.append(output);
        }

        return console_lines;
    }
};
