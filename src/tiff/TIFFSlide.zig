const std = @import("std");
const BlockInfo = @import("../core/layout.zig").BlockInfo;
const Layout = @import("../core/layout.zig").Layout;
const Mat = @import("../core/mat.zig").Mat;
const Slide = @import("../core/slide.zig").Slide;
const ImageFormat = @import("../core/slide.zig").ImageFormat;
const TIFFMetadata = @import("./metadata.zig").TIFFMetadata;
const TIFFDirectoryData = @import("./utils.zig").TIFFDirectoryData;
const TIFFBlockInfo = @import("./utils.zig").TIFFBlockInfo;
const TIFFEncodedReader = @import("./TIFFEncodedReader.zig").TIFFEncodedReader;
const c = @import("./metadata.zig").C;

pub const TIFFSlide = @This();

imageFormat: ImageFormat,
metadata: []const TIFFMetadata,
blockInfos: []TIFFBlockInfo,
slideLayout: Layout,

/// file descriptor for write instructions (we use the low level system call
/// 'open', like LibTIFF does)
in: usize,

blockOffsets: u64,
blockByteCounts: u64,
compression: u16,

reader: TIFFEncodedReader,

pub fn init(path: []const u8, allocator: std.mem.Allocator) !*TIFFSlide {
    var tiff_slide = TIFFSlide{
        .slideLayout = undefined,
        .imageFormat = undefined,
        .metadata = undefined,
        .in = undefined,
        .blockInfos = undefined,
        .blockOffsets = undefined,
        .blockByteCounts = undefined,
        .compression = undefined,
        .reader = undefined,
    };

    try tiff_slide.open(path, allocator);

    return &tiff_slide;
}

pub fn deinit(self: *const TIFFSlide) void {
    for (self.metadata) |*m| {
        m.*.deinit();
    }
}

pub fn slide(self: *TIFFSlide) Slide {
    return Slide.init(self, self.imageFormat, open, readBlockFromFile, layout);
}

pub fn layout(self: *TIFFSlide) *Layout {
    return &self.slideLayout;
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
    const tif = self.blockInfos[0].tif;
    if (c.TIFFCurrentDirectory(tif) != self.blockInfos[0].dir) {
        const c_dir: c_ushort = @intCast(self.blockInfos[0].dir);
        _ = c.TIFFSetDirectory(tif, c_dir);
    }

    const tiff_dir_data = try TIFFDirectoryData.init(allocator, tif);

    if (c.TIFFIsTiled(tif) == 1) {
        if (tiff_dir_data.compression == c.COMPRESSION_JPEG and tiff_dir_data.photometric == c.PHOTOMETRIC_YCBCR) {
            if (self.imageFormat == ImageFormat.DP200) {
                // readEncoded = new TiffReadEncodedDP200(this, metadata[0]);
            } else {
                // readEncoded = new TiffReadEncodedJpeg(this);
            }
        } else { // not jpeg
            self.reader = TIFFEncodedReader.initTile();
        }
    } else { // not tiled
        self.reader = TIFFEncodedReader.initStrip();
    }

    self.compression = tiff_dir_data.compression;

    // TODO
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
    var m = try TIFFMetadata.init(allocator, path);
    var end: usize = 0;
    end += 1;
    const m_data = &[_]TIFFMetadata{m};
    self.metadata = m_data[0..end];
    self.imageFormat = m.imageFormat;

    var lout: Layout = undefined;
    // TODO: define the layout
    if (m.imageFormat == ImageFormat.DP200) {
        // Ventana DP200 with overlaps
    } else {
        // regular grid layout
        lout = Layout.initRegularNoOverlap(allocator, m.size, m.blocksize, m.typ.?.channels());
    }

    self.slideLayout = lout;
    self.blockInfos = try m.addBlock();
}

pub fn readBlockFromFile(self: *TIFFSlide, info: BlockInfo, dst: Mat) !void {
    if (info.block < 0 or info.block >= self.blockInfos.len) {
        return error.InvalidBlockIndex;
    }

    const tiff_info = self.blockInfos[info.block];

    if (c.TIFFCurrentDirectory(tiff_info.tif) != tiff_info.dir) {
        const c_dir: c_ushort = @intCast(tiff_info.dir);
        _ = c.TIFFSetDirectory(tiff_info.tif, c_dir);
    }

    try self.reader.read(tiff_info, dst, info);
}

test "init" {
    const allocator = std.testing.allocator;

    const path = "/home/paolo/src/keeneye/zig-io/testdata/AlaskaLynx_ROW9337883641_1024x1024.ome.tiff";

    var tiff_slide = try TIFFSlide.init(path, allocator);
    defer tiff_slide.deinit();

    try std.testing.expectEqual(ImageFormat.OME, tiff_slide.imageFormat);
}
