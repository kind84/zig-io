const std = @import("std");
const Slide = @import("../core/slide.zig").Slide;
const ImageFormat = @import("../core/slide.zig").ImageFormat;
const TIFFMetadata = @import("./metadata.zig").TIFFMetadata;
const TIFFBlockInfo = @import("./utils.zig").TIFFBlockInfo;

pub const TIFFSlide = @This();

metadata: []TIFFMetadata,
blockInfos: []TIFFBlockInfo,

/// file descriptor for write instructions (we use the low level system call
/// 'open', like LibTIFF does)
in: usize,

blockOffsets: u64,
blockByteCounts: u64,
compression: u16,

// readEncoded: TIFFReadEncoded,

pub fn init(path: []const u8, allocator: std.mem.Allocator) !TIFFSlide {
    var tiff_slide = TIFFSlide{
        .metadata = undefined,
        .in = undefined,
        .blockInfos = undefined,
        .blockOffsets = undefined,
        .blockByteCounts = undefined,
        .compression = undefined,
    };

    try tiff_slide.openFromSingleFile(path, allocator);

    return tiff_slide;
}

pub fn slide(self: *TIFFSlide) Slide {
    return Slide.init(self, open);
}

pub fn open(self: *TIFFSlide, path: []const u8, allocator: std.mem.Allocator) !void {
    // Check if path is a directory
    if (std.fs.openDirAbsolute(path, .{})) |dir| {
        _ = dir;

        // Check if subfolders match channels
        // TODO

    } else |err| {
        if (err == std.fs.Dir.OpenError.NotDir) {
            try self.openFromSingleFile(path, allocator);
        } else return err;
    }
}

fn openFromSingleFile(
    self: *TIFFSlide,
    path: []const u8,
    allocator: std.mem.Allocator,
) !void {
    var m = try TIFFMetadata.provide(allocator, path);
    self.metadata = &[_]TIFFMetadata{m};

    // TODO: define the layout
    if (m.imageFormat == ImageFormat.DP200) {
        // Ventana DP200 with overlaps
    } else {
        // regular grid layout
    }

    self.blockInfos = try m.addBlock();
}
