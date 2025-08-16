const std = @import("std");

pub fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    var parsed = try std.json.parseFromSlice(T, allocator, bytes, .{});
    defer parsed.deinit();
    return parsed.value;
}

pub fn stringify(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    return std.json.stringifyAlloc(allocator, value, .{});
}
