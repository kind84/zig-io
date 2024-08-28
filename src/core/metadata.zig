const ImageFormat = @import("./slide.zig").ImageFormat;

pub fn Metadata(comptime Format: type) type {
    return struct {
        typ: Format,
    };
}
