const std = @import("std");

const zap = @import("zap");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var parser: zap.ArgumentParser = try zap.ArgumentParser.init(allocator, "my test parser");
    defer parser.deinit();

    _ = parser.addArgument("integer", i32, 125, null);
    _ = parser.addArgument("test", bool, null, zap.ArgumentOptions{ .role = .Flag });
    _ = parser.addArgument("float", f64, 125.23, zap.ArgumentOptions{ .role = .Optional });
    _ = parser.addArgument("string", []const u8, "hello arg", zap.ArgumentOptions{ .role = .Optional });

    std.debug.print("Arguments before parsing\n", .{});
    parser.printInfo();

    parser.parse() catch {
        std.debug.print(">>> Error parsing arguments!\n", .{});
        return;
    };

    std.debug.print("\n\nArguments after parsing\n", .{});
    parser.printInfo();
}
