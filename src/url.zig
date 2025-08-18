const std = @import("std");

/// For building complex URLs
pub const Builder = struct {
    base: []const u8,
    path: ?[]const u8 = null,
    query: Query,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base: []const u8) Builder {
        return .{
            .base = base,
            .allocator = allocator,
            .query = Query.init(allocator),
        };
    }

    pub fn deinit(self: *Builder) void {
        self.query.deinit();
    }

    /// Sets the path on the URL
    pub fn setPath(self: *Builder, path: []const u8) !void {
        self.path = path;
    }

    /// Adds a query string parameter to be built into the URL
    pub fn addQueryParam(self: *Builder, key: []const u8, val: []const u8) !void {
        try self.query.add(key, val);
    }

    /// Builds the URL into the supplied buffer, returns a URL string
    pub fn buildInto(self: *Builder, buf: []u8) ![]u8 {
        var url = std.ArrayList(u8).init(self.allocator);
        defer url.deinit();
        try url.appendSlice(self.base);
        if (self.path) |path| {
            try url.appendSlice(path);
        }
        const query = try self.query.build(self.allocator);
        if (query.len != 0) {
            defer self.allocator.free(query);
            try url.appendSlice(query);
        }
        const owned = try url.toOwnedSlice();
        defer self.allocator.free(owned);
        return try std.fmt.bufPrint(buf, "{s}", .{owned});
    }
};

/// Query string builder
pub const Query = struct {
    list: std.ArrayList(Param),
    const Param = struct { k: []const u8, v: []const u8 };

    pub fn init(allocator: std.mem.Allocator) Query {
        return .{ .list = std.ArrayList(Param).init(allocator) };
    }

    pub fn deinit(self: *Query) void {
        self.list.deinit();
    }

    /// Add a key-value pair to the query string.
    pub fn add(self: *Query, k: []const u8, v: []const u8) !void {
        try self.list.append(.{ .k = k, .v = v });
    }

    /// Build the query string.
    pub fn build(self: *Query, allocator: std.mem.Allocator) ![]u8 {
        // return empty list if no items
        if (self.list.items.len == 0) return allocator.alloc(u8, 0);
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try buf.append('?');
        for (self.list.items, 0..) |param, i| {
            if (i > 0) try buf.append('&');
            try urlEncodeInto(&buf, param.k);
            try buf.append('=');
            try urlEncodeInto(&buf, param.v);
        }
        return buf.toOwnedSlice();
    }
};

/// Encode the given string into the URL-encoded format
fn urlEncodeInto(buf: *std.ArrayList(u8), s: []const u8) !void {
    for (s) |c| {
        if (!shouldPercentEncode(c)) {
            try buf.append(c);
        } else {
            try buf.append('%');
            try buf.writer().print("{s}", .{std.fmt.fmtSliceHexUpper(&[_]u8{c})});
        }
    }
}

/// Check if unreserved character for URL encoding
fn shouldPercentEncode(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => false,
        else => true,
    };
}
