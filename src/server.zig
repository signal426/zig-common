const std = @import("std");
const http = @import("http.zig");

pub const HandlerFn = fn () anyerror!void;

pub const Route = struct {
    method: std.http.Method,
    path: []const u8,
    handler: *const HandlerFn(),
};

const Job = struct {
    conn: std.net.Server.Connection,
};

pub const ThreadPool = struct {
    allocator: std.mem.Allocator,
    workers: []std.Thread,
    mu: std.Thread.Mutex = .{},
    cv: std.Thread.Condition = .{},
    queue: std.ArrayList(Job),
    shutting_down: bool = false,
    server: *Server,

    pub fn init(allocator: std.mem.Allocator, server: *Server, n_workers: ?usize) !ThreadPool {
        const n = n_workers orelse @max(1, std.Thread.getCpuCount() catch 4);
        var workers = try allocator.alloc(std.Thread, n);
        var pool = ThreadPool{
            .allocator = allocator,
            .workers = workers,
            .queue = std.ArrayList(allocator),
            .server = server,
        };
        var i: usize = 0;
        while (i < n) {
            workers[i] = try std.Thread.spawn(.{}, workerMain, .{&pool});
            i += 1;
        }
    }

    fn workerMain(pool: *ThreadPool) void {
        while (true) {
            var job: ?Job = null;
            pool.mu.lock();
            while (pool.queue.items.len == 0 and !pool.shutting_down) {
                pool.cv.wait(&pool.mu);
            }
            if (pool.shutting_down) {
                pool.mu.unlock();
                break;
            }
            job = pool.queue.pop();
            if (job) |j| {

            }
        }
    }
};

const Request = struct {
    method: std.http.Method = std.http.Method.GET,
    target: []const u8,
    headers: std.ArrayList(std.http.Header),
    body: []u8,

    fn init(allocator: std.mem.Allocator) !Request {
        return .{
            .headers = std.ArrayList(std.http.Header).init(allocator),  
            .target = &[_]u8{},
        };
    }
};

const Response = struct {
    status: u16 = 200,
    headers: std.ArrayList(std.http.Header),
    body: []u8,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    request: Request,
    response: Response,
};

fn handleConnection(server: *Server, connection: std.net.Server.Connection) !void {
    defer connection.stream.close();
    var buffered_reader = std.io.bufferedReader(connection.stream.reader());
    var buffered_writer = std.io.bufferedWriter(connection.stream.writer());

    const reader = buffered_reader.reader();
    const writer = buffered_writer.writer();
}


pub const Server = struct {
};


