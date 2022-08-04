const BlockInfo = @import("../core/layout.zig").BlockInfo;
const Mat = @import("../core/mat.zig").Mat;
const TIFFBlockInfo = @import("./utils.zig").TIFFBlockInfo;

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
    _ = self;
    _ = tiffInfo;
    _ = dst;
    _ = info;
}
