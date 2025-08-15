const std = @import("std");
const http = std.http;

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
    pub fn build(self: *Query, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        if (self.list.items.len == 0) {
            return allocator.dupe(u8, "") catch unreachable;
        }
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

/// Wrapper around std.http.Client
pub const Client = struct {
    client: http.Client,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Client {
        return .{
            .client = http.Client{ .allocator = allocator },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Client) void {
        self.client.deinit();
    }

    /// Send an HTTP request and return the response.
    pub fn send(self: *Client, request: Request) !Response {
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        // create fetch options from the request object
        const options = try request.toOptions(&body);
        const fetch_response = try self.client.fetch(options);
        if (request.ignore_res_body) {
            return .{ .status = fetch_response.status, .body = null };
        }

        // fetch appended response into body
        const owned = try body.toOwnedSlice();
        return .{ .status = fetch_response.status, .body = owned, .allocator = self.allocator };
    }
};

/// HTTP request object
pub const Request = struct {
    method: http.Method,
    url: []const u8,
    extra_headers: []http.Header = &.{},
    body: []const u8,
    ignore_res_body: bool = false,

    pub fn newGet(url: []const u8) Request {
        return .{
            .method = .GET,
            .url = url,
            .body = "",
        };
    }

    pub fn newPost(url: []const u8, body: []const u8) Request {
        return .{
            .method = .POST,
            .url = url,
            .body = body,
        };
    }

    pub fn newPut(url: []const u8, body: []const u8) Request {
        return .{
            .method = .PUT,
            .url = url,
            .body = body,
        };
    }

    pub fn newDelete(url: []const u8) Request {
        return .{
            .method = .DELETE,
            .url = url,
            .body = "",
            .ignore_res_body = true,
        };
    }

    /// Convert the request to HTTP client options
    pub fn toOptions(self: Request, body: *std.ArrayList(u8)) !http.Client.FetchOptions {
        // determine response storage type based on request
        const storage: http.Client.FetchOptions.ResponseStorage =
            if (self.ignore_res_body)
                .{ .ignore = {} }
            else
                .{ .dynamic = body };

        return .{
            .method = self.method,
            .location = .{ .url = self.url },
            .headers = .{ .content_type = .{ .override = "application/json" } },
            .extra_headers = self.extra_headers,
            .payload = if (self.body.len == 0) null else self.body,
            .response_storage = storage,
        };
    }
};

/// HTTP response object
pub const Response = struct {
    status: http.Status,
    body: ?[]const u8 = null,
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *Response) void {
        if (self.body) |body| {
            self.allocator.?.free(body);
            self.body = null;
        }
    }
};

/// HTTP header for content type JSON
/// TODO: add more headers
pub const contentTypeJSONHeader = http.Header{ .name = "Content-Type", .value = "application/json" };

/// Encode the given string into the URL-encoded format
fn urlEncodeInto(buf: *std.ArrayList(u8), s: []const u8) !void {
    for (s) |c| {
        if (!percentEncode(c)) {
            try buf.append(c);
        } else {
            try buf.append('%');
            try buf.writer().print("{s}", .{std.fmt.fmtSliceHexUpper(&[_]u8{c})});
        }
    }
}

/// Check if unreserved character for URL encoding
fn percentEncode(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => false,
        else => true,
    };
}
