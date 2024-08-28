const std = @import("std");
const xml = @import("../xml.zig");
const TIFFMetadata = @import("metadata.zig");
const TIFFDirectoryData = @import("utils.zig").TIFFDirectoryData;
const Channel = @import("../core/Channel.zig");
const Size3 = @import("../core/size.zig").Size3;
const c = @import("metadata.zig").C;

pub const OMETIFFMetadata = @This();

plane_map: [][]u16,

pub fn init(
    allocator: std.mem.Allocator,
    metadata: *TIFFMetadata,
    dirs: []TIFFDirectoryData,
) !?OMETIFFMetadata {
    if (dirs.len == 0) return null;

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
    for (dirs) |dir, i| {
        if (dir.subFileType == 0 and std.meta.eql(dir.size, metadata.size)) {
            try full_resolution_dirs.append(i);
        }
    }

    var n_IFDs = full_resolution_dirs.len;
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

    var date = ifd0.description[index + 35 .. index + 35 + 7];
    if (!std.mem.eql(u8, date, "2016-06") and !std.mem.eql(u8, date, "2013-06")) {
        std.debug.print("Unsupported OME-Schema\n", .{});
        return null;
    }

    std.debug.print("{s}\n", .{ifd0.description});
    // var xml_stream = xml.parse(allocator, ifd0.description) catch return null;
    var xml_stream = try xml.parse(allocator, ifd0.description);
    defer xml_stream.deinit();

    var image = xml_stream.root.findChildByTag("Image");
    var pixels = image.findChildByTag("Pixels") orelse return null;
    var size_Z: u16 = pixels.getAttribute("SizeZ");
    var size_C: u16 = pixels.getAttribute("SizeC");
    var size_T: u16 = pixels.getAttribute("SizeT");
    var physical_size_X: f32 = pixels.getAttribute("PhysicalSizeX");
    var unit_X: []const u8 = pixels.getAttribute("PhysicalSizeXUnit");
    var physical_size_Y: f32 = pixels.getAttribute("PhysicalSizeY");
    var unit_Y: []const u8 = pixels.getAttribute("PhysicalSizeYUnit");
    var physical_size_Z: f32 = pixels.getAttribute("PhysicalSizeZ");
    var unit_Z: []const u8 = pixels.getAttribute("PhysicalSizeZUnit");

    if (size_T != 1) {
        std.debug.print("Unsupported multiple Timepoints in OME-tiff");
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
        std.debug.print("Missing IFDs adjusting size accordingly!");

        if (size_C_planes == 1) {
            size_Z = n_IFDs;
        } else if (size_Z == 1) {

            // must be non-interleaved to be here
            size_C = n_IFDs * ifd0.n_samples;
            size_C_planes = n_IFDs;
        } else {
            std.debug.print("Unsupported Missing IFDs in 4D data!");
            return null;
        }
    }

    var validIFDs: u16 = 0;
    // TODO allocate plane_map
    var plane_outer = try allocator.alloc([]u16, size_Z);

    var channel_list = try std.ArrayList(Channel).initCapacity(allocator, size_C);

    var xml_channels = pixels.findChildrenByTag("Channel");
    while (xml_channels.next()) |xml_channel| {
        var name: []const u8 = xml_channel.getAttribute("Name");
        var color: []const u8 = xml_channel.getAttribute("Color");
        var acquisition_mode: []const u8 = xml_channel.getAttribute("AcquisitionMode");
        var contrast_method: []const u8 = xml_channel.getAttribute("ContrastMethod");
        var fluor: []const u8 = xml_channel.getAttribute("Fluor");
        var emission_wavelength: []const u8 = xml_channel.getAttribute("EmissionWavelength");

        var id_attribute: []const u8 = xml_channel.getAttribute("ID");
        var id_index: usize = undefined;
        if (std.mem.indexOf(u8, id_attribute[8..], ":")) |id_idx| {
            id_index = id_idx;
        } else return null;
        var id_string = ifd0.description[id_index + 1 ..];
        var id = try std.fmt.parseInt(id_string);
        //var id = std.fmt.parseInt(id_string) catch return null;

        var spp_string: []const u8 = xml_channel.getAttribute("SamplesPerPixel");
        var samples_per_pixel = std.fmt.parseInt(spp_string) catch return null;
        if (samples_per_pixel != ifd0.n_samples) {
            std.debug.print("Unsupported inconsistent value in OME-XML!");
            return null;
        }

        var channel = Channel{};
        
        if (id > -1 and id < size_C) {
            channel.name = name;
            channel.color = color;
            channel.contrastMethod = contrast_method;
            if (contrast_method != ""){
                channel.emissionWavelength = emission_wavelength;
            } else if (acquisition_mode == "Brightfield") {
                channel.contrastMethod = acquisition_mode;
            }
            if (fluor != ""){
                channel.fluor = fluor;
                if (name == ""){
                    channel.name = fluor;
                }
                if (contrast_method == "") {
                    channel.contrastMethod = "Fluorescence";
                }
            }
            channel.emissionWavelength = emission_wavelength;
        }
    }

    return OMETIFFMetadata{};
}

pub fn addBlock(self: OMETIFFMetadata, tif: *c.TIFF) !void {
    _ = self;
    _ = tif;
    std.debug.print("Yay OMETIFF!\n", .{});
}
