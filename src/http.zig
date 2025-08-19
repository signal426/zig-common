const std = @import("std");

/// Wrapper around std.http.Client
pub const Client = struct {
    client: std.http.Client,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Client {
        return .{
            .client = std.http.Client{ .allocator = allocator },
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
    pub fn sendGet(self: *Client, url: []const u8, headers: ?[]const std.http.Header) !Response {
        var request = try Request.initGet(self.allocator, url, headers);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP PUT request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendPut(self: *Client, url: []const u8, headers: ?[]const std.http.Header, body: ?[]const u8) !Response {
        var request = try Request.initPut(self.allocator, url, headers, body);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP PATCH request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendPatch(self: *Client, url: []const u8, headers: ?[]const std.http.Header, body: ?[]const u8) !Response {
        var request = try Request.initPatch(self.allocator, url, headers, body);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP POST request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendPost(self: *Client, url: []const u8, headers: ?[]const std.http.Header, body: ?[]const u8) !Response {
        var request = try Request.initPost(self.allocator, url, headers, body);
        defer request.deinit();
        return try self.send(request);
    }

    // Sends an HTTP DELETE request to the specified location.
    // If no Content-type header supplied, defaults to JSON.
    pub fn sendDelete(self: *Client, url: []const u8, headers: ?[]const std.http.Header) !Response {
        var request = try Request.initDelete(self.allocator, url, headers);
        defer request.deinit();
        return try self.send(request);
    }
};

/// HTTP request object
pub const Request = struct {
    method: std.http.Method,
    url: []const u8,
    body: ?[]const u8 = null,
    headers: Headers,
    ignore_res_body: bool = false,

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
    }

    pub fn initGet(allocator: ?std.mem.Allocator, url: []const u8, headers: ?[]const std.http.Header) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .GET,
            .url = url,
        };
    }

    pub fn initPost(allocator: ?std.mem.Allocator, url: []const u8, headers: ?[]const std.http.Header, body: ?[]const u8) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .POST,
            .url = url,
            .body = body,
        };
    }

    pub fn initPatch(allocator: ?std.mem.Allocator, url: []const u8, headers: ?[]const std.http.Header, body: ?[]const u8) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .PATCH,
            .url = url,
            .body = body,
        };
    }

    pub fn initPut(allocator: ?std.mem.Allocator, url: []const u8, headers: ?[]const std.http.Header, body: ?[]const u8) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .PUT,
            .url = url,
            .body = body,
        };
    }

    pub fn initDelete(allocator: ?std.mem.Allocator, url: []const u8, headers: ?[]const std.http.Header) !Request {
        return .{
            .headers = try Headers.init(allocator, headers),
            .method = .DELETE,
            .url = url,
            .ignore_res_body = true,
        };
    }

    /// Convert the request to HTTP client options
    fn toOptions(self: Request, body: *std.ArrayList(u8)) !std.http.Client.FetchOptions {
        // determine response storage type based on request
        const storage: std.http.Client.FetchOptions.ResponseStorage =
            if (self.ignore_res_body)
                .{ .ignore = {} }
            else
                .{ .dynamic = body };

        return .{
            .method = self.method,
            .location = .{ .url = self.url },
            .headers = self.headers.base,
            .extra_headers = if (self.headers.extras) |extras| extras else &.{},
            .payload = if (self.body != null and self.body.?.len > 0) self.body else null,
            .response_storage = storage,
        };
    }
};

/// HTTP response object
pub const Response = struct {
    status: std.http.Status,
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
    extras: ?[]std.http.Header = null,
    base: std.http.Client.Request.Headers = .{},
    allocator: ?std.mem.Allocator = null,

    /// Initializes from the single list of headers
    pub fn init(allocator: ?std.mem.Allocator, all: ?[]const std.http.Header) !Headers {
        if (all == null) {
            return .{ .base = .{ .content_type = .{ .override = contentTypeJSONHeader.value } } };
        }
        var out = std.ArrayList(std.http.Header).init(allocator.?);
        errdefer out.deinit();
        const base = try processHeaders(all.?, &out);
        return .{
            .allocator = allocator.?,
            .extras = try out.toOwnedSlice(),
            .base = base,
        };
    }

    pub fn deinit(self: *Headers) void {
        if (self.extras) |extras| self.allocator.?.free(extras);
    }

    /// Sort base from additional headers, create appropriate objects to represent each
    fn processHeaders(all: []const std.http.Header, out: *std.ArrayList(std.http.Header)) !std.http.Client.Request.Headers {
        var res: std.http.Client.Request.Headers = .{};
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
            res.content_type = .{ .override = contentTypeJSONHeader.value };
        }
        return res;
    }
};

/// HTTP header for content type JSON
pub const contentTypeJSONHeader = std.http.Header{ .name = "Content-Type", .value = "application/json" };
