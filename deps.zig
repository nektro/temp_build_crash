const std = @import("std");
const builtin = @import("builtin");
const string = []const u8;
const ModuleDependency = std.build.ModuleDependency;

pub const cache = ".zigmod/deps";

pub fn addAllTo(exe: *std.build.LibExeObjStep) void {
    checkMinZig(builtin.zig_version, exe);
    @setEvalBranchQuota(1_000_000);

    for (packages) |pkg| {
        const moddep = pkg.zp(exe.builder);
        exe.addModule(moddep.name, moddep.module);
    }
    var llc = false;
    var vcpkg = false;
    inline for (comptime std.meta.declarations(package_data)) |decl| {
        const pkg = @as(Package, @field(package_data, decl.name));
        for (pkg.system_libs) |item| {
            exe.linkSystemLibrary(item);
            llc = true;
        }
        for (pkg.frameworks) |item| {
            if (!std.Target.current.isDarwin()) @panic(exe.builder.fmt("a dependency is attempting to link to the framework {s}, which is only possible under Darwin", .{item}));
            exe.linkFramework(item);
            llc = true;
        }
        inline for (pkg.c_include_dirs) |item| {
            exe.addIncludePath(@field(dirs, decl.name) ++ "/" ++ item);
            llc = true;
        }
        inline for (pkg.c_source_files) |item| {
            exe.addCSourceFile(@field(dirs, decl.name) ++ "/" ++ item, pkg.c_source_flags);
            llc = true;
        }
        vcpkg = vcpkg or pkg.vcpkg;
    }
    if (llc) exe.linkLibC();
    if (builtin.os.tag == .windows and vcpkg) exe.addVcpkgPaths(.static) catch |err| @panic(@errorName(err));
}

pub const Package = struct {
    directory: string,
    pkg: ?Pkg = null,
    c_include_dirs: []const string = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
    frameworks: []const string = &.{},
    vcpkg: bool = false,
    module: ?ModuleDependency = null,

    pub fn zp(self: *Package, b: *std.build.Builder) ModuleDependency {
        var temp: [100]ModuleDependency = undefined;
        const pkg = self.pkg.?;
        for (pkg.dependencies, 0..) |item, i| {
            temp[i] = item.zp(b);
        }
        if (self.module) |mod| {
            return mod;
        }
        const result = ModuleDependency{
            .name = pkg.name,
            .module = b.createModule(.{
                .source_file = pkg.source,
                .dependencies = b.allocator.dupe(ModuleDependency, temp[0..pkg.dependencies.len]) catch @panic("oom"),
            }),
        };
        self.module = result;
        return result;
    }
};

pub const Pkg = struct {
    name: string,
    source: std.build.FileSource,
    dependencies: []const *Package,
};

fn checkMinZig(current: std.SemanticVersion, exe: *std.build.LibExeObjStep) void {
    const min = std.SemanticVersion.parse("0.11.0-dev.1845+e0d390463") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.builder.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ current, min }));
}

pub const dirs = struct {
    pub const _root = "";
    pub const _m80ujped5ccg = cache ++ "/../..";
    pub const _857d9y0ezv9l = cache ++ "/git/github.com/nektro/mango_pie";
    pub const _f7dubzb7cyqe = cache ++ "/git/github.com/nektro/zig-extras";
    pub const _e8pdn6ebq6rk = cache ++ "/git/github.com/nektro/zig-signal";
    pub const _pm68dn67ppvl = cache ++ "/git/github.com/nektro/zig-flag";
    pub const _tnj3qf44tpeq = cache ++ "/git/github.com/nektro/zig-range";
};

pub const package_data = struct {
    pub var _m80ujped5ccg = Package{
        .directory = dirs._m80ujped5ccg,
    };
    pub var _f7dubzb7cyqe = Package{
        .directory = dirs._f7dubzb7cyqe,
        .pkg = Pkg{ .name = "extras", .source = .{ .path = dirs._f7dubzb7cyqe ++ "/src/lib.zig" }, .dependencies = &.{} },
    };
    pub var _857d9y0ezv9l = Package{
        .directory = dirs._857d9y0ezv9l,
        .pkg = Pkg{ .name = "mango_pie", .source = .{ .path = dirs._857d9y0ezv9l ++ "/src/lib.zig" }, .dependencies = &.{&_f7dubzb7cyqe} },
    };
    pub var _e8pdn6ebq6rk = Package{
        .directory = dirs._e8pdn6ebq6rk,
        .pkg = Pkg{ .name = "signal", .source = .{ .path = dirs._e8pdn6ebq6rk ++ "/signal.zig" }, .dependencies = &.{} },
        .system_libs = &.{"c"},
    };
    pub var _tnj3qf44tpeq = Package{
        .directory = dirs._tnj3qf44tpeq,
        .pkg = Pkg{ .name = "range", .source = .{ .path = dirs._tnj3qf44tpeq ++ "/src/lib.zig" }, .dependencies = &.{} },
    };
    pub var _pm68dn67ppvl = Package{
        .directory = dirs._pm68dn67ppvl,
        .pkg = Pkg{ .name = "flag", .source = .{ .path = dirs._pm68dn67ppvl ++ "/src/lib.zig" }, .dependencies = &.{ &_f7dubzb7cyqe, &_tnj3qf44tpeq } },
    };
    pub var _root = Package{
        .directory = dirs._root,
    };
};

pub const packages = &[_]Package{
    package_data._857d9y0ezv9l,
    package_data._e8pdn6ebq6rk,
    package_data._pm68dn67ppvl,
};

pub const pkgs = struct {
    pub const mango_pie = package_data._857d9y0ezv9l;
    pub const signal = package_data._e8pdn6ebq6rk;
    pub const flag = package_data._pm68dn67ppvl;
};

pub const imports = struct {};
