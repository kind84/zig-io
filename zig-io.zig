const std = @import("std");
const c = @import("src/tiff/metadata.zig").C;

// pub const TIFFSlide = @import("src/tiff/TIFFSlide.zig");
pub const TIFFMetadata = @import("src/tiff/metadata.zig");

test "iguan5" {
    std.testing.refAllDecls(@This());
}
