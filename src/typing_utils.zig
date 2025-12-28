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
