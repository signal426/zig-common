const std = @import("std");

/// Creates a directory for the given path.
pub fn mkdir(path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var it = std.mem.splitScalar(u8, path, '/');
    var cur = std.ArrayList(u8).init(allocator);
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        try cur.appendSlice(dir);
        std.fs.cwd().makeDir(cur.items) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        try cur.append('/');
    }
}

/// Writes a file atomically.
pub fn atomicWrite(path: []const u8, bytes: []const u8) !void {
    var cwd = std.fs.cwd();
    var dir_path: []const u8 = path;

    // ignore trailing slash
    const last_slash: ?usize = std.mem.lastIndexOf(u8, path, '/');
    if (last_slash) |idx| dir_path = path[0..idx];

    // if there is a directory, try to create it
    if (dir_path.len > 0) try mkdir(dir_path);

    var tmp_name_buf: [64]u8 = undefined;
    const tmp_name = try std.fmt.bufPrint(&tmp_name_buf, ".{s}.tmp", .{std.fs.path.basename(path)});
    var dir = try cwd.openDir(dir_path, .{});
    defer dir.close();

    var f = try dir.createFile(tmp_name, .{});
    try f.write(bytes);
    try f.close();
    try dir.rename(tmp_name, std.fs.path.basename(path));
}
