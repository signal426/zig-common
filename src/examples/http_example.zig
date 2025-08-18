const std = @import("std");
const common = @import("common");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // construct http client
    var http_client = try common.http.Client.init(allocator);
    defer http_client.deinit();

    // optionally add headers
    var hdrs = std.ArrayList(std.http.Header).init(allocator);
    defer hdrs.deinit();
    try hdrs.append(.{ .name = "test-me", .value = "test-you" });

    var urlb = common.url.Builder.init(allocator, "https://httpbin.org");
    defer urlb.deinit();

    try urlb.setPath("/get");
    try urlb.addQueryParam("test", "param");

    var scratch: [256]u8 = undefined;
    const url = try urlb.buildInto(&scratch);

    // send request
    var response = try http_client.sendGet(url, hdrs.items);
    defer response.deinit();

    // access status and response body
    std.debug.print("Status: {d}, Body: {?s}\n", .{ response.status, response.body });
}
