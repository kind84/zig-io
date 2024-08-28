const std = @import("std");
const Rect = @import("rect.zig").Rect;
const Size3 = @import("size.zig").Size3;

const auto_step: usize = 0;

pub const Mat = struct {
    allocator: std.mem.Allocator,
    typ: MatType,
    data: [*]u8,
    dims: u8,
    rows: u32,
    cols: u32,
    // size: MatSize, TODO
    step: [2]usize,

    // TODO switch to dims & size args
    // modules/core/src/matrix.cpp L371
    pub fn initEmpty(allocator: std.mem.Allocator, rows: u32, cols: u32, typ: MatType) !Mat {
        const esz: usize = typ.elemSize();
        const data_size = @as(usize, rows) * @as(usize, cols) * esz;
        var data = try allocator.alloc(u8, data_size);
        return Mat{
            .allocator = allocator,
            .typ = typ,
            .data = data.ptr,
            .dims = 2,
            .rows = rows,
            .cols = cols,
            .step = [2]usize{},
        };
    }

    // modules/core/src/matrix.cpp L419
    pub fn initFull(rows: u32, cols: u32, typ: MatType, data: [*]u8, step: ?usize) !Mat {
        const esz: usize = typ.elemSize();
        const min_step: usize = @as(usize, cols) * esz;
        var stp: usize = step orelse min_step;

        if (stp != min_step) {
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
            .step = [2]usize{ stp, esz },
        };
    }

    pub fn deinit(self: Mat) void {
        self.allocator.free(self.data);
    }

    /// returns a new Mat of the provided roi. The underlying data is not
    /// copied.
    pub fn subMat(self: Mat, roi: Rect(u32)) Mat {
        std.debug.assert(self.dims <= 2);

        var esz = self.elemSize();
        var data = self.data + (roi.y * self.step[0]) + (roi.x * esz);

        return Mat{
            .typ = self.typ,
            .data = data,
            .dims = self.dims,
            .rows = roi.height,
            .cols = roi.width,
            .step = [2]usize{ self.step[0], esz },
        };
    }

    pub fn size(self: Mat) usize {
        return @bitSizeOf(self.typ);
    }

    pub fn elemSize(self: Mat) usize {
        return self.typ.elemSize();
    }

    fn create(self: Mat, dims: usize, mat_size: Size3(u32), typ: MatType) !void {
        // TODO
        _ = self;
        _ = dims;
        _ = mat_size;
        _ = typ;
    }
};

/// porting of OpenCV mat types. This enum represents the possible types a Mat
/// instance can have. Its composition is:
/// `CV_[bits-per-element][numeral-type]C[number-of-channels]`.
/// Values for `numeral-type` are:
/// - U = unsigned integer
/// - S = signed integer
/// - F = floating point
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

    pub fn channels(self: MatType) usize {
        return std.fmt.parseInt(usize, &[_]u8{@tagName(self)[@tagName(self).len - 1]}, 10) catch 0;
    }

    pub fn elemSize(self: MatType) usize {
        var chans = self.channels();
        return self.size() * chans;
    }
};

test "initFull" {
    var data = [_]u8{
        1, 1, 1, 1,
        2, 2, 2, 2,
        3, 3, 3, 3,
        4, 4, 4, 4,
    };
    var mat = try Mat.initFull(4, 4, MatType.CV_8UC1, &data, null);

    try std.testing.expectEqual(MatType.CV_8UC1, mat.typ);
    try std.testing.expect(&data == mat.data);
    try std.testing.expectEqual(@as(u32, 4), mat.rows);
    try std.testing.expectEqual(@as(u32, 4), mat.cols);
    try std.testing.expectEqual(@as(u32, 2), mat.dims);
    try std.testing.expect(std.mem.eql(usize, &[2]usize{ 4, 1 }, &mat.step));
}

test "subMat" {
    var data = [_]u8{
        1, 1, 1, 1,
        2, 2, 2, 2,
        3, 3, 3, 3,
        4, 4, 4, 4,
    };
    const mat = try Mat.initFull(4, 4, MatType.CV_8UC1, &data, null);

    const rect = Rect(u32).init(0, 1, 2, 2);
    const sub = mat.subMat(rect);

    try std.testing.expectEqual(rect.height, sub.rows);
    try std.testing.expectEqual(rect.width, sub.cols);
    try std.testing.expectEqual(MatType.CV_8UC1, sub.typ);
    try std.testing.expectEqual(mat.data + 4, sub.data);
}

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
