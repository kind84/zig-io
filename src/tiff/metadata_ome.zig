const std = @import("std");
const TIFFMetadata = @import("metadata.zig");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const c = @import("metadata.zig").C;

pub const OMETIFFMetadata = @This();

pub fn init(metadata: *TIFFMetadata, dirs: []TIFFDirectoryData) ?OMETIFFMetadata {
    if (dirs.len == 0) return null;

    var ifd0: TIFFDirectoryData = undefined;
    for (dirs) |dir| {
        if (dir.subFileType == 0) {
            ifd0 = dir;
        }
    }

    if (ifd0.nsamples < 1 or ifd0.nsamples > 3) {
        return null;
    }

    metadata.size = ifd0.size;

    return OMETIFFMetadata{};
}

pub fn addBlock(self: OMETIFFMetadata, tif: *c.TIFF) !void {
    _ = self;
    _ = tif;
    std.debug.print("Yay OMETIFF!\n", .{});
}
