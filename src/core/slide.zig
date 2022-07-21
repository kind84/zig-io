const std = @import("std");
const builtin = @import("builtin");
const Channel = @import("./Channel.zig");
const Rect = @import("rect.zig").Rect;
const Rect3 = @import("rect.zig").Rect3;
const Mat = @import("mat.zig").Mat;
// const Metadata = @import("./metadata.zig").Metadata;
const TIFFSlide = @import("../tiff/TIFFSlide.zig");
const TIFFMetadata = @import("../tiff/metadata.zig").TIFFMetadata;

pub const Slide = struct {
    // boost::filesystem::path path_;
    //
    // std::ios_base::openmode mode_;

    // metadata: switch (Context) {
    //     TIFFSlide => Metadata(TIFFMetadata),
    //     else => unreachable,
    // },
    // metadata: Metadata,
    imageFormat: ImageFormat,
    typ: i32,
    objective: f64,
    focalPlaneMin: f64,
    focalPlaneMax: f64,
    pixelsize: @Vector(3, f64),

    // SlideLayout* layout_;
    //
    // SlideCache* cache_;

    channelList: []Channel,

    RGBABuffer: []u32,

    mat: Mat,

    ptr: *anyopaque,
    openFn: if (builtin.zig_backend == .stage1)
        fn (ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) anyerror!void
    else
        *const fn (ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) anyerror!void,

    pub fn init(
        pointer: anytype,
        imageFormat: ImageFormat,
        comptime openFn: fn (
            ptr: @TypeOf(pointer),
            path: []const u8,
            allocator: std.mem.Allocator,
        ) anyerror!void,
    ) Slide {
        const Ptr = @TypeOf(pointer);
        std.debug.assert(@typeInfo(Ptr) == .Pointer); // Must be a pointer
        std.debug.assert(@typeInfo(Ptr).Pointer.size == .One); // Must be a single-item pointer
        std.debug.assert(@typeInfo(@typeInfo(Ptr).Pointer.child) == .Struct); // Must point to a struct
        const gen = struct {
            fn open(ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) !void {
                const alignment = @typeInfo(Ptr).Pointer.alignment;
                const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                try openFn(self, path, allocator);
            }
        };

        return .{
            .imageFormat = imageFormat,
            .typ = undefined,
            .objective = undefined,
            .focalPlaneMin = undefined,
            .focalPlaneMax = undefined,
            .pixelsize = undefined,
            .channelList = undefined,
            .RGBABuffer = undefined,
            .mat = undefined,
            .ptr = pointer,
            .openFn = gen.open,
        };
    }

    pub fn open(self: Slide, path: []const u8, allocator: std.mem.Allocator) !void {
        self.openFn(self.ptr, path, allocator);
    }

    pub fn getRegion(self: Slide, region: Rect3(u32), channel: u32, dst: Mat) !void {
        // TODO
        _ = self;
        _ = channel;
        _ = dst;

        var dim: u2 = 0;
        var sz = &[_]usize{ 0, 0, 0 };

        if (region.depth == 1) {
            dim = 2;
            sz[0] = region.height;
            sz[1] = region.width;
        } else {
            dim = 3;
            sz[0] = region.depth;
            sz[1] = region.height;
            sz[2] = region.width;
        }
    }

    pub fn depth(self: Slide) i32 {
        _ = self;
        // TODO
        // return CV_MAT_DEPTH(self.typ);
        return 0;
    }

    pub fn slices(self: Slide) i32 {
        _ = self;
        // TODO
        // return self.layout.size.depth;
        return 1;
    }

    pub fn rows(self: Slide) i32 {
        _ = self;
        // TODO
        // return self.layout.size.height;
        return 1;
    }

    pub fn cols(self: Slide) i32 {
        _ = self;
        // TODO
        // return self.layout.size.width;
        return 1;
    }

    pub fn isContiguous(self: Slide) bool {
        _ = self;
        // TODO
        // self.layout.isContiguous();
        return false;
    }

    fn isValidChannelSelection(channel: u32) bool {
        // TODO
        _ = channel;
        return true;
    }

    fn copyTo(self: Slide, r1: Rect3(u32), r2: Rect3(u32), dst: Mat) !void {
        var intersect = r1.intersect(r2) orelse return error.NoIntersection;

        var src_rect = Rect(u32).init(
            intersect.x - r1.x,
            intersect.y - r1.y,
            intersect.width,
            intersect.height,
        );
        var dst_rect = Rect(u32).init(
            intersect.x - r2.x,
            intersect.y - r2.y,
            intersect.width,
            intersect.height,
        );

        var src_z0 = intersect.z - r1.z;
        var dst_z0 = intersect.z - r2.z;
        var height: u32 = undefined;
        var src_data: [*]u8 = undefined;
        var dst_data: [*]u8 = undefined;
        var bytes_in_row = intersect.width * @intCast(u32, self.mat.elemSize());

        if (self.mat.dims == 2 and dst.dims == 2) {
            std.debug.assert(intersect.depth == 1);

            src_data = self.mat.data + (src_rect.x * self.mat.elemSize()) + (src_rect.y * self.mat.step[0]);
            dst_data = dst.data + (dst_rect.x * dst.elemSize()) + (dst_rect.y * dst.step[0]);

            height = intersect.height;
        } else if (self.mat.dims == 2) { // dst.dims != 2
            std.debug.assert(intersect.depth == 1);

            var src_sub_view: Mat = self.mat.subMat(src_rect);

            var dst_slice = Mat.init(
                dst.size[1],
                dst.size[2],
                dst.typ,
                dst.data + dst_z0 * dst.step[0],
                null,
            );
            var dst_sub_view: Mat = dst_slice.subMat(dst_rect);

            src_data = src_sub_view.data;
            dst_data = dst_sub_view.data;
        } else if (dst.dims == 2) { // self.mat.dims != 2
            std.debug.assert(intersect.depth == 1);

            var src_slice = Mat.init(
                self.mat.size[1],
                self.mat.size[2],
                self.mat.typ,
                self.mat.data + src_z0 * self.mat.step[0],
                null,
            );
            var src_sub_view: Mat = src_slice.subMat(src_rect);

            var dst_sub_view: Mat = dst.subMat(dst_rect);

            src_data = src_sub_view.data;
            dst_data = dst_sub_view.data;
        } else { // dst.dims == 3 && self.mat.dims == 3
            var zz: u32 = 0;
            while (zz < intersect.depth) : (zz += 1) {
                var src_slice = Mat.init(
                    self.mat.size[1],
                    self.mat.size[2],
                    self.mat.typ,
                    self.mat.data + (src_z0 + zz) * self.mat.step[0],
                    null,
                );
                var dst_slice = Mat.init(
                    dst.size[1],
                    dst.size[2],
                    dst.typ,
                    dst.data + (dst_z0 + zz) * dst.step[0],
                    null,
                );

                var src_sub_view: Mat = src_slice.subMat(src_rect);
                var dst_sub_view: Mat = dst_slice.subMat(dst_rect);

                src_data = src_sub_view.data;
                dst_data = dst_sub_view.data;
            }
        }

        var i: u32 = 0;
        while (i < height) : (i += 1) {
            // using @memcpy to keep the same style as C++ here
            // it can be replaced by:
            // std.mem.copy(u8, dst_data[0..bytes_in_row], src_data[0..bytes_in_row]);
            @memcpy(dst_data, src_data, bytes_in_row);

            src_data += self.mat.step[0];
            dst_data += dst.step[0];
        }

        _ = self;
    }
};

pub const ImageFormat = enum(u8) {
    TIFF = 0x01,
    NDPI = 0x02,
    NDPIS = 0x03,
    DICOM = 0x04,
    FLUIDIGM = 0x05, // this one needs to be defined in a .so
    LLTECH = 0x06, // this one needs to be defined in a .so
    OIF = 0x07,
    CZI = 0x08,
    LIF = 0x09, // Leica LIF
    PHIL = 0x0A, // Philips tiff
    // JPGTIF = 0x0B, // tiff with jpeg compression (NO LONGER SUPPORTED)
    JPEG = 0x0C, // Actual jpeg files
    SVS = 0x0D, // aperio .svs with 33003 0r 33005 or JPEG compression
    E2E = 0x0E, // Heidelberg E2E OCT files
    // VEN = 0x0F, // Ventana (NO LONGER SUPPORTED)
    MRX = 0x10, // MIRAX
    TIFFS = 0x11, // tiff_stack
    APER = 0x12, // Aperio tiff
    IJT = 0x13, // Imagej-tiff
    OME = 0x14, // OME-TIFF
    QPT = 0x15, // QPTIFF
    ISYNTAX = 0x16, // Philips Isyntax
    DP200 = 0x17, // Ventana DP200 - Overlapped Tiles
};
