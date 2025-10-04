/**
    Niobium Metal Textures
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.texture;
import niobium.pixelformat;
import niobium.mtl.device;
import niobium.mtl.heap;
import niobium.texture;
import niobium.resource;
import niobium.device;
import niobium.types;
import numem;
import metal.pixelformat;
import metal.texture;
import metal.types;
import foundation;

/**
    Vulkan Texture
*/
class NioMTLTexture : NioTexture {
private:
@nogc:
    MTLTexture              handle_;
    NioTextureDescriptor    desc_;

    void createTexture(NioTextureDescriptor desc) {
        auto nmtlDevice = cast(NioMTLDevice)device;
        this.desc_ = desc;

        auto createInfo = MTLTextureDescriptor.alloc.init;
        createInfo.textureType = desc.type.toMTLTextureType();
        createInfo.pixelFormat = desc.format.toMTLPixelFormat();
        createInfo.width = desc.width;
        createInfo.height = desc.height;
        createInfo.depth = desc.depth;
        createInfo.mipmapLevelCount = desc.levels;
        createInfo.arrayLength = desc.layers;
        createInfo.usage = desc.usage.toMTLTextureUsage();
        createInfo.sampleCount = 1;
        createInfo.compressionType = MTLTextureCompressionType.Lossless;
        createInfo.swizzle = MTLTextureSwizzleChannels(
            MTLTextureSwizzle.Red, 
            MTLTextureSwizzle.Green, 
            MTLTextureSwizzle.Blue, 
            MTLTextureSwizzle.Alpha
        );
        this.handle_ = nmtlDevice.handle.newTexture(createInfo);
        createInfo.release();
    }

    void createTextureView(NioMTLTexture texture, NioTextureDescriptor desc) {
        this.desc_ = NioTextureDescriptor(
            type: desc.type,
            format: desc.format,
            storage: texture.storageMode,
            usage: texture.usage,
            width: texture.width,
            height: texture.height,
            depth: texture.depth,
            levels: desc.levels,
            layers: desc.layers
        );
        this.handle_ = texture.handle.newTextureView(
            desc_.format.toMTLPixelFormat(),
            desc_.type.toMTLTextureType(),
            NSRange(0, desc_.levels),
            NSRange(0, desc_.layers),
        );
    }

    void referenceTexture(MTLTexture texture) {
        texture.retain();

        this.desc_ = NioTextureDescriptor(
            type: texture.textureType.toNioTextureType(),
            format: texture.pixelFormat.toNioPixelFormat(),
            storage: texture.storageMode.toNioStorageMode(),
            usage: texture.usage.toNioTextureUsage(),
            width: cast(uint)texture.width,
            height: cast(uint)texture.height,
            depth: cast(uint)texture.depth,
            levels: cast(uint)texture.mipmapLevelCount,
            layers: cast(uint)texture.arrayLength
        );
        this.handle_ = texture;
    }

protected:

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override
    void onLabelChanged(string label) {
        if (handle_.label)
            handle_.label.release();
        
        handle_.label = NSString.create(label);
    }

public:

    /**
        The underlying metal handle.
    */
    final @property MTLTexture handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new $(D NioMTLTexture) from a descriptor.

        Params:
            device =    The device to create the texture on.
            desc =      Descriptor used to create the texture.
    */
    this(NioDevice device, NioTextureDescriptor desc) {
        super(device);
        this.createTexture(desc);
    }

    /**
        Constructs a new $(D NioMTLTexture) as a view of another texture.

        Params:
            device =    The device to create the texture on.
            texture =   Texture to create a view of.
            desc =      Descriptor used to create the texture.
    */
    this(NioDevice device, NioTexture texture, NioTextureDescriptor desc) {
        super(device);
        this.createTextureView(cast(NioMTLTexture)texture, desc);
    }

    /**
        Constructs a new $(D NioMTLTexture) from an existing
        metal texture.

        Params:
            device =    The device to create the texture on.
            texture =   Texture to create a view of.
    */
    this(NioDevice device, MTLTexture texture) {
        super(device);
        this.referenceTexture(texture);
    }

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => cast(uint)handle_.allocatedSize;

    /**
        The pixel format of the texture.
    */
    override @property NioPixelFormat format() => desc_.format;

    /**
        The type of the texture.
    */
    override @property NioTextureType type() => desc_.type;

    /**
        The usage flags of the texture.
    */
    override @property NioTextureUsage usage() => desc_.usage;

    /**
        Storage mode of the resource.
    */
    override @property NioStorageMode storageMode() => desc_.storage;

    /**
        Width of the texture in pixels.
    */
    override @property uint width() => desc_.width;

    /**
        Height of the texture in pixels.
    */
    override @property uint height() => desc_.height;

