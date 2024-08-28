const std = @import("std");

pub fn Rect(comptime Type: type) type {
    return struct {
        x: Type, // ┐ top left corner
        y: Type, // ┘
        width: Type,
        height: Type,

        const Self = @This();

        pub fn init(x: Type, y: Type, width: Type, height: Type) Self {
            return Self{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            };
        }

        pub fn intersect(a: Self, b: Self) ?Self {
            const x = @max(a.x, b.x);
            const y = @max(a.y, b.y);
            const width = @min(a.x + a.width, b.x + b.width) - x;
            const height = @min(a.y + a.height, b.y + b.height) - y;

            const region = Self{
                .x = x,
                .y = y,
                .width = if (width <= 0) width else return null,
                .height = if (height <= 0) height else return null,
            };

            return region;
        }

        pub fn volume(self: Self) Type {
            return self.width * self.height;
        }
    };
}

pub fn Rect3(comptime Type: type) type {
    return struct {
        x: Type, // ┐
        y: Type, // | top left corner
        z: Type, // ┘
        width: Type,
        height: Type,
        depth: Type,

        const Self = @This();

        pub fn init(x: Type, y: Type, z: Type, width: Type, height: Type, depth: Type) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
                .width = width,
                .height = height,
                .depth = depth,
            };
        }

        pub fn intersect(a: Self, b: Self) ?Self {
            const x = @max(a.x, b.x);
            const y = @max(a.y, b.y);
            const z = @max(a.z, b.z);
            const width = @min(a.x + a.width, b.x + b.width) - x;
            const height = @min(a.y + a.height, b.y + b.height) - y;
            const depth = @min(a.z + a.depth, b.z + b.depth) - z;

            const region = Self{
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
