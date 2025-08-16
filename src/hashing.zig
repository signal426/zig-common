const std = @import("std");

pub fn sha256HexAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    h.update(bytes);
    var digest: [32]u8 = undefined;
    h.final(&digest);
    return std.fmt.allocPrint(allocator, "{s}", .{std.fmt.fmtSliceHexLower(&digest)});
}
