const std = @import("std");

const zlip = @import("zlip");

fn t(names: []const []const u8) void {
    for (names) |name| {
        std.debug.print("{s}\n", .{name});
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    var parser: zlip.ArgumentParser = try zlip.ArgumentParser.init(allocator, "parser");
    defer parser.deinit();
    _ = parser.addArgument("test", bool, null, null);
    _ = parser.addArgument("integer", i32, 125, null);
    _ = parser.addArgument("float", f64, 125.23, null);
    _ = parser.addArgument("string", []const u8, "hello arg", null);
    parser.parseFromArgIterator(&arg_iterator);

    t(&.{ "test", "-t" });
}
