const std = @import("std");

const zap = @import("zap");

const myOptionalArgs = struct { optional1: f32, int_param_name: i32 = 35, just_another_param: bool, nested_struct: struct {} };

const notValidArgsType = enum { hello, world };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var parser: zap.ArgumentParser = try zap.ArgumentParser.init(allocator, "my test parser");
    defer parser.deinit();

    const cmd = try parser.addCommand("action");

    std.debug.print("Added subcommand: {s}\n", .{cmd.name});

    parser.addArgument("integer", i32, 125, null) catch {
        std.debug.print("Cannot add argument to global parser when there are sub commands!\n", .{});
    };

    try cmd.addArgument("integer", i32, 125, null);
    try cmd.addArgument("test", bool, null, zap.ArgumentOptions{ .role = .Flag });
    try cmd.addArgument("float", f64, 125.23, zap.ArgumentOptions{ .role = .Optional });
    try cmd.addArgument("string", []const u8, "hello arg", zap.ArgumentOptions{ .role = .Optional });

    try cmd.addArgumentsFromStruct(myOptionalArgs, zap.ArgumentOptions{ .role = .Optional });
    cmd.addArgumentsFromStruct(notValidArgsType, zap.ArgumentOptions{ .role = .Optional }) catch {};

    std.debug.print("Arguments before parsing\n", .{});
    parser.printInfo();

    parser.parse() catch {
        std.debug.print(">>> Error parsing arguments!\n", .{});
        return;
    };

    std.debug.print("\n\nArguments after parsing\n", .{});
    parser.printInfo();

    std.debug.print("\nAccess value of argument <float>: {d}\n", .{parser.getFloatArgument("float").?});
    std.debug.print("Access value of argument <string>: {s}\n", .{parser.getStringArgument("string").?});
    std.debug.print("Access value of argument <integer>: {d}\n", .{parser.getIntArgument("integer").?});
    std.debug.print("Access value of argument <test>: {s}\n", .{if (parser.getBoolArgument("test").?) "true" else "false"});
}
