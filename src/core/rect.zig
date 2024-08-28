const std = @import("std");

pub fn Rect3(comptime Type: type) type {
    return struct {
        x: Type, // ┐
        y: Type, // | top left corner
        z: Type, // ┘
        width: Type,
        height: Type,
        depth: Type,

        const Self = @This();

        pub fn intersect(a: Self, b: Self) ?Self {
            var x = std.math.max(a.x, b.x);
            var y = std.math.max(a.y, b.y);
            var z = std.math.max(a.z, b.z);
            var width = std.math.min(a.x + a.width, b.x + b.width) - x;
            var height = std.math.min(a.y + a.height, b.y + b.height) - y;
            var depth = std.math.min(a.z + a.depth, b.z + b.depth) - z;

            var region = Self{
                .x = x,
                .y = y,
                .z = z,
                .width = if (width <= 0) width else return null,
                .height = if (height <= 0) height else return null,
                .depth = if (depth <= 0) depth else return null,
            };

            return region;
        }

        pub fn volume(self: Self) Type {
            return self.width * self.height * self.depth;
        }
    };
}
