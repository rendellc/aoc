const std = @import("std");
const Allocator = @import("std").mem.Allocator;

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

const RPSResult = enum {
    Lose,
    Draw,
    Win,

    pub fn parse(char: u8) !RPSResult {
        switch (char) {
            'X' => return RPSResult.Lose,
            'Y' => return RPSResult.Draw,
            'Z' => return RPSResult.Win,
            else => return ProgramError.AnyError,
        }
    }

    pub fn score(self: RPSResult) i32 {
        switch (self) {
            RPSResult.Lose => return 0,
            RPSResult.Draw => return 3,
            RPSResult.Win => return 6,
        }
    }
};

const RPSHand = enum {
    R,
    P,
    S,

    pub fn parse(char: u8) !RPSHand {
        switch (char) {
            'A', 'X' => return RPSHand.R,
            'B', 'Y' => return RPSHand.P,
            'C', 'Z' => return RPSHand.S,
            else => return ProgramError.AnyError,
        }
    }

    pub fn handScore(self: RPSHand) i32 {
        return switch (self) {
            RPSHand.R => 1,
            RPSHand.P => 2,
            RPSHand.S => 3,
        };
    }

    pub fn play(self: RPSHand, other: RPSHand) RPSResult {
        if (self == other) {
            return RPSResult.Draw;
        }

        const is_loss: bool = (self == RPSHand.R and other == RPSHand.P) or
            (self == RPSHand.P and other == RPSHand.S) or
            (self == RPSHand.S and other == RPSHand.R);
        if (is_loss) {
            return RPSResult.Lose;
        }

        return RPSResult.Win;
    }

    pub fn playForOutcome(other: RPSHand, outcome: RPSResult) RPSHand {
        if (outcome == RPSResult.Draw) {
            return other;
        }

        if (outcome == RPSResult.Lose) {
            const move = switch (other) {
                RPSHand.R => RPSHand.S,
                RPSHand.P => RPSHand.R,
                RPSHand.S => RPSHand.P,
            };
            return move;
        }

        const move = switch (other) {
            RPSHand.R => RPSHand.P,
            RPSHand.P => RPSHand.S,
            RPSHand.S => RPSHand.R,
        };
        return move;
    }
};

pub fn process1(input: []const u8) !i32 {
    var lines = std.mem.split(u8, input, "\n");
    var score_total: i32 = 0;
    while (lines.next()) |line| {
        // std.debug.print("Line: {s} ({d})\n", .{ line, line.len });
        if (line.len < 3) {
            continue;
        }
        const opponent = try RPSHand.parse(line[0]);
        const me = try RPSHand.parse(line[2]);
        const play_score = me.handScore() + me.play(opponent).score();
        // std.debug.print("{c} {c}: {d} + {d} = {d}\n", .{ line[0], line[2], me.handScore(), me.play(opponent).score(), play_score });
        score_total += play_score;
    }

    return score_total;
}

pub fn process2(input: []const u8) !i32 {
    var lines = std.mem.split(u8, input, "\n");
    var score_total: i32 = 0;
    while (lines.next()) |line| {
        if (line.len < 3) {
            continue;
        }
        const opponent = try RPSHand.parse(line[0]);
        const outcome = try RPSResult.parse(line[2]);
        const me = RPSHand.playForOutcome(opponent, outcome);
        const play_score = me.handScore() + outcome.score();
        score_total += play_score;
    }

    return score_total;
}

test "simple 1" {
    const data =
        \\A Y
        \\B X
        \\C Z 
    ;

    try std.testing.expectEqual(@as(i32, 15), try process1(data));
}
test "simple 2" {
    const data =
        \\A Y
        \\B X
        \\C Z 
    ;

    try std.testing.expectEqual(@as(i32, 12), try process2(data));
}