    /**
        Depth of the texture in pixels.
    */
    override @property uint depth() => desc_.depth;

    /**
        Array layer count of the texture.
    */
    override @property uint layers() => desc_.layers;

    /**
        Mip level count of the texture.
    */
    override @property uint levels() => desc_.levels;

    /**
        Uploads data to the texture using a device-internal
        transfer queue.

        This is overall a slow operation, uploading via
        a $(D NioTransferCommandEncoder) is recommended.

        Params:
            region =    The region of the texture to upload to.
            level =     The mipmap level of the texture to upload to.
            slice =     The array slice of the texture to upload to, for non-array textures, set to 0.
            data =      The data to upload.
            rowStride = The stride of a single row of pixels.
    
        Returns:
            The calling texture, allowing chaining.
    */
    override NioTexture upload(NioRegion3D region, uint level, uint slice, void[] data, uint rowStride) {
        auto mtlregion = *(cast(MTLRegion*)&region);
        this.handle_.replace(
            mtlregion,
            level,
            slice,
            data.ptr,
            rowStride*format.toStride(),
            0
        );
        return this;
    }
}

/**
    Converts a $(D NioPixelFormat) format to its $(D MTLPixelFormat) equivalent.

    Params:
        format = The $(D NioPixelFormat)
    
    Returns:
        The $(D MTLPixelFormat) equivalent.
*/
pragma(inline, true)
MTLPixelFormat toMTLPixelFormat(NioPixelFormat format) @nogc {
    final switch(format) with(NioPixelFormat) {
        case unknown:               return MTLPixelFormat.Invalid;
        case a8Unorm:               return MTLPixelFormat.A8Unorm;
        case r8Unorm:               return MTLPixelFormat.R8Unorm;
        case r8UnormSRGB:           return MTLPixelFormat.R8Unorm_sRGB;
        case r8Snorm:               return MTLPixelFormat.R8Snorm;
        case r8Uint:                return MTLPixelFormat.R8Uint;
        case r8Sint:                return MTLPixelFormat.R8Sint;
        case r16Unorm:              return MTLPixelFormat.R16Unorm;
        case r16Uint:               return MTLPixelFormat.R16Uint;
        case r16Sint:               return MTLPixelFormat.R16Sint;
        case r16Float:              return MTLPixelFormat.R16Float;
        case r32Uint:               return MTLPixelFormat.R32Uint;
        case r32Sint:               return MTLPixelFormat.R32Sint;
        case r32Float:              return MTLPixelFormat.R32Float;
        case rg8Unorm:              return MTLPixelFormat.RG8Unorm;
        case rg8UnormSRGB:          return MTLPixelFormat.RG8Unorm_sRGB;
        case rg8Snorm:              return MTLPixelFormat.RG8Snorm;
        case rg8Uint:               return MTLPixelFormat.RG8Uint;
        case rg8Sint:               return MTLPixelFormat.RG8Sint;
        case rg16Unorm:             return MTLPixelFormat.RG16Unorm;
        case rg16Snorm:             return MTLPixelFormat.RG16Snorm;
        case rg16Uint:              return MTLPixelFormat.RG16Uint;
        case rg16Sint:              return MTLPixelFormat.RG16Sint;
        case rg16Float:             return MTLPixelFormat.RG16Float;
        case rg32Uint:              return MTLPixelFormat.RG32Uint;
        case rg32Sint:              return MTLPixelFormat.RG32Sint;
        case rg32Float:             return MTLPixelFormat.RG32Float;
        case rgba8Unorm:            return MTLPixelFormat.RGBA8Unorm;
        case rgba8UnormSRGB:        return MTLPixelFormat.RGBA8Unorm_sRGB;
        case rgba8Snorm:            return MTLPixelFormat.RGBA8Snorm;
        case rgba8Uint:             return MTLPixelFormat.RGBA8Uint;
        case rgba8Sint:             return MTLPixelFormat.RGBA8Sint;
        case rgba16Unorm:           return MTLPixelFormat.RGBA16Unorm;
        case rgba16Snorm:           return MTLPixelFormat.RGBA16Snorm;
        case rgba16Uint:            return MTLPixelFormat.RGBA16Uint;
        case rgba16Sint:            return MTLPixelFormat.RGBA16Sint;
        case rgba32Uint:            return MTLPixelFormat.RGBA32Uint;
        case rgba32Sint:            return MTLPixelFormat.RGBA32Sint;
        case rgba32Float:           return MTLPixelFormat.RGBA32Float;
        case bgra8Unorm:            return MTLPixelFormat.BGRA8Unorm;
        case bgra8UnormSRGB:        return MTLPixelFormat.BGRA8Unorm_sRGB;
        case rgbaUnorm_BC1:         return MTLPixelFormat.BC1_RGBA;
        case rgbaUnormSRGB_BC1:     return MTLPixelFormat.BC1_RGBA_sRGB;
        case rgbaUnorm_BC2:         return MTLPixelFormat.BC2_RGBA;
        case rgbaUnormSRGB_BC2:     return MTLPixelFormat.BC2_RGBA_sRGB;
        case rgbaUnorm_BC3:         return MTLPixelFormat.BC3_RGBA;
        case rgbaUnormSRGB_BC3:     return MTLPixelFormat.BC3_RGBA_sRGB;
        case rgbaUnorm_BC7:         return MTLPixelFormat.BC7_RGBAUnorm;
        case rgbaUnormSRGB_BC7:     return MTLPixelFormat.BC7_RGBAUnorm_sRGB;
        case depth24Stencil8:       return MTLPixelFormat.Depth24Unorm_Stencil8;
        case depth32Stencil8:       return MTLPixelFormat.Depth32Float_Stencil8;
        case x24Stencil8:           return MTLPixelFormat.X24_Stencil8;
        case x32Stencil8:           return MTLPixelFormat.X32_Stencil8;
    }
}

