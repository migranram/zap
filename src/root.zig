//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub inline fn isInteger(T: type) bool {
    return switch (@typeInfo(T)) {
        .int => true,
        else => false,
    };
}
pub inline fn isFloat(T: type) bool {
    return switch (@typeInfo(T)) {
        .float => true,
        else => false,
    };
}

pub inline fn checkType(T: type) void {
    std.debug.print("{} Int={} Float={}", .{ @typeInfo(T), isInteger(T), isFloat(T) });
}

pub fn doTypesCheckup() void {
    std.debug.print("Integers: ", .{});
    inline for (.{
        bool,
        u8,
        u16,
        u32,
        u64,
        i8,
        i16,
        i32,
        i64,
        f16,
        f32,
        f64,
        []const u8,
        [*]const u8,
        []u8,
    }) |T| {
        std.debug.print("\n -->", .{});
        checkType(T);
    }
    std.debug.print("\n", .{});
}
