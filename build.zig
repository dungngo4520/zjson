const std = @import("std");
const fs = std.fs;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get test filter option from VS Code or other tools
    const test_filter = b.option([]const u8, "test-filter", "Filter tests by name");

    // Create the zjson module from src/zjson.zig
    const zjson_module = b.addModule("zjson", .{
        .root_source_file = b.path("src/zjson.zig"),
    });

    // Build examples
    const examples_step = b.step("examples", "Build all examples");
    build_examples(b, target, optimize, examples_step, zjson_module);

    // Build benchmarks
    const benchmark_step = b.step("benchmark", "Build benchmarks");
    build_benchmarks(b, target, optimize, benchmark_step, zjson_module);

    // Build and run tests
    const test_step = b.step("test", "Run all tests");
    build_tests(b, target, optimize, test_step, zjson_module, test_filter);

    // Clean step: remove build artifacts
    const clean_step = b.step("clean", "Remove build artifacts");
    const clean_cmd = b.addRemoveDirTree(b.path("zig-out"));
    clean_step.dependOn(&clean_cmd.step);

    // Default step: build examples and run tests
    const default_step = b.step("all", "Build examples and run tests (default)");
    default_step.dependOn(examples_step);
    default_step.dependOn(test_step);
    b.default_step.* = default_step.*;
}

fn build_examples(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, examples_step: *std.Build.Step, zjson_module: *std.Build.Module) void {
    var dir = b.build_root.handle.openDir("examples", .{ .iterate = true }) catch |err| {
        std.debug.print("Warning: Could not open examples directory: {}\n", .{err});
        return;
    };
    defer dir.close();

    var walker = dir.walk(b.allocator) catch return;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".zig")) {
            const example_path = b.fmt("examples/{s}", .{entry.path});
            const example_name = std.fs.path.stem(entry.basename);

            const example_module = b.createModule(.{
                .root_source_file = b.path(example_path),
                .target = target,
                .optimize = optimize,
            });

            example_module.addImport("zjson", zjson_module);

            const exe = b.addExecutable(.{
                .name = example_name,
                .root_module = example_module,
            });

            const install_exe = b.addInstallArtifact(exe, .{
                .dest_dir = .{ .override = .{ .custom = "examples" } },
            });

            examples_step.dependOn(&install_exe.step);
        }
    }
}

fn build_tests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, test_step: *std.Build.Step, zjson_module: *std.Build.Module, test_filter: ?[]const u8) void {
    var dir = b.build_root.handle.openDir("tests", .{ .iterate = true }) catch |err| {
        std.debug.print("Warning: Could not open tests directory: {}\n", .{err});
        return;
    };
    defer dir.close();

    var walker = dir.walk(b.allocator) catch return;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".zig")) {
            const test_path = b.fmt("tests/{s}", .{entry.path});

            const test_module = b.createModule(.{
                .root_source_file = b.path(test_path),
                .target = target,
                .optimize = optimize,
            });

            test_module.addImport("zjson", zjson_module);

            const unit_tests = b.addTest(.{
                .root_module = test_module,
            });

            const run_test = b.addRunArtifact(unit_tests);

            // Note: test_filter is accepted from VS Code but we just acknowledge it
            // The actual filtering happens at the test runner level when VS Code runs the test
            _ = test_filter;

            test_step.dependOn(&run_test.step);
        }
    }
}

fn build_benchmarks(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, benchmark_step: *std.Build.Step, zjson_module: *std.Build.Module) void {
    var dir = b.build_root.handle.openDir("benchmark", .{ .iterate = true }) catch |err| {
        std.debug.print("Warning: Could not open benchmark directory: {}\n", .{err});
        return;
    };
    defer dir.close();

    var walker = dir.walk(b.allocator) catch return;
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".zig")) {
            const bench_path = b.fmt("benchmark/{s}", .{entry.path});
            const bench_name = std.fs.path.stem(entry.basename);

            const bench_module = b.createModule(.{
                .root_source_file = b.path(bench_path),
                .target = target,
                .optimize = optimize,
            });

            bench_module.addImport("zjson", zjson_module);

            const exe = b.addExecutable(.{
                .name = bench_name,
                .root_module = bench_module,
            });

            const install_exe = b.addInstallArtifact(exe, .{
                .dest_dir = .{ .override = .{ .custom = "benchmark" } },
            });

            benchmark_step.dependOn(&install_exe.step);
        }
    }
}