/**
    Converts a $(D MTLPixelFormat) format to its $(D NioPixelFormat) equivalent.

    Params:
        format = The $(D MTLPixelFormat)
    
    Returns:
        The $(D NioPixelFormat) equivalent.
*/
pragma(inline, true)
NioPixelFormat toNioPixelFormat(MTLPixelFormat format) @nogc {
    switch(format) with(MTLPixelFormat) {
        default:                        return NioPixelFormat.unknown;
        case A8Unorm:                   return NioPixelFormat.a8Unorm;
        case R8Unorm:                   return NioPixelFormat.r8Unorm;
        case R8Unorm_sRGB:              return NioPixelFormat.r8UnormSRGB;
        case R8Snorm:                   return NioPixelFormat.r8Snorm;
        case R8Uint:                    return NioPixelFormat.r8Uint;
        case R8Sint:                    return NioPixelFormat.r8Sint;
        case R16Unorm:                  return NioPixelFormat.r16Unorm;
        case R16Uint:                   return NioPixelFormat.r16Uint;
        case R16Sint:                   return NioPixelFormat.r16Sint;
        case R16Float:                  return NioPixelFormat.r16Float;
        case R32Uint:                   return NioPixelFormat.r32Uint;
        case R32Sint:                   return NioPixelFormat.r32Sint;
        case R32Float:                  return NioPixelFormat.r32Float;
        case RG8Unorm:                  return NioPixelFormat.rg8Unorm;
        case RG8Unorm_sRGB:             return NioPixelFormat.rg8UnormSRGB;
        case RG8Snorm:                  return NioPixelFormat.rg8Snorm;
        case RG8Uint:                   return NioPixelFormat.rg8Uint;
        case RG8Sint:                   return NioPixelFormat.rg8Sint;
        case RG16Unorm:                 return NioPixelFormat.rg16Unorm;
        case RG16Snorm:                 return NioPixelFormat.rg16Snorm;
        case RG16Uint:                  return NioPixelFormat.rg16Uint;
        case RG16Sint:                  return NioPixelFormat.rg16Sint;
        case RG16Float:                 return NioPixelFormat.rg16Float;
        case RG32Uint:                  return NioPixelFormat.rg32Uint;
        case RG32Sint:                  return NioPixelFormat.rg32Sint;
        case RG32Float:                 return NioPixelFormat.rg32Float;
        case RGBA8Unorm:                return NioPixelFormat.rgba8Unorm;
        case RGBA8Unorm_sRGB:           return NioPixelFormat.rgba8UnormSRGB;
        case RGBA8Snorm:                return NioPixelFormat.rgba8Snorm;
        case RGBA8Uint:                 return NioPixelFormat.rgba8Uint;
        case RGBA8Sint:                 return NioPixelFormat.rgba8Sint;
        case RGBA16Unorm:               return NioPixelFormat.rgba16Unorm;
        case RGBA16Snorm:               return NioPixelFormat.rgba16Snorm;
        case RGBA16Uint:                return NioPixelFormat.rgba16Uint;
        case RGBA16Sint:                return NioPixelFormat.rgba16Sint;
        case RGBA32Uint:                return NioPixelFormat.rgba32Uint;
        case RGBA32Sint:                return NioPixelFormat.rgba32Sint;
        case RGBA32Float:               return NioPixelFormat.rgba32Float;
        case BGRA8Unorm:                return NioPixelFormat.bgra8Unorm;
        case BGRA8Unorm_sRGB:           return NioPixelFormat.bgra8UnormSRGB;
        case BC1_RGBA:                  return NioPixelFormat.rgbaUnorm_BC1;
        case BC1_RGBA_sRGB:             return NioPixelFormat.rgbaUnormSRGB_BC1;
        case BC2_RGBA:                  return NioPixelFormat.rgbaUnorm_BC2;
        case BC2_RGBA_sRGB:             return NioPixelFormat.rgbaUnormSRGB_BC2;
        case BC3_RGBA:                  return NioPixelFormat.rgbaUnorm_BC3;
        case BC3_RGBA_sRGB:             return NioPixelFormat.rgbaUnormSRGB_BC3;
        case BC7_RGBAUnorm:             return NioPixelFormat.rgbaUnorm_BC7;
        case BC7_RGBAUnorm_sRGB:        return NioPixelFormat.rgbaUnormSRGB_BC7;
        case Depth24Unorm_Stencil8:     return NioPixelFormat.depth24Stencil8;
        case Depth32Float_Stencil8:     return NioPixelFormat.depth32Stencil8;
        case X24_Stencil8:              return NioPixelFormat.x24Stencil8;
        case X32_Stencil8:              return NioPixelFormat.x32Stencil8;
    }
}

