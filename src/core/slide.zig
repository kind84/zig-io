const std = @import("std");
const builtin = @import("builtin");
const Channel = @import("./Channel.zig");
const Rect3 = @import("rect.zig").Rect3;
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
            .ptr = pointer,
            .openFn = gen.open,
        };
    }

    pub fn open(self: Slide, path: []const u8, allocator: std.mem.Allocator) !void {
        self.openFn(self.ptr, path, allocator);
    }

    pub fn getRegion(self: Slide, region: Rect3(u32), channel: u32, dst: []u8) !void {
        // TODO
        _ = self;
        _ = region;
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

    fn copyTo(self: Slide, r1: Rect3(u32), r2: Rect3(u32), src: []u8, dst: []u8) !void {
        var intersect = r1.intersect(r2) orelse return error.NoIntersection;

        _ = intersect;
        _ = self;
        _ = r1;
        _ = r2;
        _ = src;
        _ = dst;
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
