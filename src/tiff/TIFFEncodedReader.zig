const BlockInfo = @import("../core/layout.zig").BlockInfo;
const Mat = @import("../core/mat.zig").Mat;
const TIFFBlockInfo = @import("./utils.zig").TIFFBlockInfo;
const c = @import("./metadata.zig").C;

const TIFFEncodeType = enum {
    Tile,
    Strip,
    Jpeg,
    DP200,
};

pub const TIFFEncodedReader = @This();
typ: TIFFEncodeType,

pub fn initTile() TIFFEncodedReader {
    return TIFFEncodedReader{
        .typ = TIFFEncodeType.Tile,
    };
}

pub fn initStrip() TIFFEncodedReader {
    return TIFFEncodedReader{
        .typ = TIFFEncodeType.Strip,
    };
}

pub fn read(self: TIFFEncodedReader, tiffInfo: TIFFBlockInfo, dst: Mat, info: BlockInfo) !void {
    switch (self.typ) {
        TIFFEncodeType.Tile => return readTile(tiffInfo, dst, info),
        TIFFEncodeType.Strip => return readStrip(tiffInfo, dst, info),
        TIFFEncodeType.Jpeg => return,
        TIFFEncodeType.DP200 => return,
    }
}

fn readTile(tiffInfo: TIFFBlockInfo, dst: Mat, _: BlockInfo) !void {
    const tile_size = c.TIFFTileSize(tiffInfo.tif);

    if (c.TIFFReadEncodedTile(tiffInfo.tif, tiffInfo.block, dst.data.ptr, tile_size) == 1) {
        return error.Internal;
    }
}

fn readStrip(tiffInfo: TIFFBlockInfo, dst: Mat, _: BlockInfo) !void {
    const strip_size = c.TIFFStripSize(tiffInfo.tif);

    if (c.TIFFReadEncodedStrip(tiffInfo.tif, tiffInfo.block, dst.data.ptr, strip_size) == 1) {
        return error.Internal;
    }
}
