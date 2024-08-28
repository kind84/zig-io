const std = @import("std");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const TIFFBlockInfo = @import("utils.zig").TIFFBlockInfo;
const OMETIFFMetadata = @import("metadata_ome.zig");
const GenericTIFFMetadata = @import("metadata_generic.zig");
const Channel = @import("../core/Channel.zig");
const ImageFormat = @import("../core/slide.zig").ImageFormat;
const MatType = @import("../core/mat.zig").MatType;
const Size3 = @import("../core/size.zig").Size3;
const c = @cImport({
    @cInclude("tiffio.h");
    @cInclude("tiff.h");
});

pub const C = c;

const MetadataType = union(enum) {
    OME: OMETIFFMetadata,
    Generic: GenericTIFFMetadata,

    fn deinit(self: MetadataType) void {
        return switch (self) {
            .OME => |m| m.deinit(),
            .Generic => |m| m.deinit(),
        };
    }

    fn addBlock(self: MetadataType, allocator: std.mem.Allocator) anyerror![]TIFFBlockInfo {
        return switch (self) {
            .OME => |m| m.addBlock(allocator),
            .Generic => |m| m.addBlock(allocator),
        };
    }
};

pub const TIFFMetadata = @This();

allocator: std.mem.Allocator,
tif: *c.TIFF,
typ: ?MatType,
size: Size3(u32),
blocksize: Size3(u32),
planarConfig: u16,
pixelsize: std.meta.Vector(3, f64),
max: f64,
channelsList: []Channel,
imageFormat: ImageFormat,
metadataType: MetadataType,

pub fn init(allocator: std.mem.Allocator, path: []const u8) !TIFFMetadata {
    var self = TIFFMetadata{
        .allocator = allocator,
        .tif = undefined,
        .typ = null,
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

            // break :blk undefined;
            return error.NotATIFFSlide;
        };

        self.metadataType = metadata;
        self.tif = tiff;
    }

    return self;
}

pub fn deinit(self: *TIFFMetadata) void {
    self.metadataType.deinit();
}

pub fn addBlock(self: TIFFMetadata) ![]TIFFBlockInfo {
    return self.metadataType.addBlock(self.allocator);
}

test "init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) std.testing.expect(false) catch @panic("TEST FAIL"); //fail test; can't try in defer as defer is executed after we return
    }

    const path = "/home/paolo/src/keeneye/zig-io/testdata/AlaskaLynx_ROW9337883641_1024x1024.ome.tiff";
    var meta = try init(allocator, path);
    defer meta.deinit();

    try std.testing.expectEqual(ImageFormat.OME, meta.imageFormat);
}

test "addBlock OME" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) std.testing.expect(false) catch @panic("TEST FAIL"); //fail test; can't try in defer as defer is executed after we return
    }

    const path = "/home/paolo/src/keeneye/zig-io/testdata/AlaskaLynx_ROW9337883641_1024x1024.ome.tiff";
    var meta = try init(allocator, path);
    defer meta.deinit();

    const infos = try meta.addBlock();
    _ = infos;
    // std.debug.print("{any}\n", .{infos});
}
