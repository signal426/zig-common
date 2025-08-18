const std = @import("std");
const common = @import("common");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // construct http client
    var t = try std.time.Timer.start();
    var http_client = try common.http.Client.init(allocator);
    defer http_client.deinit();

    // optionally add headers
    var hdrs = std.ArrayList(std.http.Header).init(allocator);
    defer hdrs.deinit();
    try hdrs.append(.{ .name = "test-me", .value = "test-you" });

    // optionally use url builder
    var scratch: [256]u8 = undefined;
    var urlb = common.url.Builder.init(allocator, "https://httpbin.org");
    defer urlb.deinit();

    try urlb.setPath("get");
    try urlb.addQueryParam("test", "param");
    try urlb.addQueryParam("test2", "param2");

    // send request
    var response = try http_client.sendGet(try urlb.buildInto(&scratch), hdrs.items);
    defer response.deinit();

    const ns = t.read();

    // access status and response body
    std.debug.print("Took: {d} ms\nStatus: {d}\nBody: {?s}\n", .{ ns / 1_000_000, response.status, response.body });
}
