const std = @import("std");
const MatType = @import("../core/mat.zig").MatType;
const Size3 = @import("../core/size.zig").Size3;
const c = @import("metadata.zig").C;

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
            tdd.blocks = @intCast(c.TIFFNumberOfTiles(tif));
        } else {
            std.debug.print("tiff file is not tiled\n", .{});
            tdd.blocksize.width = tdd.size.width;
            if (c.TIFFGetField(tif, c.TIFFTAG_ROWSPERSTRIP, &tdd.blocksize.height) == 1) {
                tdd.blocksize.height = tdd.blocksize.width;
            }
            tdd.blocksize.depth = 1; // strip are flat
            tdd.blocks = @intCast(c.TIFFNumberOfStrips(tif));
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
            tdd.xresolution = -std.math.floatMax(f32);
        }

        if (c.TIFFGetField(tif, c.TIFFTAG_YRESOLUTION, &res) == 1) {
            tdd.yresolution = res;
        } else {
            // tdd.yresolution = -std::numeric_limits<double>::max();
            tdd.yresolution = -std.math.floatMax(f32);
        }

        // Get the resolution unit
        if (c.TIFFGetField(tif, c.TIFFTAG_RESOLUTIONUNIT, &tdd.resolutionUnit) == 1) {
            tdd.resolutionUnit = c.RESUNIT_NONE;
        }

        // Get the description
        var desc: [*:0]const u8 = &[_:0]u8{};
        std.debug.print("reading tiff file description\n", .{});
        if (c.TIFFGetField(tif, c.TIFFTAG_IMAGEDESCRIPTION, &desc) == 1) {
            const description = std.mem.span(desc);

            // if kept on the stack, the description gets jammed once the
            // directory data gets moved into the heap in the tiff metadata
            // array.
            const heap_description = try allocator.alloc(u8, description.len);
            @memcpy(heap_description, description);
            tdd.description = heap_description;
        }

        return tdd;
    }

    pub fn deinit(self: TIFFDirectoryData) void {
        self.allocator.free(self.description);
    }
};

