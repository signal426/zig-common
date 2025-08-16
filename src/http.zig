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

    // Sends an HTTP GET request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendGet(self: *Client, url: []const u8, headers: []const http.Header) !Response {
        var request = try Request.newGet(self.allocator, url, headers);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP PUT request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendPut(self: *Client, url: []const u8, headers: []const http.Header, body: []const u8) !Response {
        var request = try Request.newPut(self.allocator, url, headers, body);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP PATCH request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendPatch(self: *Client, url: []const u8, headers: []const http.Header, body: []const u8) !Response {
        var request = try Request.newPatch(self.allocator, url, headers, body);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP POST request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendPost(self: *Client, url: []const u8, headers: []const http.Header, body: []const u8) !Response {
        var request = try Request.newPost(self.allocator, url, headers, body);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP DELETE request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendDelete(self: *Client, url: []const u8, headers: []const http.Header) !Response {
        var request = try Request.newDelete(self.allocator, url, headers);
        defer request.deinit();
        return try self.send(request);
    }
};

/// HTTP request object
pub const Request = struct {
    method: http.Method,
    url: []const u8,
    body: []const u8,
    headers: Headers,
    ignore_res_body: bool = false,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
    }

    pub fn newGet(allocator: std.mem.Allocator, url: []const u8, headers: []const http.Header) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .GET,
            .url = url,
            .body = "",
            .allocator = allocator,
        };
    }

    pub fn newPost(allocator: std.mem.Allocator, url: []const u8, headers: []const http.Header, body: []const u8) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .POST,
            .url = url,
            .body = body,
            .allocator = allocator,
        };
    }

    pub fn newPatch(allocator: std.mem.Allocator, url: []const u8, headers: []const http.Header, body: []const u8) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .PATCH,
            .url = url,
            .body = body,
            .allocator = allocator,
        };
    }

    pub fn newPut(allocator: std.mem.Allocator, url: []const u8, headers: []const http.Header, body: []const u8) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .PUT,
            .url = url,
            .body = body,
            .allocator = allocator,
        };
    }

    pub fn newDelete(allocator: std.mem.Allocator, url: []const u8, headers: []const http.Header) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .DELETE,
            .url = url,
            .body = "",
            .ignore_res_body = true,
        };
    }

    /// Convert the request to HTTP client options
    fn toOptions(self: Request, body: *std.ArrayList(u8)) !http.Client.FetchOptions {
        // determine response storage type based on request
        const storage: http.Client.FetchOptions.ResponseStorage =
            if (self.ignore_res_body)
                .{ .ignore = {} }
            else
                .{ .dynamic = body };

        return .{
            .method = self.method,
            .location = .{ .url = self.url },
            .headers = self.headers.base,
            .extra_headers = self.headers.extras,
            .payload = if (self.body.len == 0) null else self.body,
            .response_storage = storage,
        };
    }
};

/// HTTP response object
pub const Response = struct {
    status: http.Status,
    body: ?[]u8 = null,
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *Response) void {
        if (self.body) |body| {
            self.allocator.?.free(body);
            self.body = null;
        }
    }
};

/// Allows for using a single list to describe
/// both base (if necessary) and extra headers.
const Headers = struct {
    extras: []http.Header,
    base: http.Client.Request.Headers = .{},
    allocator: std.mem.Allocator,

    /// Initializes from the single list of headers
    pub fn init(allocator: std.mem.Allocator, all: []const http.Header) !Headers {
        var out = std.ArrayList(http.Header).init(allocator);
        errdefer out.deinit();
        const base = try processHeaders(all, &out);
        return .{
            .allocator = allocator,
            .extras = try out.toOwnedSlice(),
            .base = base,
        };
    }

    pub fn deinit(self: *Headers) void {
        self.allocator.free(self.extras);
    }

    fn processHeaders(all: []const http.Header, out: *std.ArrayList(http.Header)) !http.Client.Request.Headers {
        var res: http.Client.Request.Headers = .{};
        var has_ct: bool = false;
        for (all) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "host")) {
                res.host = .{ .override = header.value };
            } else if (std.ascii.eqlIgnoreCase(header.name, "authorization")) {
                res.authorization = .{ .override = header.value };
            } else if (std.ascii.eqlIgnoreCase(header.name, "user-agent")) {
                res.user_agent = .{ .override = header.value };
            } else if (std.ascii.eqlIgnoreCase(header.name, "connection")) {
                res.connection = .{ .override = header.value };
            } else if (std.ascii.eqlIgnoreCase(header.name, "accept-encoding")) {
                res.accept_encoding = .{ .override = header.value };
            } else if (std.ascii.eqlIgnoreCase(header.name, "content-type")) {
                has_ct = true;
                res.content_type = .{ .override = header.value };
            } else {
                try out.append(.{ .name = header.name, .value = header.value });
            }
        }
        // if no content-type header included, default to json
        if (!has_ct) {
            try out.append(contentTypeJSONHeader);
        }
        return res;
    }
};

/// HTTP header for content type JSON
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
