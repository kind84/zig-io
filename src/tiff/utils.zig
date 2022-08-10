const std = @import("std");
const Size3 = @import("../core/size.zig").Size3;
const c = @import("metadata.zig").C;
// const c = @cImport({
//     @cInclude("tiff.h");
//     @cInclude("tiffio.h");
// });

pub const TIFFBlockInfo = struct {
    tif: *c.TIFF,
    dir: usize,
    block: u32,
};

pub const TIFFDirectoryData = struct {
    allocator: std.mem.Allocator,
    format: u16,
    nbits: u16,
    n_samples: u16,
    planarConfig: u16,
    compression: u16,
    photometric: u16,
    resolutionUnit: u16,
    size: Size3(u32),
    blocksize: Size3(u32),
    blocks: u32,
    subFileType: u32,
    xresolution: f32,
    yresolution: f32,
    description: []u8,

    pub fn init(allocator: std.mem.Allocator, tif: *c.TIFF) !TIFFDirectoryData {
        var tdd = TIFFDirectoryData{
            .allocator = allocator,
            .format = 0,
            .nbits = 0,
            .n_samples = 0,
            .planarConfig = 0,
            .compression = 0,
            .photometric = 0,
            .resolutionUnit = 0,
            .size = undefined,
            .blocksize = undefined,
            .blocks = 0,
            .subFileType = 0,
            .xresolution = 0,
            .yresolution = 0,
            .description = undefined,
        };

        if (c.TIFFGetField(tif, c.TIFFTAG_SUBFILETYPE, &tdd.subFileType) == 0) {
            std.debug.print("found full resolution IFD\n", .{});

            // TODO: is this valid?
            tdd.subFileType = 0; // i.e. full-resolution image data
        }

        // Get the image dimension
        _ = c.TIFFGetField(tif, c.TIFFTAG_IMAGEWIDTH, &tdd.size.width);
        _ = c.TIFFGetField(tif, c.TIFFTAG_IMAGELENGTH, &tdd.size.height);

        // Get the block size
        if (c.TIFFIsTiled(tif) == 1) {
            std.debug.print("tiff file is tiled\n", .{});
            _ = c.TIFFGetField(tif, c.TIFFTAG_TILEWIDTH, &tdd.blocksize.width);
            _ = c.TIFFGetField(tif, c.TIFFTAG_TILELENGTH, &tdd.blocksize.height);
            if (c.TIFFGetField(tif, c.TIFFTAG_TILEDEPTH, &tdd.blocksize.depth) == 1) {
                tdd.blocksize.depth = 1;
            }
            tdd.blocks = @intCast(u32, c.TIFFNumberOfTiles(tif));
        } else {
            std.debug.print("tiff file is not tiled\n", .{});
            tdd.blocksize.width = tdd.size.width;
            if (c.TIFFGetField(tif, c.TIFFTAG_ROWSPERSTRIP, &tdd.blocksize.height) == 1) {
                tdd.blocksize.height = tdd.blocksize.width;
            }
            tdd.blocksize.depth = 1; // strip are flat
            tdd.blocks = @intCast(u32, c.TIFFNumberOfStrips(tif));
        }

        // We define the size depth by the blocksize's one
        tdd.size.depth = tdd.blocksize.depth;

        // Get the CV type
        if (c.TIFFGetField(tif, c.TIFFTAG_SAMPLEFORMAT, &tdd.format) == 1) {
            tdd.format = c.SAMPLEFORMAT_UINT;
        }
        _ = c.TIFFGetField(tif, c.TIFFTAG_BITSPERSAMPLE, &tdd.nbits);
        _ = c.TIFFGetField(tif, c.TIFFTAG_SAMPLESPERPIXEL, &tdd.n_samples);
        _ = c.TIFFGetField(tif, c.TIFFTAG_PHOTOMETRIC, &tdd.photometric);
        _ = c.TIFFGetField(tif, c.TIFFTAG_PLANARCONFIG, &tdd.planarConfig);
        _ = c.TIFFGetField(tif, c.TIFFTAG_COMPRESSION, &tdd.compression);

        // Get the resolution
        var res: f32 = 0;
        if (c.TIFFGetField(tif, c.TIFFTAG_XRESOLUTION, &res) == 1) {
            tdd.xresolution = res;
        } else {
            // tdd.xresolution = -std::numeric_limits<double>::max();
            tdd.xresolution = -std.math.f64_max;
        }

        if (c.TIFFGetField(tif, c.TIFFTAG_YRESOLUTION, &res) == 1) {
            tdd.yresolution = res;
        } else {
            // tdd.yresolution = -std::numeric_limits<double>::max();
            tdd.yresolution = -std.math.f64_max;
        }

        // Get the resolution unit
        if (c.TIFFGetField(tif, c.TIFFTAG_RESOLUTIONUNIT, &tdd.resolutionUnit) == 1) {
            tdd.resolutionUnit = c.RESUNIT_NONE;
        }

        // Get the description
        var desc: [*:0]const u8 = &[_:0]u8{};
        std.debug.print("reading tiff file description\n", .{});
        if (c.TIFFGetField(tif, c.TIFFTAG_IMAGEDESCRIPTION, &desc) == 1) {
            var description = std.mem.span(desc);

            // if kept on the stack, the description gets jammed once the
            // directory data gets moved into the heap in the tiff metadata
            // array.
            var heap_description = try allocator.alloc(u8, description.len);
            std.mem.copy(u8, heap_description, description);
            tdd.description = heap_description;
        }

        return tdd;
    }

    pub fn deinit(self: TIFFDirectoryData) void {
        self.allocator.free(self.description);
    }
};
