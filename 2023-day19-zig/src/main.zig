const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const dprint = std.debug.print;

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

    try bw.flush();
}

const ProgramError = error{
    AnyError,
};

const Workflows = struct {
    workflows: std.StringHashMap(Workflow),

    pub fn init(allocator: Allocator) Workflows {
        return .{
            .workflows = std.StringHashMap(Workflow).init(allocator),
        };
    }

    pub fn add(self: *Workflows, workflow: Workflow) !void {
        try self.workflows.put(workflow.name, workflow);
    }

    pub fn get(self: Workflows, name: []const u8) Workflow {
        return self.workflows.get(name).?;
    }

    pub fn checkIsAccepted(self: Workflows, part: Part) bool {
        var w = self.get("in");

        while (true) {
            const redirect = w.evaluate(part);

            switch (redirect) {
                Rule.RedirectType.None => {
                    unreachable;
                },
                Rule.RedirectType.Accept => {
                    return true;
                },
                Rule.RedirectType.Reject => {
                    return false;
                },
                Rule.RedirectType.Workflow => |name| {
                    w = self.get(name);
                },
            }
        }

        unreachable;
    }
};

const Workflow = struct {
    name: []const u8,
    rules: []const Rule,

    pub fn parse(allocator: Allocator, str: []const u8) !Workflow {
        // px{a<2006:qkq,m>2090:A,rfg}
        const name_len = std.mem.indexOfScalar(u8, str, '{').?;
        const rule_end = std.mem.indexOfScalar(u8, str, '}').?;
        const rules_str = str[name_len + 1 .. rule_end];
        var rule_strs = std.mem.splitScalar(u8, rules_str, ',');
        var rules = std.ArrayList(Rule).init(allocator);
        while (rule_strs.next()) |rule_str| {
            const r = try Rule.parse(rule_str);
            try rules.append(r);
        }

        return .{
            .name = str[0..name_len],
            .rules = try rules.toOwnedSlice(),
        };
    }

    pub fn evaluate(self: Workflow, part: Part) Rule.Redirect {
        for (self.rules) |rule| {
            const redirect = rule.evaluate(part);

            switch (redirect) {
                Rule.RedirectType.None => {
                    continue;
                },
                else => {
                    return redirect;
                },
            }
        }

        unreachable;
    }
};

const Rule = struct {
    const Op = enum { None, LT, GT };
    const RedirectType = enum { None, Workflow, Reject, Accept };
    const Redirect = union(RedirectType) {
        None: void,
        Workflow: []const u8,
        Reject: void,
        Accept: void,
    };

    const Variable = enum { none, x, m, a, s };

    variable: Variable = Variable.none,
    op: Op = Op.None,
    value: i64 = 0,
    redirect: Redirect,

    pub fn parse(str: []const u8) !Rule {
        // px{a<2006:qkq,m>2090:A,rfg}
        // examples:
        // a<2006:qkq
        // m>2090:A
        // rfg
        // s<3803:A
        // R
        if (str.len == 0) {
            return ProgramError.AnyError;
        }

        if (str.len == 1) {
            return switch (str[0]) {
                'A' => .{ .redirect = Redirect{ .Accept = {} } },
                'R' => .{ .redirect = Redirect{ .Reject = {} } },
                else => ProgramError.AnyError,
            };
        }

        const redirect_sep = std.mem.indexOfScalar(u8, str, ':');
        if (redirect_sep == null) {
            return .{ .variable = Variable.none, .op = Op.None, .redirect = Redirect{
                .Workflow = str,
            } };
        }

        const redirect_str = str[redirect_sep.? + 1 ..];
        std.debug.assert(redirect_str.len >= 1);
        const redirect = switch (redirect_str[0]) {
            'A' => Redirect{ .Accept = {} },
            'R' => Redirect{ .Reject = {} },
            else => Redirect{ .Workflow = redirect_str },
        };
        // a<2006:qkq
        const variable = switch (str[0]) {
            'x' => Variable.x,
            'a' => Variable.a,
            'm' => Variable.m,
            's' => Variable.s,
            else => Variable.none,
        };
        const op = switch (str[1]) {
            '<' => Op.LT,
            '>' => Op.GT,
            else => {
                return ProgramError.AnyError;
            },
        };
        const value_start = std.mem.indexOfAny(u8, str, "<>").? + 1;
        const value = try std.fmt.parseInt(i64, str[value_start..redirect_sep.?], 10);

        const rule = Rule{
            .variable = variable,
            .op = op,
            .value = value,
            .redirect = redirect,
        };
        dprint("Parsed {s} to {any}\n", .{ str, rule });

        return rule;
    }

    pub fn evaluate(self: Rule, part: Part) Redirect {
        const variable: ?*const i64 = switch (self.variable) {
            Variable.none => null,
            Variable.x => &part.x,
            Variable.m => &part.m,
            Variable.a => &part.a,
            Variable.s => &part.s,
        };
        const condition_passed = switch (self.op) {
            Op.None => true,
            Op.LT => variable.?.* < self.value,
            Op.GT => variable.?.* > self.value,
        };
        if (!condition_passed) {
            return Redirect{ .None = {} };
        }

        return self.redirect;
    }
};

const Part = struct {
    x: i64,
    m: i64,
    a: i64,
    s: i64,

    pub fn parse(str: []const u8) !Part {
        //{x=2127,m=1623,a=2188,s=1013}
        const start = std.mem.indexOfScalar(u8, str, '{').?;
        const end = std.mem.indexOfScalar(u8, str, '}').?;
        var values = std.mem.splitScalar(u8, str[start + 1 .. end], ',');
        var part = Part{
            .x = 0,
            .m = 0,
            .a = 0,
            .s = 0,
        };
        while (values.next()) |value_str| {
            const value = try std.fmt.parseInt(i64, value_str[2..], 10);

            const variable: *i64 = switch (value_str[0]) {
                'x' => &part.x,
                'm' => &part.m,
                'a' => &part.a,
                's' => &part.s,
                else => {
                    return ProgramError.AnyError;
                },
            };
            variable.* = value;
        }

        return part;
    }
};

fn process1(allocator: Allocator, input: []const u8) !i64 {
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var iter = std.mem.splitSequence(u8, input, "\n\n");
    const workflows_str = iter.next().?;
    var workflow_strs = std.mem.splitScalar(u8, workflows_str, '\n');
    var workflows = Workflows.init(aa);
    while (workflow_strs.next()) |workflow_str| {
        const w = try Workflow.parse(aa, workflow_str);
        dprint("Parsed {s} to {any}\n", .{ workflow_str, w });
        try workflows.add(w);
    }

    const parts_str = iter.next().?;
    //var parts = std.ArrayList(Part).init(aa);
    var part_strs = std.mem.splitScalar(u8, parts_str, '\n');
    var sum: i64 = 0;
    while (part_strs.next()) |part_str| {
        if (part_str.len == 0) continue;
        const p = try Part.parse(part_str);

        const accepted = workflows.checkIsAccepted(p);
        if (accepted) {
            sum += p.x + p.m + p.a + p.s;
        }
    }

    return sum;
}

fn process2(allocator: Allocator, input: []const u8) !i64 {
    _ = input;
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    _ = aa;

    return 0;
}

test "simple 1" {
    const data =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;

    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 19114), try process1(allocator, data));
}
