const std = @import("std");
const Slide = @import("slide.zig").Slide;
const TIFFSlide = @import("../tiff/TIFFSlide.zig");

pub fn openSlide(path: []const u8, allocator: std.mem.Allocator) Slide {
    var slide: Slide = undefined;

    std.debug.assert(std.fs.path.isAbsolute(path));

    if (TIFFSlide.init(path, allocator)) |*tiff_slide| {
        slide = tiff_slide.*.slide();
    } else |_| {
        unreachable;
    }

    return slide;
}
