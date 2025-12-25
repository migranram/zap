//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const arg_mod = @import("argument.zig");
const Argument = arg_mod.Argument;
const ArgumentOptions = arg_mod.ArgumentOptions;

/// _deinit()_ available
pub const ArgumentParser = struct {
    name: []const u8,
    arguments: std.ArrayList(Argument),
    arguments_options: std.ArrayList(?ArgumentOptions),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser {
        return ArgumentParser{
            .arguments = try std.ArrayList(Argument).initCapacity(allocator, 10),
            .arguments_options = .empty,
            .name = name,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ArgumentParser) void {
        self.arguments.deinit(self.allocator);
        self.arguments_options.deinit(self.allocator);
    }

    pub fn addArgument(self: *ArgumentParser, name: []const u8, T: type, defaultValue: ?T, options: ?ArgumentOptions) bool {
        const arg = Argument.createFromType(name, T, defaultValue) catch return false;
        self.arguments.append(self.allocator, arg) catch return false;

        self.arguments_options.append(self.allocator, options) catch return false;

        return true;
    }

    pub fn parseFromArgIterator(self: *ArgumentParser, arg_iterator: *std.process.ArgIterator) void {
        var i: usize = 0;
        while (arg_iterator.next()) |arg| : (i += 1) {
            std.debug.print("({d})[{d:>3}] {s}\n", .{ i, arg.len, arg.ptr });
        }

        std.debug.print("------CONFIG. ARGS-------\n", .{});

        for (self.arguments.items, 0..) |arg, j| {
            switch (arg) {
                .Bool => std.debug.print("({d})[{s:-^14}] {s:<20}: {s}\n", .{ j, "Bool", arg.Bool.name, if (arg.Bool.value) "true" else "false" }),
                .Int => std.debug.print("({d})[{s:-^14}] {s:<20}: {d}\n", .{ j, "Int", arg.Int.name, arg.Int.value }),
                .Float => std.debug.print("({d})[{s:-^14}] {s:<20}: {d}\n", .{ j, "Float", arg.Float.name, arg.Float.value }),
                .String => std.debug.print("({d})[{s:-^14}] {s:<20}: {s}\n", .{ j, "String", arg.String.name, arg.String.value }),
            }
        }
    }
};
