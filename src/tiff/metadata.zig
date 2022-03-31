const std = @import("std");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const OMETIFFMetadata = @import("metadata_ome.zig");
const Channel = @import("../core/Channel.zig");
const ImageFormat = @import("../core/Slide.zig").ImageFormat;
const Size3 = @import("../core/size3.zig").Size3;
const c = @cImport({
    @cInclude("tiffio.h");
    @cInclude("tiff.h");
});

pub const C = c;

const MetadataType = union(enum) {
    OME: OMETIFFMetadata,

    fn addBlock(self: MetadataType, tif: *c.TIFF) !void {
        return switch (self) {
            .OME => |m| m.addBlock(tif),
        };
    }
};

pub const TIFFMetadata = @This();

tif: *c.TIFF,
typ: i32,
size: Size3(i32),
blocksize: Size3(i32),
planarConfig: u16,
pixelsize: @Vector(3, f64),
max: f64,
channelsList: []Channel,
imageFormat: ImageFormat,
metadataType: MetadataType,

pub fn provide(allocator: std.mem.Allocator, path: []const u8) !TIFFMetadata {
    var self = TIFFMetadata{
        .tif = undefined,
        .typ = -1,
        .size = undefined,
        .blocksize = undefined,
        .planarConfig = 0,
        .pixelsize = undefined,
        .max = 0,
        .channelsList = undefined,
        .imageFormat = undefined,
        .metadataType = undefined,
    };

    std.debug.print("opening tiff file\n", .{});
    var maybe_tif = c.TIFFOpen(path.ptr, "r8");
    if (maybe_tif) |tiff| {
        var n_dirs: c_int = c.TIFFNumberOfDirectories(tiff);
        var size_dirs = @intCast(usize, n_dirs);
        std.debug.print("found {d} IFDs in tiff file\n", .{size_dirs});
        var dirs_array = try std.ArrayList(TIFFDirectoryData).initCapacity(allocator, size_dirs);

        var dir_no: usize = 0;
        while (true) : (dir_no += 1) {
            std.debug.print("reading IFD no {d}\n", .{dir_no});
            if (c.TIFFReadDirectory(tiff) == 0) break;
            var dir = TIFFDirectoryData.init(tiff);
            try dirs_array.append(dir);
        }

        // reset directory index
        _ = c.TIFFSetDirectory(tiff, 0);

        var dirs = dirs_array.toOwnedSlice();
        std.debug.print("found dirs: {any}\n", .{dirs});

        // try OME
        if (OMETIFFMetadata.init(&self, dirs)) |m| {
            std.debug.print("tiff file is OME-Tiff\n", .{});
            self.metadataType = MetadataType{ .OME = m };
        }

        self.tif = tiff;
    }
    return self;
}

pub fn addBlock(self: TIFFMetadata) !void {
    return self.metadataType.addBlock(self.tif);
}
