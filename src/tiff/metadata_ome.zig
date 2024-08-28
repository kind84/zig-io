const std = @import("std");
const builtin = @import("builtin");
const xml = @import("../xml.zig");
const TIFFMetadata = @import("metadata.zig");
const utils = @import("utils.zig");
const TIFFDirectoryData = utils.TIFFDirectoryData;
const TIFFBlockInfo = utils.TIFFBlockInfo;
const Channel = @import("../core/Channel.zig");
const Size3 = @import("../core/size.zig").Size3;
const ImageFormat = @import("../core/slide.zig").ImageFormat;
const c = @import("metadata.zig").C;

pub const OMETIFFMetadata = @This();

arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,
channels: u16,
slices: u16,
plane_map: [][]usize,
metadata: *TIFFMetadata,

pub fn init(
    alloc: std.mem.Allocator,
    metadata: *TIFFMetadata,
    dirs: []TIFFDirectoryData,
) !?OMETIFFMetadata {
    defer {
        for (dirs) |dir| {
            dir.deinit();
        }
        alloc.free(dirs);
    }
    if (dirs.len == 0) return null;

    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    // find the first full resolution IFD
    var d: usize = 0;
    while (d < dirs.len) : (d += 1) {
        if (dirs[d].subFileType == 0) break;
    }

    if (d == dirs.len) {
        // No full resolution IFDs found
        // check for an Ultivue-style ome-tiff
        if (dirs[0].subFileType == 0x2) {
            d = 0;
        } else return null;
    }

    var ifd0: TIFFDirectoryData = dirs[d];

    if (ifd0.n_samples < 1 or ifd0.n_samples > 3) {
        return null;
    }

    metadata.size = ifd0.size;

    // Find all the TIFFDirectoryData that represent an image
    // of a matching size & type
    var full_resolution_dirs = std.ArrayList(usize).init(allocator);
    defer full_resolution_dirs.deinit();
    for (dirs, 0..) |dir, i| {
        if (dir.subFileType == 0 and std.meta.eql(dir.size, metadata.size)) {
            try full_resolution_dirs.append(i);
        }
    }

    const n_IFDs: u16 = @intCast(full_resolution_dirs.items.len);
    if (n_IFDs == 0) {
        std.debug.print("No valid images in file\n", .{});
        return null;
    }

    var index: usize = undefined;
    if (std.mem.indexOf(u8, ifd0.description, "www.openmicroscopy.org/Schemas/OME/201")) |idx| {
        index = idx;
    } else {
        std.debug.print("No OME-Schema\n", .{});
        return null;
    }

    const date = ifd0.description[index + 35 .. index + 35 + 7];
    if (!std.mem.eql(u8, date, "2016-06") and !std.mem.eql(u8, date, "2013-06")) {
        std.debug.print("Unsupported OME-Schema\n", .{});
        return null;
    }

    var xml_stream = xml.parse(allocator, ifd0.description) catch return null;
    defer xml_stream.deinit();

    var image = xml_stream.root.findChildByTag("Image") orelse return null;
    var pixels = image.findChildByTag("Pixels") orelse return null;

    const size_Z_string: []const u8 = pixels.getAttribute("SizeZ") orelse return null;
    var size_Z: u16 = std.fmt.parseInt(u16, size_Z_string, 10) catch 0;
    const size_C_string: []const u8 = pixels.getAttribute("SizeC") orelse return null;
    var size_C: u16 = std.fmt.parseInt(u16, size_C_string, 10) catch 0;
    const size_T_string: []const u8 = pixels.getAttribute("SizeT") orelse return null;
    const size_T: u16 = std.fmt.parseInt(u16, size_T_string, 10) catch 0;

    const physical_size_X_string: []const u8 = pixels.getAttribute("PhysicalSizeX") orelse "";
    const physical_size_X: f32 = std.fmt.parseFloat(f32, physical_size_X_string) catch 0;
    const unit_X: []const u8 = pixels.getAttribute("PhysicalSizeXUnit") orelse "";
    const physical_size_Y_string: []const u8 = pixels.getAttribute("PhysicalSizeY") orelse "";
    const physical_size_Y: f32 = std.fmt.parseFloat(f32, physical_size_Y_string) catch 0;
    const unit_Y: []const u8 = pixels.getAttribute("PhysicalSizeYUnit") orelse "";
    const physical_size_Z_string: []const u8 = pixels.getAttribute("PhysicalSizeZ") orelse "";
    const physical_size_Z: f32 = std.fmt.parseFloat(f32, physical_size_Z_string) catch 0;
    const unit_Z: []const u8 = pixels.getAttribute("PhysicalSizeZUnit") orelse "";
    const dimension_order: []const u8 = pixels.getAttribute("DimensionOrder") orelse "";

    if (size_T != 1) {
        std.debug.print("Unsupported multiple Timepoints in OME-tiff\n", .{});
        return null;
    }

    // for non-interleaved data there is 1 plane/IFD per channel
    // some files are incorrectly marked as "interleaved" so use nIFDs
    // to detect where n_samples is likely to be > 1
    var size_C_planes: u16 = undefined; // no of planes/ifds required for the channels of a z-plane

    // check for multiple samples
    if (ifd0.n_samples > 1) {
        size_C_planes = size_C / ifd0.n_samples;
        metadata.planarConfig = c.PLANARCONFIG_CONTIG;
    } else {
        size_C_planes = size_C;
        metadata.planarConfig = c.PLANARCONFIG_SEPARATE;
    }

    if (n_IFDs < size_C_planes * size_Z) {

        // failed to find all expected IFDs
        // so adjust sizes for missing planes
        std.debug.print("Missing IFDs adjusting size accordingly!\n", .{});

        if (size_C_planes == 1) {
            size_Z = n_IFDs;
        } else if (size_Z == 1) {

            // must be non-interleaved to be here
            size_C = n_IFDs * ifd0.n_samples;
            size_C_planes = n_IFDs;
        } else {
            std.debug.print("Unsupported Missing IFDs in 4D data!\n", .{});
            return null;
        }
    }

    var valid_IFDs: u16 = 0;
    var plane_outer = try allocator.alloc([]usize, size_Z);
    for (plane_outer) |*out| {
        out.* = try allocator.alloc(usize, size_C_planes);
    }

    var channel_list = try std.ArrayList(Channel).initCapacity(allocator, size_C);

    var xml_channels = pixels.findChildrenByTag("Channel");
    while (xml_channels.next()) |*xml_channel| {
        const name: []const u8 = xml_channel.*.getAttribute("Name") orelse "";
        const color: []const u8 = xml_channel.*.getAttribute("Color") orelse "";
        const acquisition_mode: []const u8 = xml_channel.*.getAttribute("AcquisitionMode") orelse "";
        const contrast_method: []const u8 = xml_channel.*.getAttribute("ContrastMethod") orelse "";
        const fluor: []const u8 = xml_channel.*.getAttribute("Fluor") orelse "";
        const emission_wavelength: []const u8 = xml_channel.*.getAttribute("EmissionWavelength") orelse "";

        var id_attribute: []const u8 = xml_channel.*.getAttribute("ID") orelse return null;
        var id: u16 = undefined;
        if (std.mem.indexOf(u8, id_attribute[8..], ":")) |id_index| {
            const id_string = id_attribute[id_index + 9 ..];
            id = std.fmt.parseInt(u16, id_string, 10) catch return null;
        } else return null;

        const spp_string: []const u8 = xml_channel.*.getAttribute("SamplesPerPixel") orelse return null;
        const samples_per_pixel: u16 = std.fmt.parseInt(u16, spp_string, 10) catch 0;
        if (samples_per_pixel != ifd0.n_samples) {
            std.debug.print("Unsupported inconsistent value in OME-XML!\n", .{});
            return null;
        }

        var channel = Channel{
            .name = undefined,
            .color = undefined,
            .contrastMethod = undefined,
            .fluor = undefined,
            .emissionWavelength = undefined,
            .exposureTime = undefined,
            .exposureTimeUnit = undefined,
        };

        if (id < size_C) {
            channel.name = name;
            channel.color = color;
            channel.contrastMethod = contrast_method;
            if (!std.mem.eql(u8, contrast_method, "")) {
                channel.emissionWavelength = emission_wavelength;
            } else if (std.mem.eql(u8, acquisition_mode, "Brightfield")) {
                channel.contrastMethod = acquisition_mode;
            }
            if (!std.mem.eql(u8, fluor, "")) {
                channel.fluor = fluor;
                if (std.mem.eql(u8, name, "")) {
                    channel.name = fluor;
                }
                if (std.mem.eql(u8, contrast_method, "")) {
                    channel.contrastMethod = "Fluorescence";
                }
            }
            if (!std.mem.eql(u8, emission_wavelength, "")) {}
            channel.emissionWavelength = emission_wavelength;

            // TODO: set emission wavelength unit
        }

        try channel_list.append(channel);
    }

    var xml_tiff_datas = pixels.findChildrenByTag("TiffData");
    while (xml_tiff_datas.next()) |xml_tiff_data| {
        var plane_count: i16 = -1;
        if (xml_tiff_data.attributes.len == 0) {
            std.debug.print("invalid empty TiffData in OME-XML\n", .{});
            return null;
        }

        const ifd_string: []const u8 = xml_tiff_data.getAttribute("IFD") orelse return null;
        const ifd: usize = std.fmt.parseInt(usize, ifd_string, 10) catch return null;
        const chan_string: []const u8 = xml_tiff_data.getAttribute("FirstC") orelse return null;
        const chan: usize = std.fmt.parseInt(usize, chan_string, 10) catch return null;
        const z_plane_string: []const u8 = xml_tiff_data.getAttribute("FirstZ") orelse return null;
        const z_plane: usize = std.fmt.parseInt(usize, z_plane_string, 10) catch return null;
        const plane_count_string: []const u8 = xml_tiff_data.getAttribute("PlaneCount") orelse return null;
        plane_count = std.fmt.parseInt(i16, plane_count_string, 10) catch return null;

        if (ifd < n_IFDs) { // valid IFD
            valid_IFDs += 1;
            plane_outer[z_plane][chan] = full_resolution_dirs.items[ifd];
        } else {
            if (plane_count == size_C_planes and size_Z == 1) {
                var c_plane: usize = 0;
                while (c_plane < size_C_planes) : (c_plane += 1) {
                    plane_outer[0][c_plane] = full_resolution_dirs.items[ifd + c_plane];
                }
                valid_IFDs += size_C_planes;
            } else {
                if (plane_count == size_Z and size_C_planes == 1) {
                    var z: usize = 0;
                    while (z < size_Z) : (z += 1) {
                        plane_outer[z][0] = full_resolution_dirs.items[ifd + z];
                    }
                    valid_IFDs += size_C_planes;
                }
            }
        }
    }

    // Handle Plane info to get exposure time
    // Only for Z==0 and T==0 Ke platform cannot handle
    // metadata for other planes yet
    var xml_planes = pixels.findChildrenByTag("Plane");

    while (xml_planes.next()) |xml_plane| {
        const exposure_time: []const u8 = xml_plane.getAttribute("ExposureTime") orelse "";
        const exposure_time_unit: []const u8 = xml_plane.getAttribute("ExposureTimeUnit") orelse "";

        const the_t_string: []const u8 = xml_plane.getAttribute("TheT") orelse return null;
        const the_t: i16 = std.fmt.parseInt(i16, the_t_string, 10) catch return null;
        const the_z_string: []const u8 = xml_plane.getAttribute("TheZ") orelse return null;
        const the_z: i16 = std.fmt.parseInt(i16, the_z_string, 10) catch return null;
        const the_c_string: []const u8 = xml_plane.getAttribute("TheC") orelse return null;
        const the_c: usize = std.fmt.parseInt(usize, the_c_string, 10) catch return null;

        // only collect exposure time for z== 0
        if (the_t == 0 and the_z == 0) {
            channel_list.items[the_c].exposureTime = exposure_time;
            channel_list.items[the_c].exposureTimeUnit = exposure_time_unit;
        }
    }

    // try to handle invalid ome-tiffs with no TiffData info in XML
    // by using the dimensionOrder specifief in the XML
    // requires  samplesPerPixel = 1
    if (valid_IFDs == 0 and n_IFDs == size_C_planes * size_Z) {
        valid_IFDs = n_IFDs;

        var valid_ifd: u16 = 0;
        if (std.mem.eql(u8, dimension_order, "XYZCT")) {
            var cc: u16 = 0;
            while (cc < size_C_planes) : (cc += 1) {
                var zz: u16 = 0;
                while (zz < size_Z) : (zz += 1) {
                    plane_outer[zz][cc] = full_resolution_dirs.items[valid_ifd];
                    valid_ifd += 1;
                }
            }
        } else if (std.mem.eql(u8, dimension_order, "XYCZT")) {
            var zz: u16 = 0;
            while (zz < size_Z) : (zz += 1) {
                var cc: u16 = 0;
                while (cc < size_C_planes) : (cc += 1) {
                    plane_outer[zz][cc] = full_resolution_dirs.items[valid_ifd];
                    valid_ifd += 1;
                }
            }
        } else {
            std.debug.print("Unsupported DimensionOrder in OME-XML!\n", .{});
            return null;
        }
    }

    // check all planes are in map
    if (n_IFDs != valid_IFDs) {
        std.debug.print("Unsupported XML values in OME-tiff\n", .{});
        std.debug.print("Found {d} planes in OME-XML! Expected {d}\n", .{ valid_IFDs, n_IFDs });
        return null;
    }

    metadata.typ = try utils.computeMatType(
        ifd0.format,
        ifd0.photometric,
        ifd0.nbits,
        ifd0.n_samples,
        size_C_planes,
    );

    metadata.size = ifd0.size;
    metadata.size.depth = size_Z;
    metadata.blocksize = ifd0.blocksize;

    // get resolution from tiff (required for some Ultivue tiffs)
    if (ifd0.xresolution > 0 and ifd0.yresolution > 0) {
        switch (ifd0.resolutionUnit) {
            c.RESUNIT_NONE => {}, // do nothing with unitless value (i.e. pixelsize_ == 0)
            c.RESUNIT_INCH => {
                metadata.pixelsize[0] = 25400.0 / ifd0.xresolution;
                metadata.pixelsize[1] = 25400.0 / ifd0.yresolution;
            },
            c.RESUNIT_CENTIMETER => {
                metadata.pixelsize[0] = 10000.0 / ifd0.xresolution;
                metadata.pixelsize[1] = 10000.0 / ifd0.yresolution;
            },
            else => {},
        }
    }

    // Now override for genuine OME-tiffs
    // TBD Handle other units
    if (std.mem.eql(u8, unit_X, "pixel") or std.mem.eql(u8, unit_X, "nm") or std.mem.eql(u8, unit_X, "µm") or std.mem.eql(u8, unit_X, "mm")) {
        switch (unit_X[0]) {
            'm' => metadata.pixelsize[0] = physical_size_X * 1000.0,
            'n' => metadata.pixelsize[0] = physical_size_X / 1000.0,
            else => metadata.pixelsize[0] = physical_size_X,
        }
    } else if (builtin.mode == std.builtin.Mode.Debug) {
        std.debug.print("Unrecognised pixel sizeX units\n", .{});
    }

    if (std.mem.eql(u8, unit_Y, "pixel") or std.mem.eql(u8, unit_Y, "nm") or std.mem.eql(u8, unit_Y, "µm") or std.mem.eql(u8, unit_Y, "mm")) {
        switch (unit_Y[0]) {
            'm' => metadata.pixelsize[1] = physical_size_Y * 1000.0,
            'n' => metadata.pixelsize[1] = physical_size_Y / 1000.0,
            else => metadata.pixelsize[1] = physical_size_Y,
        }
    } else if (builtin.mode == std.builtin.Mode.Debug) {
        std.debug.print("Unrecognised pixel sizeY units\n", .{});
    }

    if (std.mem.eql(u8, unit_Z, "pixel") or std.mem.eql(u8, unit_Z, "nm") or std.mem.eql(u8, unit_Z, "µm") or std.mem.eql(u8, unit_Z, "mm")) {
        switch (unit_Z[0]) {
            'm' => metadata.pixelsize[2] = physical_size_Z * 1000.0,
            'n' => metadata.pixelsize[2] = physical_size_Z / 1000.0,
            else => metadata.pixelsize[2] = physical_size_Z,
        }
    } else if (builtin.mode == std.builtin.Mode.Debug) {
        std.debug.print("Unrecognised pixel sizeZ units\n", .{});
    }

    metadata.imageFormat = ImageFormat.OME;

    return OMETIFFMetadata{
        .arena = arena,
        .allocator = allocator,
        .channels = size_C,
        .slices = size_Z,
        .plane_map = plane_outer,
        .metadata = metadata,
    };
}

