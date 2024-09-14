const std = @import("std");
const builtin = @import("builtin");
const BlockInfo = @import("./layout.zig").BlockInfo;
const Channel = @import("./Channel.zig");
const Layout = @import("./layout.zig").Layout;
const Rect = @import("rect.zig").Rect;
const Rect3 = @import("rect.zig").Rect3;
const Mat = @import("mat.zig").Mat;
const MatType = @import("mat.zig").MatType;
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
    typ: MatType,
    objective: f64,
    focalPlaneMin: f64,
    focalPlaneMax: f64,
    pixelsize: @Vector(3, f64),

    // TODO
    // SlideCache* cache_;

    channelList: []Channel,

    RGBABuffer: []u32,

    ptr: *anyopaque,
    openFn: if (builtin.zig_backend == .stage1)
        fn (ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) anyerror!void
    else
        *const fn (ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) anyerror!void,

    readBlockFromFileFn: if (builtin.zig_backend == .stage1)
        fn (ptr: *anyopaque, info: BlockInfo, dst: Mat) anyerror!void
    else
        *const fn (ptr: *anyopaque, info: BlockInfo, dst: Mat) anyerror!void,

    layoutFn: if (builtin.zig_backend == .stage1)
        fn (ptr: *anyopaque) *Layout
    else
        *const fn (ptr: *anyopaque) *Layout,

    pub fn init(
        pointer: anytype,
        imageFormat: ImageFormat,
        comptime openFn: fn (
            ptr: @TypeOf(pointer),
            path: []const u8,
            allocator: std.mem.Allocator,
        ) anyerror!void,
        comptime readBlockFromFileFn: fn (
            ptr: @TypeOf(pointer),
            info: BlockInfo,
            dst: Mat,
        ) anyerror!void,
        comptime layoutFn: fn (ptr: @TypeOf(pointer)) *Layout,
    ) Slide {
        const Ptr = @TypeOf(pointer);
        std.debug.assert(@typeInfo(Ptr) == .pointer); // Must be a pointer
        std.debug.assert(@typeInfo(Ptr).pointer.size == .One); // Must be a single-item pointer
        std.debug.assert(@typeInfo(@typeInfo(Ptr).pointer.child) == .@"struct"); // Must point to a struct
        const gen = struct {
            fn open(ptr: *anyopaque, path: []const u8, allocator: std.mem.Allocator) !void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                try openFn(self, path, allocator);
            }

            fn readBlockFromFile(ptr: *anyopaque, info: BlockInfo, dst: Mat) !void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                try readBlockFromFileFn(self, info, dst);
            }

            fn layout(ptr: *anyopaque) *Layout {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                return layoutFn(self);
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
            .ptr = pointer,
            .openFn = gen.open,
            .readBlockFromFileFn = gen.readBlockFromFile,
            .layoutFn = gen.layout,
        };
    }

    pub fn open(self: *const Slide, path: []const u8, allocator: std.mem.Allocator) !void {
        self.openFn(self.ptr, path, allocator);
    }

    pub fn readBlockFromFile(self: *const Slide, info: BlockInfo, dst: Mat) !void {
        try self.readBlockFromFileFn(self.ptr, info, dst);
    }

    pub fn layout(self: *const Slide) *Layout {
        return self.layoutFn(self.ptr);
    }

    pub fn getRegion(self: *Slide, allocator: std.mem.Allocator, region: Rect3(usize), channel: usize, dst: *Mat) !void {
        const range: []BlockInfo = try self.layout().getIntersect(region, channel);
        if (range.len == 0) return;

        // var dim: u2 = 0;
        // var sz = &[_]usize{ 0, 0, 0 };

        // if (region.depth == 1) {
        //     dim = 2;
        //     sz[0] = region.height;
        //     sz[1] = region.width;
        // } else {
        //     dim = 3;
        //     sz[0] = region.depth;
        //     sz[1] = region.height;
        //     sz[2] = region.width;
        // }

        const typ = if (self.isContiguous()) self.typ else self.depth();

        for (range) |info| {
            var src = try Mat.initEmpty(allocator, info.rect.height, info.rect.width, typ);
            try self.readBlockFromFile(info, src);
            try Slide.copyTo(allocator, info.rect, region, &src, dst);
        }
    }

    pub fn depth(self: Slide) MatType {
        // TODO
        _ = self;
        return MatType.CV_8SC1;
    }

    pub fn slices(self: Slide) usize {
        return self.layout().size.depth;
    }

    pub fn rows(self: Slide) usize {
        return self.layout().size.height;
    }

    pub fn cols(self: Slide) usize {
        return self.layout().size.width;
    }

    pub fn isContiguous(self: Slide) bool {
        return self.layout().contiguous;
    }

    fn isValidChannelSelection(channel: usize) bool {
        // TODO
        _ = channel;
        return true;
    }

    /// copies from src to dst the portion of r1 that overlaps r2.
    fn copyTo(allocator: std.mem.Allocator, r1: Rect3(usize), r2: Rect3(usize), src: *Mat, dst: *Mat) !void {
        const intersect = r1.intersect(r2) orelse return error.NoIntersection;

        const src_rect = Rect(usize).init(
            intersect.x - r1.x,
            intersect.y - r1.y,
            intersect.width,
            intersect.height,
        );
        const dst_rect = Rect(usize).init(
            intersect.x - r2.x,
            intersect.y - r2.y,
            intersect.width,
            intersect.height,
        );

        const src_z0 = intersect.z - r1.z;
        const dst_z0 = intersect.z - r2.z;
        var height: usize = undefined;
        var src_data: []u8 = undefined;
        var dst_data: []u8 = undefined;
        // const bytes_in_row = intersect.width * src.elemSize();

        if (src.dims == 2 and dst.dims == 2) {
            std.debug.assert(intersect.depth == 1);

            src_data.ptr = src.data.ptr + (src_rect.x * src.elemSize()) + (src_rect.y * src.step[0]);
            dst_data.ptr = dst.data.ptr + (dst_rect.x * dst.elemSize()) + (dst_rect.y * dst.step[0]);

            height = intersect.height;
        } else if (src.dims == 2) { // dst.dims != 2
            std.debug.assert(intersect.depth == 1);

            const src_sub_view: Mat = src.subMat(src_rect);

            var mat_data: []u8 = undefined;
            mat_data.ptr = dst.data.ptr + dst_z0 * dst.step[0];
            var dst_slice = try Mat.initFull(
                allocator,
                dst.sizes[1],
                dst.sizes[2],
                dst.typ,
                mat_data,
                null,
            );
            const dst_sub_view: Mat = dst_slice.subMat(dst_rect);

            src_data = src_sub_view.data;
            dst_data = dst_sub_view.data;
        } else if (dst.dims == 2) { // src.dims != 2
            std.debug.assert(intersect.depth == 1);

            var mat_data: []u8 = undefined;
            mat_data.ptr = src.data.ptr + src_z0 * src.step[0];
            var src_slice = try Mat.initFull(
                allocator,
                src.sizes[1],
                src.sizes[2],
                src.typ,
                mat_data,
                null,
            );
            const src_sub_view: Mat = src_slice.subMat(src_rect);

            const dst_sub_view: Mat = dst.subMat(dst_rect);

            src_data = src_sub_view.data;
            dst_data = dst_sub_view.data;
        } else { // dst.dims == 3 && src.dims == 3
            var zz: usize = 0;
            var mat_src_data: []u8 = undefined;
            mat_src_data.ptr = src.data.ptr + (src_z0 + zz) * src.step[0];
            var mat_dst_data: []u8 = undefined;
            mat_dst_data.ptr = dst.data.ptr + (dst_z0 + zz) * dst.step[0];
            while (zz < intersect.depth) : (zz += 1) {
                var src_slice = try Mat.initFull(
                    allocator,
                    src.sizes[1],
                    src.sizes[2],
                    src.typ,
                    mat_src_data,
                    null,
                );
                var dst_slice = try Mat.initFull(
                    allocator,
                    dst.sizes[1],
                    dst.sizes[2],
                    dst.typ,
                    mat_dst_data,
                    null,
                );

                const src_sub_view: Mat = src_slice.subMat(src_rect);
                const dst_sub_view: Mat = dst_slice.subMat(dst_rect);

                src_data = src_sub_view.data;
                dst_data = dst_sub_view.data;
            }
        }

        var i: usize = 0;
        while (i < height) : (i += 1) {
            @memcpy(dst_data, src_data);

            src_data.ptr += src.step[0];
            dst_data.ptr += dst.step[0];
        }
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
