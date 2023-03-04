const std = @import("std");
const builtin = @import("builtin");
const http = @import("mango_pie");
const signal = @import("signal");
const flag = @import("flag");

var global_running = std.atomic.Atomic(bool).init(true);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
    defer std.debug.assert(!gpa.deinit());
    const alloc = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    //

    signal.listenFor(std.os.linux.SIG.INT, handle_sig);
    signal.listenFor(std.os.linux.SIG.TERM, handle_sig);

    //

    try flag.addSingle("root");
    try flag.addSingle("public");
    try flag.addSingle("port");

    _ = try flag.parse(.double);
    try flag.parseEnv();

    //

    // Create the server socket
    const listen_port = try std.fmt.parseUnsigned(u16, flag.getSingle("port") orelse "8000", 10);
    const server_fd = try http.createSocket(listen_port);
    std.log.info("starting server on port {d}", .{listen_port});

    // Create the server
    var server: http.Server = undefined;
    try server.init(alloc, .{}, &global_running, server_fd, handleRequest);
    defer server.deinit();

    try server.run(std.time.ns_per_s);
}

fn handle_sig() void {
    std.log.info("exiting safely...", .{});
    global_running.store(false, .SeqCst);
}

fn handleRequest(per_request_allocator: std.mem.Allocator, peer: http.Peer, res_writer: http.ResponseWriter, req: http.Request) anyerror!http.Response {
    _ = per_request_allocator;

    std.log.debug("IN HANDLER addr={} method: {s}, path: {s}, body: \"{?s}\"", .{ peer.addr, @tagName(req.method), req.path, req.body });

    try res_writer.writeAll("Hello, World in handler!\n");
    return http.Response{
        .response = .{
            .status_code = .ok,
            .headers = &.{},
        },
    };
}
