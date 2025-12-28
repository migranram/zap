const std = @import("std");

const zlip = @import("zlip");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();
    _ = arg_iterator.next();

    var parser: zlip.ArgumentParser = try zlip.ArgumentParser.init(allocator, "parser");
    defer parser.deinit();
    _ = parser.addArgument("integer", i32, 125, null);
    _ = parser.addArgument("test", bool, null, zlip.ArgumentOptions{ .role = .Flag });
    _ = parser.addArgument("float", f64, 125.23, zlip.ArgumentOptions{ .role = .Optional });
    _ = parser.addArgument("string", []const u8, "hello arg", zlip.ArgumentOptions{ .role = .Optional });
    parser.parseFromArgIterator(&arg_iterator) catch std.debug.print("Error parsing arguments!\n", .{});

    parser.printInfo();
}
