const std = @import("std");
const Size3 = @import("../core/size3.zig").Size3;
const c = @import("metadata.zig").C;
const TIFF = @import("metadata.zig").TIFF;
// const c = @cImport({
//     @cInclude("tiff.h");
//     @cInclude("tiffio.h");
// });

pub const TIFFBlockInfo = struct {
    tif: *TIFF,
    dir: i32,
    block: i32,
};

pub const TIFFDirectoryData = struct {
    format: u16,
    nbits: u16,
    nsamples: u16,
    planarConfig: u16,
    compression: u16,
    photometric: u16,
    resolutionUnit: u16,
    size: Size3(i32),
    blocksize: Size3(i32),
    blocks: i32,
    subFileType: i32,
    xresolution: f64,
    yresolution: f64,
    description: []const u8,

    pub fn init(tif: *TIFF) TIFFDirectoryData {
        var tdd = TIFFDirectoryData{
            .format = 0,
            .nbits = 0,
            .nsamples = 0,
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
            if (c.TIFFGetField(tif, c.TIFFTAG_TILEDEPTH, &tdd.blocksize.depth) == 0) {
                tdd.blocksize.depth = 1;
            }
            tdd.blocks = @intCast(i32, c.TIFFNumberOfTiles(tif));
        } else {
            std.debug.print("tiff file is not tiled\n", .{});
            tdd.blocksize.width = tdd.size.width;
            if (c.TIFFGetField(tif, c.TIFFTAG_ROWSPERSTRIP, &tdd.blocksize.height) == 0) {
                tdd.blocksize.height = tdd.blocksize.width;
            }
            tdd.blocksize.depth = 1; // strip are flat
            tdd.blocks = @intCast(i32, c.TIFFNumberOfStrips(tif));
        }

        // We define the size depth by the blocksize's one
        tdd.size.depth = tdd.blocksize.depth;

        // Get the CV type
        if (c.TIFFGetField(tif, c.TIFFTAG_SAMPLEFORMAT, &tdd.format) == 0) {
            tdd.format = c.SAMPLEFORMAT_UINT;
        }
        _ = c.TIFFGetField(tif, c.TIFFTAG_BITSPERSAMPLE, &tdd.nbits);
        _ = c.TIFFGetField(tif, c.TIFFTAG_SAMPLESPERPIXEL, &tdd.nsamples);
        _ = c.TIFFGetField(tif, c.TIFFTAG_PHOTOMETRIC, &tdd.photometric);
        _ = c.TIFFGetField(tif, c.TIFFTAG_PLANARCONFIG, &tdd.planarConfig);
        _ = c.TIFFGetField(tif, c.TIFFTAG_COMPRESSION, &tdd.compression);

        // Get the resolution
        var res: f32 = undefined;
        if (c.TIFFGetField(tif, c.TIFFTAG_XRESOLUTION, &res) == 0) {
            tdd.xresolution = res;
        } else {
            // tdd.xresolution = -std::numeric_limits<double>::max();
            tdd.xresolution = -std.math.f64_max;
        }

        if (c.TIFFGetField(tif, c.TIFFTAG_YRESOLUTION, &res) == 0) {
            tdd.yresolution = res;
        } else {
            // tdd.yresolution = -std::numeric_limits<double>::max();
            tdd.yresolution = -std.math.f64_max;
        }

        // Get the resolution unit
        if (c.TIFFGetField(tif, c.TIFFTAG_RESOLUTIONUNIT, &tdd.resolutionUnit) == 0) {
            tdd.resolutionUnit = c.RESUNIT_NONE;
        }

        // Get the description
        // var c_descr: ?[*]const u8 = null;
        var desc: ?[*:0]const u8 = null;
        std.debug.print("reading tiff file description\n", .{});
        if (c.TIFFGetField(tif, c.TIFFTAG_IMAGEDESCRIPTION, &desc) == 0) {
            if (desc) |d| {
                tdd.description = std.mem.span(d);
            }
        }
        std.debug.print("reading tiff file description done\n", .{});

        return tdd;
    }
};
