const std = @import("std");

const errors = @import("errors.zig");
const typing_utils = @import("typing_utils.zig");

fn BaseArg(T: type) type {
    return struct { name: []const u8, value: T = undefined, parsed: bool = false };
}

const BoolArg = BaseArg(bool);
const IntArg = BaseArg(i64);
const FloatArg = BaseArg(f64);
const StringArg = BaseArg([]const u8);

pub const ParsingResult = enum { Parsed, NotParsed, AlreadyParsed };

pub const Argument = union(enum) {
    Bool: BoolArg,
    Int: IntArg,
    Float: FloatArg,
    String: StringArg,

    pub fn createFromType(name: []const u8, T: type, value: ?T) errors.ParserError!Argument {
        if (typing_utils.isInteger(T)) return Argument{ .Int = IntArg{ .name = name, .value = if (value) |v| @intCast(v) else undefined } };
        if (typing_utils.isFloat(T)) return Argument{ .Float = FloatArg{ .name = name, .value = if (value) |v| @floatCast(v) else undefined } };
        if (T == bool) return Argument{ .Bool = BoolArg{ .name = name, .value = value orelse undefined } };
        if (T == []const u8) return Argument{ .String = StringArg{ .name = name, .value = value orelse undefined } };
        return errors.ParserError.InvalidRawType;
    }

    pub fn getName(self: *const Argument) []const u8 {
        return switch (self.*) {
            .Bool => self.Bool.name,
            .Int => self.Int.name,
            .Float => self.Float.name,
            .String => self.String.name,
        };
    }

    pub fn setParsed(self: *Argument) void {
        switch (self.*) {
            .Bool => self.Bool.parsed = true,
            .Int => self.Int.parsed = true,
            .Float => self.Float.parsed = true,
            .String => self.String.parsed = true,
        }
    }

    pub fn parsed(self: *const Argument) bool {
        return switch (self.*) {
            .Bool => self.Bool.parsed,
            .Int => self.Int.parsed,
            .Float => self.Float.parsed,
            .String => self.String.parsed,
        };
    }

    pub fn setValue(self: *Argument, value: anytype) !void {
        const T = @TypeOf(value);
        if (typing_utils.isInteger(T)) {
            self.Int.value = @intCast(value);
        } else if (typing_utils.isFloat(T)) {
            self.Float.value = @floatCast(value);
        } else if (T == bool) {
            self.Bool.value = value;
        } else if (T == []const u8) {
            self.String.value = value;
        } else return errors.ParserError.InvalidRawType;
    }

    fn parseFlag(self: *Argument, text: []const u8) errors.ParserError!ParsingResult {
        if (text.len < 3)
            return ParsingResult.NotParsed;
        const fmt_name = self.getName();
        if (std.mem.eql(u8, text[2..], fmt_name)) {
            try self.setValue(true);
            return ParsingResult.Parsed;
        }

        return ParsingResult.NotParsed;
    }

    fn parseOptional(self: *Argument, text: []const u8) errors.ParserError!ParsingResult {
        if (text.len < 3)
            return ParsingResult.NotParsed;

        const fmt_name = self.getName();
        if (!std.mem.eql(u8, text[2..], fmt_name)) {
            return ParsingResult.NotParsed;
        }

        return ParsingResult.Parsed;
    }

    fn parsePositional(self: *Argument, text: []const u8) errors.ParserError!ParsingResult {
        try self.parseValueFromString(text);
        return ParsingResult.Parsed;
    }

    pub fn parseValueFromString(self: *Argument, text: []const u8) errors.ParserError!void {
        switch (self.*) {
            .Int => {
                try self.setValue(std.fmt.parseInt(i64, text, 10) catch return errors.ParserError.InvalidRawType);
            },
            .Float => {
                try self.setValue(std.fmt.parseFloat(f64, text) catch return errors.ParserError.InvalidRawType);
            },
            .String => {
                try self.setValue(text);
            },
            .Bool => {
                if (std.mem.eql(u8, text, "yes") or std.mem.eql(u8, text, "1") or std.mem.eql(u8, text, "on") or std.mem.eql(u8, text, "true")) {
                    try self.setValue(true);
                } else if (std.mem.eql(u8, text, "no") or std.mem.eql(u8, text, "0") or std.mem.eql(u8, text, "off") or std.mem.eql(u8, text, "false")) {
                    try self.setValue(false);
                } else return errors.ParserError.InvalidRawType;
            },
        }
    }

    pub fn parseString(self: *Argument, text: []const u8, role: ArgumentRole) errors.ParserError!ParsingResult {
        if (self.parsed())
            return ParsingResult.AlreadyParsed;

        const ret = switch (role) {
            .Positional => self.parsePositional(text),
            .Flag => self.parseFlag(text),
            .Optional => self.parseOptional(text),
        } catch |err| return err;

        if (ret == ParsingResult.Parsed)
            self.setParsed();

        return ret;
    }
};

pub const ArgumentRole = enum { Positional, Flag, Optional };
pub const ArgumentOptions = struct {
    role: ArgumentRole,
};
