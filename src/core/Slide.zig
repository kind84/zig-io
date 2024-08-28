pub const Slide = @This();

imageFormat: ImageFormat,

// boost::filesystem::path path_;
//
// std::ios_base::openmode mode_;

typ: i32,
objective: f64,
focalPlaneMin: f64,
focalPlaneMax: f64,
pixelsize: @Vector(3, f64),

// SlideLayout* layout_;
//
// SlideCache* cache_;

//ChannelListType channelList_;

min: []f64,
max: []f64,

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
    JPGTIF = 0x0B, // tiff with jpeg compression
    JPEG = 0x0C, // Actual jpeg files
    SVS = 0x0D, // aperio .svs with 33003 0r 33005 or JPEG compression
    E2E = 0x0E, // Heidelberg E2E OCT files
    VEN = 0x0F, // Ventana
    MRX = 0x10, // MIRAX
    TIFFS = 0x11, // tiff_stack
    APER = 0x12, // Aperio tiff
    IJT = 0x13, // Imagej-tiff
    OME = 0x14, // OME-TIFF
    QPT = 0x15, // QPTIFF
    ISYNTAX = 0x16, // Philips Isyntax
};