pub fn computeMatType(
    format: u16,
    photometric: u16,
    nBits: u16,
    nSamples: u16,
    nChannels: u16,
) !MatType {
    // TODO
    // if (CV_DIV2_REM(nbits, 3) != 0) {
    //   CV_Error(Error::StsBadArg, "'nbits' must be multiple of 8");
    // }

    if (nSamples < 1) {
        return error.BadArg;
    }
    const ph_rgb: u16 = @intCast(c.PHOTOMETRIC_RGB);
    if (nSamples < 3 and photometric == ph_rgb) {
        return error.BadArg;
    }
    const ph_ycbcr: u16 = @intCast(c.PHOTOMETRIC_YCBCR);
    if (nSamples != 3 and photometric == ph_ycbcr) {
        return error.BadArg;
    }
    const ph_pal: u16 = @intCast(c.PHOTOMETRIC_PALETTE);
    if (nSamples != 1 and photometric == ph_pal) {
        return error.BadArg;
    }

    // allow for multiple channels
    const n_samples = nSamples * nChannels;

    const c_sampl_uint: u16 = @intCast(c.SAMPLEFORMAT_UINT);
    const c_sampl_int: u16 = @intCast(c.SAMPLEFORMAT_INT);
    const c_sampl_ieeeffp: u16 = @intCast(c.SAMPLEFORMAT_IEEEFP);
    const c_sampl_void: u16 = @intCast(c.SAMPLEFORMAT_VOID);
    const c_sampl_complexint: u16 = @intCast(c.SAMPLEFORMAT_COMPLEXINT);
    const c_sampl_complexieeefp: u16 = @intCast(c.SAMPLEFORMAT_COMPLEXIEEEFP);
    switch (format) {
        c_sampl_uint => {
            switch (nBits) {
                8 => {
                    switch (n_samples) {
                        1 => return MatType.CV_8UC1,
                        2 => return MatType.CV_8UC2,
                        3 => return MatType.CV_8UC3,
                        4 => return MatType.CV_8UC4,
                        else => unreachable,
                    }
                },
                16 => {
                    std.debug.print("{d}\n", .{n_samples});
                    switch (n_samples) {
                        1 => return MatType.CV_16UC1,
                        2 => return MatType.CV_16UC2,
                        3 => return MatType.CV_16UC3,
                        4 => return MatType.CV_16UC4,
                        else => unreachable,
                    }
                },
                else => return error.UnsupportedFormat,
            }
        },
        c_sampl_int => {
            switch (nBits) {
                8 => {
                    switch (n_samples) {
                        1 => return MatType.CV_8SC1,
                        2 => return MatType.CV_8SC2,
                        3 => return MatType.CV_8SC3,
                        4 => return MatType.CV_8SC4,
                        else => unreachable,
                    }
                },
                16 => {
                    switch (n_samples) {
                        1 => return MatType.CV_16SC1,
                        2 => return MatType.CV_16SC2,
                        3 => return MatType.CV_16SC3,
                        4 => return MatType.CV_16SC4,
                        else => unreachable,
                    }
                },
                32 => {
                    switch (n_samples) {
                        1 => return MatType.CV_32SC1,
                        2 => return MatType.CV_32SC2,
                        3 => return MatType.CV_32SC3,
                        4 => return MatType.CV_32SC4,
                        else => unreachable,
                    }
                },
                else => return error.UnsupportedFormat,
            }
        },
        c_sampl_ieeeffp => {
            switch (nBits) {
                32 => {
                    switch (n_samples) {
                        1 => return MatType.CV_32FC1,
                        2 => return MatType.CV_32FC2,
                        3 => return MatType.CV_32FC3,
                        4 => return MatType.CV_32FC4,
                        else => unreachable,
                    }
                },
                64 => {
                    switch (n_samples) {
                        1 => return MatType.CV_64FC1,
                        2 => return MatType.CV_64FC2,
                        3 => return MatType.CV_64FC3,
                        4 => return MatType.CV_64FC4,
                        else => unreachable,
                    }
                },
                else => return error.UnsupportedFormat,
            }
        },
        c_sampl_void => return error.UnsupportedFormat, // unspecified
        c_sampl_complexint => return error.UnsupportedFormat, // not supported yet
        c_sampl_complexieeefp => return error.UnsupportedFormat, // not supported yet
        else => {
            // unable to find the correct OpenCV type using 'format', likely because the
            // tag is missing from the TIFF file. Return default type in function of the
            // number of bits and number of samples.
            switch (nBits) {
                8 => {
                    switch (n_samples) {
                        1 => return MatType.CV_8UC1,
                        2 => return MatType.CV_8UC2,
                        3 => return MatType.CV_8UC3,
                        4 => return MatType.CV_8UC4,
                        else => unreachable,
                    }
                },
                16 => {
                    switch (n_samples) {
                        1 => return MatType.CV_16UC1,
                        2 => return MatType.CV_16UC2,
                        3 => return MatType.CV_16UC3,
                        4 => return MatType.CV_16UC4,
                        else => unreachable,
                    }
                },
                32 => {
                    switch (n_samples) {
                        1 => return MatType.CV_32FC1,
                        2 => return MatType.CV_32FC2,
                        3 => return MatType.CV_32FC3,
                        4 => return MatType.CV_32FC4,
                        else => unreachable,
                    }
                },
                64 => {
                    switch (n_samples) {
                        1 => return MatType.CV_64FC1,
                        2 => return MatType.CV_64FC2,
                        3 => return MatType.CV_64FC3,
                        4 => return MatType.CV_64FC4,
                        else => unreachable,
                    }
                },
                else => return MatType.CV_8UC1,
            }
        },
    }
}

test "init" {
    const allocator = std.testing.allocator;

    const path: []const u8 = "/home/paolo/src/keeneye/zig-io/testdata/AlaskaLynx_ROW9337883641_1024x1024.ome.tiff";

    const tiff = c.TIFFOpen(path.ptr, "r8") orelse unreachable;
    defer {
        _ = c.TIFFClose(tiff);
    }

    const tdd = try TIFFDirectoryData.init(allocator, tiff);
    defer tdd.deinit();

    try std.testing.expectEqual(@as(u16, 8), tdd.nbits);
    try std.testing.expectEqual(@as(u16, 3), tdd.n_samples);
    try std.testing.expectEqual(@as(u16, 1), tdd.compression); // Compression None
}
