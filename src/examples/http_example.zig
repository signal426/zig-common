const std = @import("std");
const common = @import("common");
const http = std.http;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var http_client = try common.http.Client.init(gpa.allocator(), "https://httpbin.org");
    defer http_client.deinit();

    var headers = std.ArrayList(http.Header).init(gpa.allocator());
    defer headers.deinit();

    try headers.append(common.http.contentTypeJSONHeader);
    const request = common.http.Request.newGet("/get", headers.items);

    const response = try http_client.send(request);

    std.debug.print("Status: {d}\n", .{response.status});
}
