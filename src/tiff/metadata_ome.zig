const std = @import("std");
const xml = @import("../xml.zig");
const TIFFMetadata = @import("metadata.zig");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const Size3 = @import("../core/size.zig").Size3;
const c = @import("metadata.zig").C;

pub const OMETIFFMetadata = @This();

pub fn init(
    allocator: std.mem.Allocator,
    metadata: *TIFFMetadata,
    dirs: []TIFFDirectoryData,
) !?OMETIFFMetadata {
    if (dirs.len == 0) return null;

    // find the first full resolution IFD
    var d: usize = 0;
    while (d < dirs.len) : (d += 1) {
        if (dirs[d].subFileType == 0) break;
    }

    if (d == dirs.len) {
        // No full resolution IFDs found
        // check for an Ultivue-style ome-tiff
        if (dirs[0].subFileType == 0x2) {
            d = 0;
        } else return null;
    }

    var ifd0: TIFFDirectoryData = dirs[d];

    if (ifd0.nsamples < 1 or ifd0.nsamples > 3) {
        return null;
    }

    metadata.size = ifd0.size;

    // Find all the TIFFDirectoryData that represent an image
    // of a matching size & type
    var full_resolution_dirs = std.ArrayList(usize).init(allocator);
    for (dirs) |dir, i| {
        if (dir.subFileType == 0 and std.meta.eql(dir.size, metadata.size)) {
            try full_resolution_dirs.append(i);
        }
    }

    if (full_resolution_dirs.items.len == 0) {
        std.debug.print("No valid images in file\n", .{});
        return null;
    }

    var index: usize = undefined;
    if (std.mem.indexOf(u8, ifd0.description, "www.openmicroscopy.org/Schemas/OME/201")) |idx| {
        index = idx;
    } else {
        std.debug.print("No OME-Schema\n", .{});
        return null;
    }

    var date = ifd0.description[index + 35 .. index + 35 + 7];
    if (!std.mem.eql(u8, date, "2016-06") and !std.mem.eql(u8, date, "2013-06")) {
        std.debug.print("Unsupported OME-Schema\n", .{});
        return null;
    }

    return OMETIFFMetadata{};
}

pub fn addBlock(self: OMETIFFMetadata, tif: *c.TIFF) !void {
    _ = self;
    _ = tif;
    std.debug.print("Yay OMETIFF!\n", .{});
}
