const std = @import("std");

pub inline fn isInteger(T: type) bool {
    if (T == comptime_int) return true;
    return switch (@typeInfo(T)) {
        .int => true,
        else => false,
    };
}
pub inline fn isFloat(T: type) bool {
    if( T == comptime_float) return true;
    return switch (@typeInfo(T)) {
        .float => true,
        else => false,
    };
}
