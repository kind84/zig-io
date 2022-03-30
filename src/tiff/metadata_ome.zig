const std = @import("std");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const TIFF = @import("metadata.zig").TIFF;

pub const OMETIFFMetadata = @This();

pub fn init(dirs: []TIFFDirectoryData) ?OMETIFFMetadata {
    _ = dirs;
    return OMETIFFMetadata{};
}

pub fn addBlock(self: OMETIFFMetadata, tif: *TIFF) !void {
    _ = self;
    _ = tif;
    std.debug.print("Yay OMETIFF!\n", .{});
}
