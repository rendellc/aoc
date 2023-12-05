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

const Cards = std.StaticBitSet(100);
const CardGame = struct {
    id: usize,
    winning_cards: Cards,
    player_cards: Cards,

    pub fn countMatches(self: CardGame) usize {
        const matches = self.winning_cards.intersectWith(self.player_cards);
        return matches.count();
    }

    pub fn parseLine(line: []const u8) !CardGame {
        std.debug.print("parseGame: {s}\n", .{line});
        const semicolon_index = std.mem.indexOfScalar(u8, line, ':').?;
        const bar_index = std.mem.indexOfScalar(u8, line, '|').?;

        var game_id_str_iter = std.mem.tokenizeAny(u8, line, "Card :");
        const game_id_str = game_id_str_iter.next().?;

        const game_id = try std.fmt.parseInt(usize, game_id_str, 10);
        const winning_cards = try parseCards(line[semicolon_index + 1 .. bar_index]);
        const player_cards = try parseCards(line[bar_index + 1 ..]);

        return .{ .id = game_id, .winning_cards = winning_cards, .player_cards = player_cards };
    }
};

fn parseCards(numbers_str: []const u8) !Cards {
    //std.debug.print("parseCards: {s}\n", .{numbers_str});
    var cards = Cards.initEmpty();

    var number_strs = std.mem.tokenizeScalar(u8, numbers_str, ' ');
    while (number_strs.next()) |number_str| {
        // std.debug.print("\tparseCards: {s}\n", .{number_str});
        const number = try std.fmt.parseInt(u8, number_str, 10);
        cards.set(number);
    }

    return cards;
}

fn process1(allocator: Allocator, input: []const u8) !i64 {
    _ = allocator;
    // var arena = std.heap.ArenaAllocator.init(allocator);
    // defer arena.deinit();
    // const aa = arena.allocator();
    // _ = aa;

    var total_score: usize = 0;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        const card_game = try CardGame.parseLine(line);
        const matches = card_game.countMatches();
        if (matches == 0) {
            continue;
        }

        const game_score = std.math.pow(usize, 2, matches - 1);
        total_score += @intCast(game_score);
    }

    return @intCast(total_score);
}

fn parseGames(allocator: Allocator, input: []const u8) !std.ArrayList(CardGame) {
    var games = std.ArrayList(CardGame).init(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        const card_game = try CardGame.parseLine(line);
        try games.append(card_game);
    }

    return games;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const games = try parseGames(aa, input);
    var card_copies = try aa.alloc(usize, games.items.len);
    @memset(card_copies, 1);

    var total_number_of_cards: usize = 0;
    for (games.items) |game| {
        const card_index = game.id - 1;
        const number_of_this_card = card_copies[card_index];
        total_number_of_cards += number_of_this_card;

        const matches = game.countMatches();

        for (0..matches) |i| {
            const matched_game_index = card_index + 1 + i;
            if (matched_game_index >= games.items.len) {
                continue;
            }
            card_copies[matched_game_index] += number_of_this_card;
        }
    }

    std.debug.print("{any}\n", .{card_copies});

    return @intCast(total_number_of_cards);
}

test "simple 1" {
    const data =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 13), try process1(allocator, data));
}

test "simple 2" {
    const data =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 30), try process2(allocator, data));
}
