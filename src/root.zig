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

    // Sub commands
    subcommands_ptr_list: std.ArrayList(ArgumentParser),
    selected_sub_cmd: ?u16,

    // Arguments
    flag_arguments: std.ArrayList(Argument),
    positional_arguments: std.ArrayList(Argument),
    optional_arguments: std.ArrayList(Argument),

    // Init / De-init ----------------
    pub fn init(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser {
        return ArgumentParser{
            .flag_arguments = .empty,
            .positional_arguments = .empty,
            .optional_arguments = .empty,
            .name = name,
            .allocator = allocator,
            .subcommands_ptr_list = .empty,
            .selected_sub_cmd = null,
        };
    }

    pub fn deinit(self: *ArgumentParser) void {
        self.flag_arguments.deinit(self.allocator);
        self.positional_arguments.deinit(self.allocator);
        self.optional_arguments.deinit(self.allocator);

        for (self.subcommands_ptr_list.items) |*cmd| {
            cmd.deinit();
        }
        self.subcommands_ptr_list.deinit(self.allocator);
    }

    // Subcommands ----------------
    pub fn addCommand(self: *ArgumentParser, name: []const u8) !*ArgumentParser {
        const cmd = try self.subcommands_ptr_list.addOne(self.allocator);

        errdefer _ = self.subcommands_ptr_list.pop();
        cmd.* = try ArgumentParser.init(self.allocator, name);
        return cmd;
    }

    // Argument handling ----------------
    pub fn addArgument(self: *ArgumentParser, name: []const u8, T: type, defaultValue: ?T, options: ?ArgumentOptions) !void {
        // Check if there are sub-commands. Currently a parser with subcmds cannot have global arguments
        if (self.subcommands_ptr_list.items.len > 0)
            return Errors.ParserError.CannotAddArgument;

        const arg_type = if (options) |opt| opt.role else ArgumentRole.Positional;

        if (arg_type == .Flag and T != bool)
            return Errors.ParserError.InvalidRawType;

        const arg = try Argument.createFromType(name, T, defaultValue);

        switch (arg_type) {
            ArgumentRole.Flag => {
                try self.flag_arguments.append(self.allocator, arg);
            },
            ArgumentRole.Positional => {
                try self.positional_arguments.append(self.allocator, arg);
            },
            ArgumentRole.Optional => {
                try self.optional_arguments.append(self.allocator, arg);
            },
        }

        return;
    }

    pub fn addArgumentsFromStruct(self: *ArgumentParser, arg_struct: type, options: ?ArgumentOptions) !void {
        const ti = @typeInfo(arg_struct);
        if (ti != .@"struct") {
            std.debug.print("Error parsing argument structs \"{s}\". The passed type has to be a struct!\n", .{@typeName(arg_struct)});
            return Errors.ParserError.InvalidRawType;
        }

        inline for (ti.@"struct".fields) |field| {
            self.addArgument(field.name, field.type, field.defaultValue(), options) catch |e| {
                std.debug.print("Could not add argument \"{s}\". In argument struct [{s}]. {any}\n", .{ field.name, @typeName(arg_struct), e });
            };
        }

        return;
    }

    pub fn parseFromArgIterator(self: *ArgumentParser, arg_iterator: *std.process.ArgIterator, continue_on_unknown: bool) Errors.ParserError!void {
        // First parse the positionals, they have to be in the same order as defined:
        var ix: usize = 0;
        outerloop: while (arg_iterator.next()) |token| : (ix += 1) {
            if (self.subcommands_ptr_list.items.len > 0) {
                for (self.subcommands_ptr_list.items, 0..) |*cmd, id| {
                    if (!std.mem.eql(u8, cmd.name, token))
                        continue;

                    self.selected_sub_cmd = @intCast(id);
                    try cmd.parseFromArgIterator(arg_iterator, continue_on_unknown);
                    break :outerloop;
                }
                std.debug.print("No sub command could be parsed! Available are:\n", .{});
                for (self.subcommands_ptr_list.items, 0..) |cmd, id| std.debug.print("\t--> [{d}] {s}\n", .{ id, cmd.name });
                return Errors.ParserError.CouldNotBeParsed;
            }
            for (self.positional_arguments.items) |*arg| {
                const res: ParsingResult = arg.parseString(token, ArgumentRole.Positional) catch |e| {
                    if (e == Errors.ParserError.InvalidRawType)
                        std.debug.print("Error parsing value \"{s}\" for positional [{s}]\n", .{ token, arg.getName() });
                    return e;
                };

                if (res == .NotParsed) {
                    std.debug.print("Positional argument not found: {s}\n", .{arg.*.getName()});
                    return Errors.ParserError.CouldNotBeParsed;
                } // The value has to exist

                if (res == .Parsed)
                    continue :outerloop;

                // If already parsed go to next arg
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
                    for (self.optional_arguments.items) |*other| {
                        if (other.matches(t, .Optional)) {
                            std.debug.print("Trying to parse \"{s}\" as value for optional [{s}] failed!\n", .{ t, arg.getName() });
                            return Errors.ParserError.CouldNotBeParsed;
                        }
                    }
                    for (self.flag_arguments.items) |*other| {
                        if (other.matches(t, .Flag)) {
                            std.debug.print("Trying to parse \"{s}\" as value for optional [{s}] failed!\n", .{ t, arg.getName() });
                            return Errors.ParserError.CouldNotBeParsed;
                        }
                    }

                    arg.parseValueFromString(t) catch {
                        std.debug.print("Error parsing value \"{s}\" for optional [{s}]\n", .{ t, arg.getName() });
                        return Errors.ParserError.InvalidRawType;
                    };
                    continue :outerloop;
                } else {
                    std.debug.print("Missing value for optional: {s}\n", .{arg.*.getName()});
                    return Errors.ParserError.CouldNotBeParsed;
                }
            }

            std.debug.print("Unknown argument: {s}\n", .{token});
            if (!continue_on_unknown)
                return Errors.ParserError.CouldNotBeParsed;
        }
    }

    /// Throws an **zlap.Error.ParsingError** if something goes wrong while parsing!
    pub fn parse(self: *ArgumentParser) !void {
        var arg_iterator = try std.process.argsWithAllocator(self.allocator);
        defer arg_iterator.deinit();
        _ = arg_iterator.next();

        return self.parseFromArgIterator(&arg_iterator, false);
    }

    fn findArgument(self: *const ArgumentParser, name: []const u8) ?Argument {
        for (self.positional_arguments.items) |arg| if (std.mem.eql(u8, name, arg.getName())) return arg;
        for (self.flag_arguments.items) |arg| if (std.mem.eql(u8, name, arg.getName())) return arg;
        for (self.optional_arguments.items) |arg| if (std.mem.eql(u8, name, arg.getName())) return arg;

        return null;
    }

    pub fn getIntArgument(self: *const ArgumentParser, name: []const u8) ?i64 {
        if (self.subcommands_ptr_list.items.len > 0) {
            if (self.selected_sub_cmd == null) {
                return null;
            } else {
                return self.subcommands_ptr_list.items[self.selected_sub_cmd.?].getIntArgument(name);
            }
        }
        if (self.findArgument(name)) |arg| return arg.get(i64);

        return null;
    }

    pub fn getFloatArgument(self: *const ArgumentParser, name: []const u8) ?f64 {
        if (self.subcommands_ptr_list.items.len > 0) {
            if (self.selected_sub_cmd == null) {
                return null;
            } else {
                return self.subcommands_ptr_list.items[self.selected_sub_cmd.?].getFloatArgument(name);
            }
        }
        if (self.findArgument(name)) |arg| return arg.get(f64);

        return null;
    }

    pub fn getStringArgument(self: *const ArgumentParser, name: []const u8) ?[]const u8 {
        if (self.subcommands_ptr_list.items.len > 0) {
            if (self.selected_sub_cmd == null) {
                return null;
            } else {
                return self.subcommands_ptr_list.items[self.selected_sub_cmd.?].getStringArgument(name);
            }
        }
        if (self.findArgument(name)) |arg| return arg.get([]const u8);

        return null;
    }

    pub fn getBoolArgument(self: *const ArgumentParser, name: []const u8) ?bool {
        if (self.subcommands_ptr_list.items.len > 0) {
            if (self.selected_sub_cmd == null) {
                return null;
            } else {
                return self.subcommands_ptr_list.items[self.selected_sub_cmd.?].getBoolArgument(name);
            }
        }
        if (self.findArgument(name)) |arg| return arg.get(bool);

        return null;
    }


    // Utils ----------------
    pub fn printInfo(self: *const ArgumentParser) void {
        std.debug.print("{s:-^30}\n", .{self.name});
        if (self.subcommands_ptr_list.items.len > 0) {
            if (self.selected_sub_cmd == null) {
                for (self.subcommands_ptr_list.items) |cmd| cmd.printInfo();
            } else self.subcommands_ptr_list.items[self.selected_sub_cmd.?].printInfo();
            return;
        }
        var j: usize = 0;
        var buffer: [100]u8 = undefined;
        for (self.positional_arguments.items) |arg| {
            switch (arg) {
                .Bool => std.debug.print("({d})|.POS|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                .Int => std.debug.print("({d})|.POS|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                .Float => std.debug.print("({d})|.POS|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                .String => std.debug.print("({d})|.POS|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
            }
            j += 1;
        }
        for (self.flag_arguments.items) |arg| {
            switch (arg) {
                .Bool => std.debug.print("({d})|FLAG|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                else => @panic("Flag should only be bool"),
            }
            j += 1;
        }
        for (self.optional_arguments.items) |arg| {
            switch (arg) {
                .Bool => std.debug.print("({d})|.OPT|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                .Int => std.debug.print("({d})|.OPT|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                .Float => std.debug.print("({d})|.OPT|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
                .String => std.debug.print("({d})|.OPT|{s}\n", .{ j, arg.getFormattedString(&buffer) }),
            }
            j += 1;
        }
    }
};
