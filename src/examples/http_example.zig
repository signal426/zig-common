const std = @import("std");
const common = @import("common");
const http = std.http;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var http_client = try common.http.Client.init(gpa.allocator());
    defer http_client.deinit();

    const request = common.http.Request.newGet("https://httpbin.org/get");

    // make sure to deinit the response
    var response = try http_client.send(request);
    defer response.deinit();

    std.debug.print("Status: {d}, Body: {?s}\n", .{ response.status, response.body });
}
