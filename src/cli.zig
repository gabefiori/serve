const std = @import("std");
const assert = std.debug.assert;

pub const CliError = error{
    InvalidArgument,
    UnknownOption,
    MissingValue,
    InvalidShortArgument,
} || std.fmt.ParseIntError;

pub const help_message =
    \\Usage: serve [PATH] [OPTIONS]
    \\
    \\Simple static HTTP server.
    \\
    \\Arguments:
    \\  PATH                Specify the server path (default: '.')
    \\
    \\Options:
    \\  -h, --help          Show this help message and exit
    \\  -p, --port PORT     Set the server port (default: 8080)
    \\  -t, --threads NUM   Set the number of threads (default: 2)
    \\  -w, --workers NUM   Set the number of workers (default: 1)
;

pub const Args = struct {
    path: []const u8 = ".",
    threads: i16 = 2,
    workers: i16 = 1,
    port: usize = 8080,
    help: bool = false,
    iter: *ArgsIterator,

    const Option = struct {
        short: []const u8,
        long: []const u8,
        is_long: bool = false,
        is_short: bool = false,

        fn matches(self: *Option, haystack: []const u8) bool {
            if (haystack.len == 0) return false;

            if (self.short.len > 0) {
                if (haystack[0] != '-') return false;
                self.is_short = std.mem.startsWith(u8, haystack[1..], self.short);
                if (self.is_short) return self.is_short;
            }

            if (self.long.len == 0 or haystack.len < 2) return false;
            if (!std.mem.startsWith(u8, haystack, "--")) return false;

            self.is_long = std.mem.startsWith(u8, haystack[2..], self.long);

            return self.is_long;
        }
    };

    pub fn init(iter: *ArgsIterator) Args {
        return .{ .iter = iter };
    }

    pub fn parse(self: *Args) CliError!void {
        assert(self.iter.skip());

        var opt_port: Option = .{ .short = "p", .long = "port" };
        var opt_threads: Option = .{ .short = "t", .long = "threads" };
        var opt_workers: Option = .{ .short = "w", .long = "workers" };

        while (self.iter.next()) |arg| {
            if (!std.mem.startsWith(u8, arg, "-")) {
                self.path = arg;
                continue;
            }

            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                self.help = true;
                return;
            }

            if (opt_port.matches(arg)) {
                self.port = try self.parse_arg(usize, &opt_port);
                continue;
            }

            if (opt_threads.matches(arg)) {
                self.threads = try self.parse_arg(i16, &opt_threads);
                continue;
            }

            if (opt_workers.matches(arg)) {
                self.workers = try self.parse_arg(i16, &opt_workers);
                continue;
            }

            return CliError.UnknownOption;
        }
    }

    fn parse_arg(self: *Args, comptime T: type, key: *Option) !T {
        const eq = std.mem.indexOfScalar(u8, self.iter.current, '=');

        if (key.is_short) {
            if (eq) |_| return CliError.InvalidShortArgument;

            if (!std.mem.eql(u8, key.short, self.iter.current[1..])) {
                return try parse_value(T, self.iter.current[key.short.len + 1 ..]);
            }

            return try parse_value(T, try self.iter.try_next());
        }

        if (eq) |pos| {
            return try parse_value(T, self.iter.current[pos + 1 ..]);
        }

        return parse_value(T, try self.iter.try_next());
    }

    fn parse_value(comptime T: type, raw: ?[]const u8) !T {
        const src = raw orelse return CliError.MissingValue;
        return switch (T) {
            []const u8 => src,
            i16 => try std.fmt.parseInt(i16, src, 10),
            usize => try std.fmt.parseInt(usize, src, 10),
            else => @compileError("Unsupported type"),
        };
    }
};

pub const ArgsIterator = struct {
    index: usize = 0,
    count: usize = 0,
    items: [][*:0]u8,
    current: [:0]const u8 = "",

    pub fn init(items: [][*:0]u8) ArgsIterator {
        return ArgsIterator{
            .items = items,
            .count = items.len,
        };
    }

    pub fn try_next(self: *ArgsIterator) ![:0]const u8 {
        if (self.next()) |item| {
            return item;
        }

        return CliError.MissingValue;
    }

    pub fn next(self: *ArgsIterator) ?[:0]const u8 {
        if (self.index == self.count) return null;
        const s = self.items[self.index];

        self.index += 1;
        self.current = std.mem.sliceTo(s, 0);

        return self.current;
    }

    pub fn skip(self: *ArgsIterator) bool {
        if (self.index == self.count) return false;
        self.index += 1;
        return true;
    }
};

test "parse" {
    var items = [_][*:0]u8{
        @constCast("server"),
        @constCast("/custom/path"),
        @constCast("--threads"),
        @constCast("10"),
        @constCast("--workers=20"),
        @constCast("-p8000"),
        @constCast("--help"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try args.parse();
    try std.testing.expectEqualStrings("/custom/path", args.path);
    try std.testing.expectEqual(10, args.threads);
    try std.testing.expectEqual(20, args.workers);
    try std.testing.expectEqual(8000, args.port);
    try std.testing.expect(args.help);
}

test "parse missing value" {
    var items = [_][*:0]u8{
        @constCast("server"),
        @constCast("--threads"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try std.testing.expectError(CliError.MissingValue, args.parse());
}

test "parse unknown option" {
    var items = [_][*:0]u8{
        @constCast("server"),
        @constCast("--unknown-option"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try std.testing.expectError(CliError.UnknownOption, args.parse());
}

test "parse invalid integer" {
    var items = [_][*:0]u8{
        @constCast("server"),
        @constCast("--threads"),
        @constCast("not_a_number"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try std.testing.expectError(error.InvalidCharacter, args.parse());
}

test "parse multiple options in different orders" {
    var items = [_][*:0]u8{
        @constCast("server"),
        @constCast("--workers=15"),
        @constCast("/another/path"),
        @constCast("-t"),
        @constCast("8"),
        @constCast("-p"),
        @constCast("9000"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try args.parse();
    try std.testing.expectEqualStrings("/another/path", args.path);
    try std.testing.expectEqual(8, args.threads);
    try std.testing.expectEqual(15, args.workers);
    try std.testing.expectEqual(9000, args.port);
}

test "parse with minimum arguments" {
    var items = [_][*:0]u8{
        @constCast("server"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try args.parse();
    try std.testing.expectEqualStrings(".", args.path);
    try std.testing.expectEqual(2, args.threads);
    try std.testing.expectEqual(1, args.workers);
    try std.testing.expectEqual(8080, args.port);
    try std.testing.expect(!args.help);
}

test "parse invalid short argument" {
    var items = [_][*:0]u8{
        @constCast("server"),
        @constCast("-p=8000"),
    };

    var iter = ArgsIterator.init(&items);
    var args = Args.init(&iter);

    try std.testing.expectError(CliError.InvalidShortArgument, args.parse());
}
