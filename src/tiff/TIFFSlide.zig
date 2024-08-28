const std = @import("std");
const Slide = @import("../core/slide.zig").Slide;
const ImageFormat = @import("../core/slide.zig").ImageFormat;
const TIFFMetadata = @import("./metadata.zig").TIFFMetadata;
const TIFFDirectoryData = @import("./utils.zig").TIFFDirectoryData;
const TIFFBlockInfo = @import("./utils.zig").TIFFBlockInfo;
const c = @import("./metadata.zig").C;

pub const TIFFSlide = @This();

imageFormat: ImageFormat,
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
        .imageFormat = undefined,
        .metadata = undefined,
        .in = undefined,
        .blockInfos = undefined,
        .blockOffsets = undefined,
        .blockByteCounts = undefined,
        .compression = undefined,
    };

    try tiff_slide.open(path, allocator);

    return tiff_slide;
}

pub fn slide(self: *TIFFSlide) Slide {
    return Slide.init(self, self.imageFormat, open);
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

    std.debug.print("{any}\n", .{self.blockInfos});
    var tif = self.blockInfos[0].tif;
    if (c.TIFFCurrentDirectory(tif) != self.blockInfos[0].dir) {
        _ = c.TIFFSetDirectory(tif, @intCast(c_ushort, self.blockInfos[0].dir));
    }

    var tiff_dir_data = try TIFFDirectoryData.init(allocator, tif);

    if (c.TIFFIsTiled(tif) == 1) {
        if (tiff_dir_data.compression == c.COMPRESSION_JPEG and tiff_dir_data.photometric == c.PHOTOMETRIC_YCBCR) {
            if (self.imageFormat == ImageFormat.DP200) {
                // readEncoded = new TiffReadEncodedDP200(this, metadata[0]);
            } else {
                // readEncoded = new TiffReadEncodedJpeg(this);
            }
        } else { // not jpeg
            // readEncoded = new TiffReadEncodedTile;
        }
    } else { // not tiled
        // readEncoded = new TiffReadEncodedStrip;
    }

    self.compression = tiff_dir_data.compression;

    // resize RGBA buffer as required
    // if (compression == COMPRESSION_JPEG && photometric == PHOTOMETRIC_YCBCR) {
    //   Size3 maxBlock = layout_->maxBlockSize();
    //   RGBABuffer.resize((maxBlock.width * maxBlock.height * tiffDirData.nbits) /
    //                     8);
    // }
}

fn openFromSingleFile(
    self: *TIFFSlide,
    path: []const u8,
    allocator: std.mem.Allocator,
) !void {
    var m = try TIFFMetadata.provide(allocator, path);
    self.metadata = &[_]TIFFMetadata{m};
    self.imageFormat = m.imageFormat;

    // TODO: define the layout
    if (m.imageFormat == ImageFormat.DP200) {
        // Ventana DP200 with overlaps
    } else {
        // regular grid layout
    }

    self.blockInfos = try m.addBlock();
}
