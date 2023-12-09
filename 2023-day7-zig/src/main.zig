const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const UniqueCounter = @import("./UniqueCounter.zig").UniqueCounter;

const CardCounter = UniqueCounter(13);

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

    // const output1 = try process1(allocator, input);
    // try stdout.print("Result 1: {d}\n", .{output1});

    const output2 = try process2(allocator, input);
    try stdout.print("Result 2: {d}\n", .{output2});

    try bw.flush();
}

const ProgramError = error{
    AnyError,
};

const Card = struct {
    index: u8,

    pub fn getJokerIndex() u8 {
        return 9;
    }

    pub fn isJoker(self: Card) bool {
        return self.index == Card.getJokerIndex();
    }

    pub fn fromChar(char: u8) !Card {
        const index: u8 = switch (char) {
            '2' => 0,
            '3' => 1,
            '4' => 2,
            '5' => 3,
            '6' => 4,
            '7' => 5,
            '8' => 6,
            '9' => 7,
            'T' => 8,
            'J' => 9,
            'Q' => 10,
            'K' => 11,
            'A' => 12,
            else => return ProgramError.AnyError,
        };

        return Card{ .index = index };
    }
};

const Hand = struct {
    cards: [5]Card,
    str: []const u8,
    bid: i64,
    score: u64,
    joker_mode: bool,

    fn cardScore(self: Hand, card: Card) u64 {
        if (self.joker_mode and card.isJoker()) {
            return 0;
        }

        return card.index + 1;
    }

    fn computeScore(self: Hand) u64 {
        var hand_score: u64 = 0;

        const counter = self.countUnique();

        const num_jokers = if (self.joker_mode)
            counter.getCount(Card.getJokerIndex())
        else
            0;

        // Add most significant score first
        const has_five = counter.countWithCount(5) == 1;
        const has_four = counter.countWithCount(4) == 1;
        const has_three = counter.countWithCount(3) > 0;
        const has_two_pairs = counter.countWithCount(2) >= 2;
        const has_pair = counter.countWithCount(2) == 1;
        const has_house = has_pair and has_three;

        if (has_five or (has_four and num_jokers == 1) or (has_three and num_jokers == 2) or (has_pair and num_jokers == 3) or (num_jokers == 4)) {
            hand_score += 32;
        } else if (has_four or (has_three and num_jokers == 1) or (has_two_pairs and num_jokers == 2) or (num_jokers == 3)) {
            hand_score += 16;
        } else if (has_house or (has_two_pairs and num_jokers == 1)) {
            hand_score += 8;
        } else if (has_three or (has_pair and num_jokers == 1) or (num_jokers == 2)) {
            hand_score += 4;
        } else if (has_two_pairs) {
            hand_score += 2;
        } else if (has_pair or (num_jokers == 1)) {
            hand_score += 1;
        }

        // max score based on card values, without pairs, house, ...
        const max_cards_score = std.math.powi(u64, 16, self.cards.len) catch unreachable;
        hand_score *= max_cards_score;

        var cards_score: u64 = 0;
        for (self.cards) |c| {
            cards_score = 14 * cards_score + self.cardScore(c);
        }
        hand_score += cards_score;

        return hand_score;
    }

    pub fn parse(line: []const u8, joker_mode: bool) !Hand {
        if (line.len < 6) {
            return ProgramError.AnyError;
        }
        var hand: Hand = .{
            .str = line[0..5],
            .cards = undefined,
            .bid = undefined,
            .score = undefined,
            .joker_mode = joker_mode,
        };
        for (hand.str, 0..) |char, i| {
            hand.cards[i] = try Card.fromChar(char);
        }
        hand.bid = try std.fmt.parseInt(i64, line[6..], 10);
        hand.score = hand.computeScore();

        return hand;
    }

    fn countUnique(self: Hand) CardCounter {
        var counter = CardCounter.init();
        for (self.cards) |card| {
            counter.count(card.index);
        }

        return counter;
    }
};

fn parse(allocator: Allocator, input: []const u8, joker_mode: bool) ![]Hand {
    var hands = std.ArrayList(Hand).init(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        const hand = try Hand.parse(line, joker_mode);
        try hands.append(hand);
    }

    return try hands.toOwnedSlice();
}

fn sort(hands: *[]Hand) void {
    const Context = struct {
        fn lessThanFn(ctx: @This(), lhs: Hand, rhs: Hand) bool {
            _ = ctx;
            return lhs.score < rhs.score;
        }
    };

    std.sort.insertion(Hand, hands.*, Context{}, Context.lessThanFn);
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var hands = try parse(aa, input, false);
    sort(&hands);

    var total_winnings: i64 = 0;
    for (hands, 1..) |hand, rank| {
        // print("{s}\n", .{hand.str});
        total_winnings += @as(i64, @intCast(rank)) * hand.bid;
    }

    return total_winnings;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var hands = try parse(aa, input, true);
    sort(&hands);

    var total_winnings: i64 = 0;
    for (hands, 1..) |hand, rank| {
        print("{s}: {d}\n", .{ hand.str, hand.score });
        total_winnings += @as(i64, @intCast(rank)) * hand.bid;
    }

    return total_winnings;
}

// test "simple 1" {
//     const data =
//         \\32T3K 765
//         \\T55J5 684
//         \\KK677 28
//         \\KTJJT 220
//         \\QQQJA 483
//     ;
//
//     const allocator = std.testing.allocator;
//     try std.testing.expectEqual(@as(i64, 6440), try process1(allocator, data));
// }
//
//
test "simple 2" {
    const data =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 5905), try process2(allocator, data));
}

test "bug 1" {
    const data =
        \\JT89Q 10
        \\ATKQ5 20
        \\JK4T3 30
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 20 * 1 + 10 * 2 + 30 * 3), try process2(allocator, data));
}

test "bug 2" {
    const data =
        \\AAKKQ 10
        \\2233J 20
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 10 * 1 + 20 * 2), try process2(allocator, data));
}
