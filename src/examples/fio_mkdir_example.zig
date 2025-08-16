const std = @import("std");
const common = @import("common");

pub fn main() !void {
    try common.fio.mkdir("my/example/dir");
}