pub fn deinit(self: OMETIFFMetadata) void {
    self.arena.deinit();
}

pub fn addBlock(self: OMETIFFMetadata, allocator: std.mem.Allocator) ![]TIFFBlockInfo {
    const m = self.metadata;

    const nbz: usize = m.size.depth / m.blocksize.depth;
    var nbc: usize = 0;
    const pc_u16: u16 = @intCast(c.PLANARCONFIG_CONTIG);
    if (m.planarConfig == pc_u16) {
        nbc = 1;
    } else if (m.typ) |typ| {
        nbc = typ.channels();
    }
    const nbb: usize = ((1 + ((m.size.width - 1) / m.blocksize.width)) *
        (1 + ((m.size.height - 1) / m.blocksize.height)));

    std.debug.print("{d}\n", .{nbb * nbc * nbz});
    var block_infos = try std.ArrayList(TIFFBlockInfo).initCapacity(allocator, nbb * nbc * nbz);
    var block: u32 = 0;
    var zz: usize = 0;
    while (zz < nbz) : (zz += 1) {
        var cc: usize = 0;
        while (cc < nbc) : (cc += 1) {
            var bb: usize = 0;
            while (bb < nbb) : (bb += 1) {
                const info = TIFFBlockInfo{
                    .tif = self.metadata.tif,
                    .dir = self.plane_map[zz][cc],
                    .block = block,
                };

                block_infos.appendAssumeCapacity(info);
                block += 1;
            }
        }
    }

    std.debug.print("Yay OMETIFF!\n", .{});
    return block_infos.toOwnedSlice();
}

test "init" {
    const allocator = std.testing.allocator;

    const path = "/home/paolo/src/keeneye/zig-io/testdata/AlaskaLynx_ROW9337883641_1024x1024.ome.tiff";
    var meta = try init(allocator, path);
    defer meta.deinit();

    try std.testing.expectEqual(ImageFormat.OME, meta.imageFormat);
}
