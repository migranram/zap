const errors = @import("errors.zig");
const typing_utils = @import("typing_utils.zig");

fn BaseArg(T: type) type {
    return struct { name: []const u8, value: T = undefined };
}

const BoolArg = BaseArg(bool);
const IntArg = BaseArg(i32);
const FloatArg = BaseArg(f32);
const StringArg = BaseArg([]const u8);

pub const Argument = union(enum) {
    Bool: BoolArg,
    Int: IntArg,
    Float: FloatArg,
    String: StringArg,

    pub fn createFromType(name: []const u8, T: type, value: ?T) errors.ParserError!Argument {
        if (typing_utils.isInteger(T)) return Argument{ .Int = IntArg{ .name = name, .value = if (value) |v| @truncate(v) else undefined } };
        if (typing_utils.isFloat(T)) return Argument{ .Float = FloatArg{ .name = name, .value = if (value) |v| @floatCast(v) else undefined } };
        if (T == bool) return Argument{ .Bool = BoolArg{ .name = name, .value = value orelse undefined } };
        if (T == []const u8) return Argument{ .String = StringArg{ .name = name, .value = value orelse undefined } };
        return errors.ParserError.InvalidRawType;
    }
};

pub const ArgumentOptions = struct {
    role: enum { Positional, Flag, Optional },
};
