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

    const output2 = try process2(allocator, input);
    try stdout.print("Result 2: {d}\n", .{output2});

    try bw.flush(); // don't forget to flush!
}

const ProgramError = error{
    AnyError,
};

const Reveal = struct {
    r: i64 = 0,
    g: i64 = 0,
    b: i64 = 0,

    pub fn parse(str: []const u8) !Reveal {
        // parse string in form ' 6 red, 1 blue'
        var reveal: Reveal = .{};
        var colors = std.mem.splitSequence(u8, str[1..], ", ");
        while (colors.next()) |color_str| {
            const space_index = std.mem.indexOfScalar(u8, color_str, ' ').?;
            const color_count = try std.fmt.parseInt(i64, color_str[0..space_index], 10);
            switch (color_str[space_index + 1]) {
                'r' => {
                    reveal.r = color_count;
                },
                'g' => {
                    reveal.g = color_count;
                },
                'b' => {
                    reveal.b = color_count;
                },
                else => {
                    return ProgramError.AnyError;
                },
            }
        }

        return reveal;
    }
};

const Game = struct {
    id: i64,
    reveals: std.ArrayList(Reveal),

    pub fn parse(allocator: Allocator, str: []const u8) !Game {
        var parts = std.mem.splitScalar(u8, str, ':');
        const id_str = parts.next().?;
        const id = try std.fmt.parseInt(i64, id_str[5..], 10);

        var reveals = std.ArrayList(Reveal).init(allocator);
        const reveals_str = parts.next().?;
        var reveal_strs = std.mem.splitScalar(u8, reveals_str, ';');
        while (reveal_strs.next()) |reveal_str| {
            const reveal = try Reveal.parse(reveal_str);
            try reveals.append(reveal);
        }

        return .{
            .id = id,
            .reveals = reveals,
        };
    }

    pub fn deinit(self: *Game) void {
        self.reveals.deinit();
    }

    pub fn compute_power(self: Game) i64 {
        var minimum_red: i64 = 0;
        var minimum_green: i64 = 0;
        var minimum_blue: i64 = 0;

        for (self.reveals.items) |reveal| {
            if (reveal.r > minimum_red) {
                minimum_red = reveal.r;
            }
            if (reveal.g > minimum_green) {
                minimum_green = reveal.g;
            }
            if (reveal.b > minimum_blue) {
                minimum_blue = reveal.b;
            }
        }

        const power = minimum_red * minimum_green * minimum_blue;
        return power;
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    var games = std.ArrayList(Game).init(aa);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        // std.debug.print("Line: '{s}'\n", .{line});
        if (line.len == 0) {
            continue;
        }

        try games.append(try Game.parse(aa, line));
        // std.debug.print("Game '{any}'\n", .{game});
    }

    const max_red = 12;
    const max_green = 13;
    const max_blue = 14;

    var valid_game_id_sum: i64 = 0;
    outer: for (games.items) |game| {
        for (game.reveals.items) |reveal| {
            if (reveal.r > max_red) {
                continue :outer;
            }
            if (reveal.g > max_green) {
                continue :outer;
            }
            if (reveal.b > max_blue) {
                continue :outer;
            }
        }

        valid_game_id_sum += game.id;
    }

    return valid_game_id_sum;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    var games = std.ArrayList(Game).init(aa);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        std.debug.print("Line: '{s}'\n", .{line});
        if (line.len == 0) {
            continue;
        }

        try games.append(try Game.parse(aa, line));
        // std.debug.print("Game '{any}'\n", .{game});
    }

    var power_sum: i64 = 0;
    for (games.items) |game| {
        power_sum += game.compute_power();
    }

    return power_sum;
}

test "simple 1" {
    const data =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 8), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 2286), try process2(allocator, data));
}
