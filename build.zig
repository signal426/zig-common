const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const common_mod = b.addModule("common", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const build_examples = b.option(bool, "examples", "Build example binaries") orelse false;

    if (build_examples) {
        // Add example binaries here
        const httpex = b.addExecutable(.{
            .name = "example_http",
            .root_source_file = b.path("src/examples/http_example.zig"),
            .target = target,
            .optimize = optimize,
        });

        httpex.root_module.addImport("common", common_mod);
        b.installArtifact(httpex);
    }
}
