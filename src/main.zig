const std = @import("std");

const zlip = @import("zlip");

// The should not be completely generic, but adhere to some predefined types

fn BaseArg(T: type) type {
    return struct { name: []const u8, value: T = undefined };
}

const BoolArg = BaseArg(bool);
const IntArg = BaseArg(i32);
const FloatArg = BaseArg(f32);
const StringArg = BaseArg([]const u8);

const ParserError = error{ InvalidRawType, CouldNotBeParsed };

const Argument = union(enum) {
    Bool: BoolArg,
    Int: IntArg,
    Float: FloatArg,
    String: StringArg,

    fn createFromType(name: []const u8, T: type, value: ?T) ParserError!Argument {
        if (zlip.isInteger(T)) return Argument{ .Int = IntArg{ .name = name, .value = if (value) |v| @truncate(v) else undefined } };
        if (zlip.isFloat(T)) return Argument{ .Float = FloatArg{ .name = name, .value = if (value) |v| @floatCast(v) else undefined } };
        if (T == bool) return Argument{ .Bool = BoolArg{ .name = name, .value = value orelse undefined } };
        if (T == []const u8) return Argument{ .String = StringArg{ .name = name, .value = value orelse undefined } };
        return ParserError.CouldNotBeParsed;
    }
};

const ArgumentParser = struct {
    name: []const u8,
    arguments: std.ArrayList(Argument),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser {
        return ArgumentParser{
            .arguments = try std.ArrayList(Argument).initCapacity(allocator, 100),
            .name = name,
            .allocator = allocator,
        };
    }

    fn deinit(self: *ArgumentParser) void {
        self.arguments.deinit(self.allocator);
    }

    fn addArgument(self: *ArgumentParser, name: []const u8, T: type, defaultValue: ?T) bool {
        const arg = Argument.createFromType(name, T, defaultValue) catch return false;
        self.arguments.append(self.allocator, arg) catch return false;

        return true;
    }

    fn parseFromArgIterator(self: *ArgumentParser, arg_iterator: *std.process.ArgIterator) void {
        var i: usize = 0;
        while (arg_iterator.next()) |arg| : (i += 1) {
            std.debug.print("({d})[{d:>3}] {s}\n", .{ i, arg.len, arg.ptr });
        }

        std.debug.print("------CONFIG. ARGS-------\n", .{});

        for (self.arguments.items, 0..) |arg, j| {
            switch (arg) {
                .Bool => std.debug.print("({d})[Bool ] {s:<20}: {s}\n", .{ j, arg.Bool.name, if (arg.Bool.value) "true" else "false" }),
                .Int => std.debug.print("({d})[Int  ] {s:<20}: {d}\n", .{ j, arg.Int.name, arg.Int.value }),
                .Float => std.debug.print("({d})[Float] {s:<20}: {d}\n", .{ j, arg.Float.name, arg.Float.value }),
                else => std.debug.print("({d}){}\n", .{ j, arg }),
            }
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    var parser: ArgumentParser = try ArgumentParser.init(allocator, "parser");
    defer parser.deinit();
    _ = parser.addArgument("test", bool, null);
    _ = parser.addArgument("withDefault", i32, 125);
    _ = parser.addArgument("withDefault2", f64, 125.23);
    _ = parser.addArgument("string", []const u8, "hello arg");
    parser.parseFromArgIterator(&arg_iterator);
}
