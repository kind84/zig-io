const std = @import("std");
const Rect = @import("rect.zig").Rect;

pub const Mat = struct {
    typ: MatType,
    data: [*]u8,
    dims: u8,
    rows: u32,
    cols: u32,
    size: []u32,
    step: []usize,

    const auto_step: usize = 0;

    // modules/core/src/matrix.cpp L419
    pub fn init(rows: u32, cols: u32, typ: MatType, data: [*]u8, step: ?usize) !Mat {
        var stp = step orelse auto_step;

        var esz = typ.elemSize();
        var min_step = cols * @intCast(u32, esz);

        if (stp == auto_step) {
            stp = min_step;
        } else {
            std.debug.assert(stp >= min_step);
            if (stp % typ.size() != 0) {
                return error.BadStep;
            }
        }

        return Mat{
            .typ = typ,
            .data = data,
            .dims = 2,
            .rows = rows,
            .cols = cols,
            .size = &[_]u32{},
            .step = &[_]usize{ stp, esz },
        };
    }

    /// returns a new Mat of the provided roi. The underlying data is not
    /// copied.
    pub fn subMat(self: Mat, roi: Rect) Mat {
        std.debug.assert(self.dims <= 2);

        var esz = self.elemSize();
        var data = self.data + (roi.x * esz);

        return Mat{
            .typ = self.typ,
            .data = data,
            .dims = self.dims,
            .rows = roi.height, // TODO FIXME
            .cols = roi.width, // TODO FIXME
            .size = &[_]u32{roi.height},
            .step = &[_]usize{ self.step[0], esz },
        };
    }

    pub fn size(self: Mat) usize {
        return @bitSizeOf(self.t);
    }

    pub fn elemSize(self: Mat) usize {
        return self.typ.elemSize();
    }
};

pub const MatType = enum(u8) {
    CV_8UC1,
    CV_8UC2,
    CV_8UC3,
    CV_8UC4,
    CV_8SC1,
    CV_8SC2,
    CV_8SC3,
    CV_8SC4,
    CV_16UC1,
    CV_16UC2,
    CV_16UC3,
    CV_16UC4,
    CV_16SC1,
    CV_16SC2,
    CV_16SC3,
    CV_16SC4,
    CV_32SC1,
    CV_32SC2,
    CV_32SC3,
    CV_32SC4,
    CV_32FC1,
    CV_32FC2,
    CV_32FC3,
    CV_32FC4,
    CV_64FC1,
    CV_64FC2,
    CV_64FC3,
    CV_64FC4,

    /// returns the number of bytes for a given type.
    pub fn size(self: MatType) usize {
        switch (@tagName(self)[3]) {
            '8' => return 1,
            '1' => return 2,
            '3' => return 4,
            '6' => return 8,
            else => return 0,
        }
    }

    pub fn elemSize(self: MatType) usize {
        var chans = std.fmt.parseInt(usize, &[_]u8{@tagName(self)[@tagName(self).len - 1]}, 10) catch 0;
        return self.size() * chans;
    }
};

test "size" {
    var typ = MatType.CV_8UC1;
    std.debug.assert(typ.size() == 1);
    typ = MatType.CV_16UC1;
    std.debug.assert(typ.size() == 2);
    typ = MatType.CV_32SC1;
    std.debug.assert(typ.size() == 4);
    typ = MatType.CV_64FC1;
    std.debug.assert(typ.size() == 8);
}

test "elemSize" {
    var typ = MatType.CV_8UC2;
    std.debug.assert(typ.elemSize() == 2);
    typ = MatType.CV_16UC2;
    std.debug.assert(typ.elemSize() == 4);
    typ = MatType.CV_32SC3;
    std.debug.assert(typ.elemSize() == 12);
    typ = MatType.CV_64FC4;
    std.debug.assert(typ.elemSize() == 32);
}