/**
    Converts a $(D NioTextureType) type to its $(D MTLTextureType) equivalent.

    Params:
        type = The $(D NioTextureType)
    
    Returns:
        The $(D MTLTextureType) equivalent.
*/
pragma(inline, true)
MTLTextureType toMTLTextureType(NioTextureType type) @nogc {
    final switch(type) with(NioTextureType) {
        case type1D:                    return MTLTextureType.Type1D;
        case type1DArray:               return MTLTextureType.Type1DArray;
        case type2D:                    return MTLTextureType.Type2D;
        case type2DArray:               return MTLTextureType.Type2DArray;
        case type2DMultisample:         return MTLTextureType.Type2DMultisample;
        case typeCube:                  return MTLTextureType.TypeCube;
        case typeCubeArray:             return MTLTextureType.TypeCubeArray;
        case type3D:                    return MTLTextureType.Type3D;
        case type2DMultisampleArray:    return MTLTextureType.Type2DMultisampleArray;
    }
}

/**
    Converts a $(D MTLTextureType) type to its $(D NioTextureType) equivalent.

    Params:
        type = The $(D MTLTextureType)
    
    Returns:
        The $(D NioTextureType) equivalent.
*/
pragma(inline, true)
NioTextureType toNioTextureType(MTLTextureType type) @nogc {
    switch(type) with(MTLTextureType) {
        default:                        return NioTextureType.type2D;
        case Type1D:                    return NioTextureType.type1D;
        case Type1DArray:               return NioTextureType.type1DArray;
        case Type2D:                    return NioTextureType.type2D;
        case Type2DArray:               return NioTextureType.type2DArray;
        case Type2DMultisample:         return NioTextureType.type2DMultisample;
        case TypeCube:                  return NioTextureType.typeCube;
        case TypeCubeArray:             return NioTextureType.typeCubeArray;
        case Type3D:                    return NioTextureType.type3D;
        case Type2DMultisampleArray:    return NioTextureType.type2DMultisampleArray;
    }
}

/**
    Converts a $(D NioTextureUsage) bitmask to its $(D MTLTextureUsage) equivalent.

    Params:
        usage = The $(D NioTextureUsage)
    
    Returns:
        The $(D MTLTextureUsage) equivalent.
*/
pragma(inline, true)
MTLTextureUsage toMTLTextureUsage(NioTextureUsage usage) @nogc {
    uint result = 0;

    if (usage & NioTextureUsage.sampled)
        result |= MTLTextureUsage.ShaderRead | MTLTextureUsage.ShaderWrite;

    if (usage & NioTextureUsage.attachment)
        result |= MTLTextureUsage.RenderTarget;
    
    return cast(MTLTextureUsage)result;
}

/**
    Converts a $(D MTLTextureUsage) bitmask to its $(D NioTextureUsage) equivalent.

    Params:
        usage = The $(D MTLTextureUsage)
    
    Returns:
        The $(D NioTextureUsage) equivalent.
*/
pragma(inline, true)
NioTextureUsage toNioTextureUsage(MTLTextureUsage usage) @nogc {
    uint result = 
        NioTextureUsage.videoEncode | 
        NioTextureUsage.videoDecode | 
        NioTextureUsage.transfer;

    if (usage & MTLTextureUsage.ShaderRead)
        result |= NioTextureUsage.sampled;

    if (usage & MTLTextureUsage.ShaderWrite)
        result |= NioTextureUsage.sampled;

    if (usage & MTLTextureUsage.RenderTarget)
        result |= NioTextureUsage.attachment;
    
    return cast(NioTextureUsage)result;
}