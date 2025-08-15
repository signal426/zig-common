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
    base_url: std.Uri,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !Client {
        return .{
            .client = http.Client{ .allocator = allocator },
            .base_url = try std.Uri.parse(ensureValidBaseURL(base_url)),
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
        const options = try request.toOptions(self.base_url, &body);
        const fetch_response = try self.client.fetch(options);
        if (!request.ignore_res_body and options.payload != null) {
            return .{
                .status = fetch_response.status,
                .body = options.payload,
            };
        } else {
            return .{
                .status = fetch_response.status,
                .body = null,
            };
        }
    }
};

/// HTTP request object
pub const Request = struct {
    method: http.Method,
    path: []const u8,
    headers: []http.Header,
    body: []const u8,
    ignore_res_body: bool,

    pub fn newGet(path: []const u8, headers: []http.Header) Request {
        return .{
            .method = .GET,
            .path = path,
            .headers = headers,
            .body = "",
            .ignore_res_body = false,
        };
    }

    pub fn newPost(path: []const u8, headers: []http.Header, body: []const u8) Request {
        return .{
            .method = .POST,
            .path = path,
            .headers = headers,
            .body = body,
            .ignore_res_body = false,
        };
    }

    pub fn newPut(path: []const u8, headers: []http.Header, body: []const u8) Request {
        return .{
            .method = .PUT,
            .path = path,
            .headers = headers,
            .body = body,
            .ignore_res_body = false,
        };
    }

    pub fn newDelete(path: []const u8, headers: []http.Header) Request {
        return .{
            .method = .DELETE,
            .path = path,
            .headers = headers,
            .body = "",
            .ignore_res_body = true,
        };
    }

    /// Convert the request to HTTP client options
    pub fn toOptions(self: Request, base_url: std.Uri, body: *std.ArrayList(u8)) !http.Client.FetchOptions {
        // combine base URL and path
        var fixed: [1024]u8 = undefined;
        var buf: []u8 = fixed[0..];
        const url = try base_url.resolve_inplace(self.path, &buf);

        // determine response storage type based on request
        const storage: http.Client.FetchOptions.ResponseStorage =
            if (self.ignore_res_body)
                .{ .ignore = {} }
            else
                .{ .dynamic = body };

        return .{
            .method = self.method,
            .location = .{ .uri = url },
            .extra_headers = self.headers,
            .payload = if (self.body.len == 0) null else self.body,
            .response_storage = storage,
        };
    }
};

/// HTTP response object
pub const Response = struct {
    status: http.Status,
    body: ?[]const u8 = null,
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
fn percentEncode(c: u8) !bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => true,
        else => false,
    };
}

/// Ensure the base URL does not end with a slash
fn ensureValidBaseURL(url: []const u8) []const u8 {
    if (url.len > 0 and url[url.len - 1] == '/') return url[0 .. url.len - 1];
    return url;
}

/// Ensure the URL path contains a leading slash
fn ensureLeadingSlash(allocator: std.mem.Allocator, path: []const u8) []const u8 {
    if (path.len == 0 or path[0] != '/') {
        return try std.mem.concat(allocator, u8, &.{ "/", path });
    }
    return try allocator.dupe(u8, path);
}
