//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const arg_mod = @import("argument.zig");
pub const Argument = arg_mod.Argument;
pub const ArgumentOptions = arg_mod.ArgumentOptions;
pub const ArgumentRole = arg_mod.ArgumentRole;
pub const ParsingResult = arg_mod.ParsingResult;
pub const Errors = @import("errors.zig");

/// _deinit()_ available
pub const ArgumentParser = struct {
    name: []const u8,
    allocator: std.mem.Allocator,

    // Arguments
    flag_arguments: std.ArrayList(Argument),
    positional_arguments: std.ArrayList(Argument),
    optional_arguments: std.ArrayList(Argument),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser {
        return ArgumentParser{
            .flag_arguments = try std.ArrayList(Argument).initCapacity(allocator, 10),
            .positional_arguments = try std.ArrayList(Argument).initCapacity(allocator, 10),
            .optional_arguments = try std.ArrayList(Argument).initCapacity(allocator, 10),
            .name = name,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ArgumentParser) void {
        self.flag_arguments.deinit(self.allocator);
        self.positional_arguments.deinit(self.allocator);
        self.optional_arguments.deinit(self.allocator);
    }

    pub fn addArgument(self: *ArgumentParser, name: []const u8, T: type, defaultValue: ?T, options: ?ArgumentOptions) bool {
        const arg_type = if (options) |opt| opt.role else ArgumentRole.Positional;

        if (arg_type == .Flag and T != bool)
            return false;

        const arg = Argument.createFromType(name, T, defaultValue) catch return false;

        switch (arg_type) {
            ArgumentRole.Flag => self.flag_arguments.append(self.allocator, arg) catch return false,
            ArgumentRole.Positional => self.positional_arguments.append(self.allocator, arg) catch return false,
            ArgumentRole.Optional => self.optional_arguments.append(self.allocator, arg) catch return false,
        }

        return true;
    }

    pub fn printInfo(self: *ArgumentParser) void {
        std.debug.print("{s:-^30}\n", .{self.name});
        var j: usize = 0;
        for (self.positional_arguments.items) |arg| {
            switch (arg) {
                .Bool => std.debug.print("({d})|.POS|[{s:.^14}] {s:<20}: {s}\n", .{ j, "Bool", arg.Bool.name, if (arg.Bool.value) "true" else "false" }),
                .Int => std.debug.print("({d})|.POS|[{s:.^14}] {s:<20}: {d}\n", .{ j, "Int", arg.Int.name, arg.Int.value }),
                .Float => std.debug.print("({d})|.POS|[{s:.^14}] {s:<20}: {d}\n", .{ j, "Float", arg.Float.name, arg.Float.value }),
                .String => std.debug.print("({d})|.POS|[{s:.^14}] {s:<20}: {s}\n", .{ j, "String", arg.String.name, arg.String.value }),
            }
            j += 1;
        }
        for (self.flag_arguments.items) |arg| {
            switch (arg) {
                .Bool => std.debug.print("({d})|FLAG|[{s:.^14}] {s:<20}: {s}\n", .{ j, "Bool", arg.Bool.name, if (arg.Bool.value) "true" else "false" }),
                else => @panic("Flag should only be bool"),
            }
            j += 1;
        }
        for (self.optional_arguments.items) |arg| {
            switch (arg) {
                .Bool => std.debug.print("({d})|.OPT|[{s:.^14}] {s:<20}: {s}\n", .{ j, "Bool", arg.Bool.name, if (arg.Bool.value) "true" else "false" }),
                .Int => std.debug.print("({d})|.OPT|[{s:.^14}] {s:<20}: {d}\n", .{ j, "Int", arg.Int.name, arg.Int.value }),
                .Float => std.debug.print("({d})|.OPT|[{s:.^14}] {s:<20}: {d}\n", .{ j, "Float", arg.Float.name, arg.Float.value }),
                .String => std.debug.print("({d})|.OPT|[{s:.^14}] {s:<20}: {s}\n", .{ j, "String", arg.String.name, arg.String.value }),
            }
            j += 1;
        }
    }

    pub fn parseFromArgIterator(self: *ArgumentParser, arg_iterator: *std.process.ArgIterator) Errors.ParserError!void {
        // First parse the positionals, they have to be in the same order as defined:
        var ix: usize = 0;
        outerloop: while (arg_iterator.next()) |token| : (ix += 1) {
            for (self.positional_arguments.items) |*arg| {
                const res: ParsingResult = try arg.parseString(token, ArgumentRole.Positional);

                if (res == .NotParsed) {
                    std.debug.print("Positional argument not found: {s}\n", .{arg.*.getName()});
                    return Errors.ParserError.CouldNotBeParsed;
                } // The value has to exist

                if (res == .Parsed)
                    continue :outerloop;
            }
            for (self.flag_arguments.items) |*arg| {
                const res: ParsingResult = try arg.parseString(token, ArgumentRole.Flag);

                if (res == .Parsed)
                    continue :outerloop;
            }
            for (self.optional_arguments.items) |*arg| {
                const res: ParsingResult = try arg.parseString(token, ArgumentRole.Optional);

                if (res != .Parsed)
                    continue;

                const next_token = arg_iterator.next();

                if (next_token) |t| {
                    try arg.parseValueFromString(t);
                    continue :outerloop;
                } else {
                    std.debug.print("Missing value for optional: {s}\n", .{arg.*.getName()});
                    return Errors.ParserError.CouldNotBeParsed;
                }
            }

            std.debug.print("Unknown argument: {s}\n", .{token});
            return Errors.ParserError.CouldNotBeParsed;
        }
    }

    /// Throws an **zlap.Error.ParsingError** if something goes wrong while parsing!
    pub fn parse(self: *ArgumentParser) !void {
        var arg_iterator = try std.process.argsWithAllocator(self.allocator);
        defer arg_iterator.deinit();
        _ = arg_iterator.next();

        return self.parseFromArgIterator(&arg_iterator);
    }
};
