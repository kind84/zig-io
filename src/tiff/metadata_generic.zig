const std = @import("std");
const TIFFMetadata = @import("metadata.zig");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const TIFFBlockInfo = @import("utils.zig").TIFFBlockInfo;
const c = @import("metadata.zig").C;

pub const GenericTIFFMetadata = @This();

pub fn init(
    allocator: std.mem.Allocator,
    metadata: *TIFFMetadata,
    dirs: []TIFFDirectoryData,
) !?GenericTIFFMetadata {
    _ = allocator;
    _ = metadata;
    _ = dirs;
    return GenericTIFFMetadata{};
}

pub fn deinit(self: GenericTIFFMetadata) void {
    _ = self;
}

pub fn addBlock(self: GenericTIFFMetadata, allocator: std.mem.Allocator) ![]TIFFBlockInfo {
    _ = self;
    _ = allocator;
    std.debug.print("Yay Generic TIFF!\n", .{});
    return &[_]TIFFBlockInfo{};
}
