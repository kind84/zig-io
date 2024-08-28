const std = @import("std");
const TIFFMetadata = @import("metadata.zig");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
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

pub fn addBlock(self: GenericTIFFMetadata, tif: *c.TIFF) !void {
    _ = self;
    _ = tif;
    std.debug.print("Yay Generic TIFF!\n", .{});
}
