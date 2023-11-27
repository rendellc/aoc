const std = @import("std");

pub const LineIterator = std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence);
