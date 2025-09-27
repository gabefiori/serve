const std = @import("std");
const builtin = @import("builtin");

const zap = @import("zap");
const Logging = zap.Logging;

const cli = @import("cli.zig");

pub fn main() !void {
    var args_iter: cli.ArgsIterator = .init(std.os.argv);
    var args: cli.Args = .init(&args_iter);

    args.parse() catch |err| {
        std.log.err("Invalid argument '{s}' ({s})", .{ args_iter.current, @errorName(err) });
        std.process.exit(1);
    };

    if (args.help) {
        var stdout_buffer: [512]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;

        try stdout.writeAll(cli.help_message);
        try stdout.flush();

        return;
    }

    if (builtin.mode == .Debug) {
        Logging.fio_set_log_level(Logging.fio_log_level_debug);
    } else {
        Logging.fio_set_log_level(Logging.fio_log_level_info);
    }

    var listener = zap.HttpListener.init(.{
        .port = args.port,
        .on_request = on_request,
        .public_folder = args.path,
        .log = true,
    });

    try listener.listen();

    zap.start(.{
        .threads = args.threads,
        .workers = args.workers,
    });
}

fn on_request(r: zap.Request) !void {
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - File not found</h1></body></html>") catch return;
}
