const std = @import("std");
const TIFFDirectoryData = @import("tiff/utils.zig").TIFFDirectoryData;
const TIFFMetadata = @import("tiff/metadata.zig").TIFFMetadata;
const c = @cImport({
    @cInclude("tiffio.h");
});

pub fn main() anyerror!void {
    std.debug.maybeEnableSegfaultHandler();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // const path = "/home/paolo/Downloads/image-set-001/TCGA-60.ome.tiff";
    const path = "/home/paolo/Downloads/pd-l1ktnslcS5.ome.tiff";
    var metadata = try TIFFMetadata.provide(allocator, path);
    try metadata.addBlock();

    // var maybe_tif = c.TIFFOpen(path, "r8");
    // std.debug.print("{s}\n", .{@typeName(@TypeOf(maybe_tif))});
    // if (maybe_tif) |tif| {
    //     defer c.TIFFClose(tif);

    //     var dircount: u8 = 0;
    //     var have_dir = true;
    //     while (have_dir) : (dircount += 1) {
    //         if (c.TIFFReadDirectory(tif) == 0) have_dir = false;
    //     }
    //     std.debug.print("{d} directories in {s}\n", .{ dircount, path });
    // }
}
