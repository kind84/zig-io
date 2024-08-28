const std = @import("std");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const OMETIFFMetadata = @import("metadata_ome.zig");
const GenericTIFFMetadata = @import("metadata_generic.zig");
const Channel = @import("../core/Channel.zig");
const ImageFormat = @import("../core/Slide.zig").ImageFormat;
const Size3 = @import("../core/size.zig").Size3;
const c = @cImport({
    @cInclude("tiffio.h");
    @cInclude("tiff.h");
});

pub const C = c;

const MetadataType = union(enum) {
    OME: OMETIFFMetadata,
    Generic: GenericTIFFMetadata,

    fn addBlock(self: MetadataType, tif: *c.TIFF) !void {
        return switch (self) {
            .OME => |m| m.addBlock(tif),
            .Generic => |m| m.addBlock(tif),
        };
    }
};

pub const TIFFMetadata = @This();

tif: *c.TIFF,
typ: i32,
size: Size3(u32),
blocksize: Size3(u32),
planarConfig: u16,
pixelsize: std.meta.Vector(3, f64),
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
        .pixelsize = @Vector(3, f64){},
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
            var dir = try TIFFDirectoryData.init(allocator, tiff);
            try dirs_array.append(dir);
            if (c.TIFFReadDirectory(tiff) == 0) break;
            std.debug.print("DESCR: {s}\n", .{dir.description});
        }

        // reset directory index
        _ = c.TIFFSetDirectory(tiff, 0);

        var dirs = dirs_array.toOwnedSlice();

        var metadata: MetadataType = blk: {
            // try OME
            if (try OMETIFFMetadata.init(allocator, &self, dirs)) |m| {
                std.debug.print("tiff file is OME-Tiff\n", .{});
                break :blk MetadataType{ .OME = m };
            }

            // try generic
            if (try GenericTIFFMetadata.init(allocator, &self, dirs)) |m| {
                std.debug.print("tiff file is Generic Tiff\n", .{});
                break :blk MetadataType{ .Generic = m };
            }

            break :blk undefined;
        };

        self.metadataType = metadata;
        self.tif = tiff;
    }
    return self;
}

pub fn addBlock(self: TIFFMetadata) !void {
    return self.metadataType.addBlock(self.tif);
}
