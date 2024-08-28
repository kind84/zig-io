pub const Channel = @This();

name: []const u8,

// 32-bit int as string
// "-1" is #FFFFFFFF so solid white (it is a signed 32 bit value)
// NB unsigned would be much safer
// but we need to match the OME standard
// see ToDo on
// https://downloads.openmicroscopy.org/bio-formats-cpp/5.1.1/api/classome_1_1xml_1_1model_1_1primitives_1_1Color.html
color: []const u8,
contrastMethod: []const u8,
fluor: []const u8,
