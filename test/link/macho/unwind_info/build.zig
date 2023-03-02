const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");

    testUnwindInfo(b, test_step, optimize, target, false);
    testUnwindInfo(b, test_step, optimize, target, true);
}

fn testUnwindInfo(
    b: *std.Build,
    test_step: *std.Build.Step,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
    dead_strip: bool,
) void {
    const exe = createScenario(b, optimize, target);
    exe.link_gc_sections = dead_strip;

    const check = exe.checkObject(.macho);
    check.checkStart("segname __TEXT");
    check.checkNext("sectname __gcc_except_tab");
    check.checkNext("sectname __unwind_info");

    switch (builtin.cpu.arch) {
        .aarch64 => {
            check.checkNext("sectname __eh_frame");
        },
        .x86_64 => {}, // We do not expect `__eh_frame` section on x86_64 in this case
        else => unreachable,
    }

    check.checkInSymtab();
    check.checkNext("{*} (__TEXT,__text) external ___gxx_personality_v0");

    const run_cmd = check.runAndCompare();
    run_cmd.expectStdOutEqual(
        \\Constructed: a
        \\Constructed: b
        \\About to destroy: b
        \\About to destroy: a
        \\Error: Not enough memory!
        \\
    );

    test_step.dependOn(&run_cmd.step);
}

fn createScenario(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) *std.Build.CompileStep {
    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    b.default_step.dependOn(&exe.step);
    exe.addIncludePath(".");
    exe.addCSourceFiles(&[_][]const u8{
        "main.cpp",
        "simple_string.cpp",
        "simple_string_owner.cpp",
    }, &[0][]const u8{});
    exe.linkLibCpp();
    return exe;
}