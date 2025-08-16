const std = @import("std");
const common = @import("common");
const http = std.http;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // construct http client
    var http_client = try common.http.Client.init(allocator);
    defer http_client.deinit();

    // optionally add headers
    var hdrs = std.ArrayList(http.Header).init(allocator);
    defer hdrs.deinit();
    try hdrs.append(.{ .name = "test-me", .value = "test-you" });

    // send request
    var response = try http_client.sendGet("https://httpbin.org/get", hdrs.items);
    defer response.deinit();

    // access status and response body
    std.debug.print("Status: {d}, Body: {?s}\n", .{ response.status, response.body });
}
