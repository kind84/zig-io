const std = @import("std");
const builtin = @import("builtin");
const read = @import("./core/read.zig");
const Mat = @import("./core/mat.zig").Mat;
const MatType = @import("./core/mat.zig").MatType;
const Rect3 = @import("./core/rect.zig").Rect3;
const c = @cImport({
    @cInclude("tiffio.h");
});

pub fn main() anyerror!void {
    std.debug.maybeEnableSegfaultHandler();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // const path = "/home/paolo/Downloads/image-set-001/TCGA-60.ome.tiff";
    const path = "/home/paolo/src/keeneye/zig-io/testdata/AlaskaLynx_ROW9337883641_1024x1024.ome.tiff";

    var slide = try read.openSlide(path, allocator);

    // TODO: check slide depth
    // if (slide->depth() != CV_8U && slide->depth() != CV_16U &&
    //     slide->depth() != CV_32F) {
    //   CV_Error(cv::Error::StsUnsupportedFormat, "Unsupported bitdepth");
    // }
    //
    // if (slide->depth() == CV_32F) {
    //   CV_Error(cv::Error::StsUnsupportedFormat,
    //            "Floating point data not yet supported!");
    // }

    var num_channels = slide.channelList.len;
    var file_type: MatType = slide.depth();

    if (slide.isContiguous()) {
        if (num_channels > 4) {
            std.debug.print("Unsupported {d} samples/pixel\n", .{num_channels});
            return error.UnsupportedSamplesPerPixel;
        }
        file_type = slide.typ;
    }

    if (builtin.mode == std.builtin.Mode.Debug) {
        std.debug.print("Slide image format: {s}\n", .{@tagName(slide.imageFormat)});
        std.debug.print("Slide width (px): {d}\n", .{slide.cols()});
        std.debug.print("Slide height (px): {d}\n", .{slide.rows()});
        std.debug.print("Slide depth (px): {d}\n", .{slide.slices()});
        std.debug.print("Number of channels: {d}\n", .{slide.channelList.len});
        if (slide.objective > 0.0) {
            std.debug.print("Slide Objective: {d}\n", .{slide.objective});
        }
        if (@fabs(slide.focalPlaneMin - slide.focalPlaneMax) < 1e-9 or slide.slices() == 1) {
            std.debug.print("Slide focalPlaneMin: {d}\n", .{slide.focalPlaneMin});
            std.debug.print("Slide focalPlaneMax: {d}\n", .{slide.focalPlaneMax});
        }
    }

    // std.debug.print("{any}\n", .{slide});
    var dst = try Mat.initEmpty(allocator, 1, 1, MatType.CV_8UC1);
    defer dst.deinit();
    var region = Rect3(usize).init(0, 0, 0, 100, 100, 1);
    var channel: usize = 1;
    try slide.getRegion(allocator, region, channel, &dst);
    std.debug.print("{any}\n", .{dst});
}
