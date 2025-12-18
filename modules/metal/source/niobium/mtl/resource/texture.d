/**
    Niobium Metal Textures
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.resource.texture;
import niobium.mtl.resource;
import niobium.mtl.device;
import niobium.mtl.heap;
import niobium.mtl.utils;
import numem;
import metal.texture;
import metal.types;
import foundation;

public import niobium.texture;
public import niobium.mtl.formats;

/**
    Vulkan Texture
*/
class NioMTLTexture : NioTexture {
private:
@nogc:
    MTLTexture              handle_;
    NioTextureDescriptor    desc_;

    void createTexture(NioTextureDescriptor desc) {
        .autorelease(() {
            auto mtlDevice = cast(NioMTLDevice)device;
            this.desc_ = desc;

            auto createInfo = MTLTextureDescriptor.alloc.init.autoreleased;
            createInfo.textureType = desc.type.toMTLTextureType();
            createInfo.pixelFormat = desc.format.toMTLPixelFormat();
            createInfo.width = desc.width;
            createInfo.height = desc.height;
            createInfo.depth = desc.depth;
            createInfo.mipmapLevelCount = desc.levels;
            createInfo.arrayLength = desc.slices;
            createInfo.usage = desc.usage.toMTLTextureUsage();
            createInfo.sampleCount = 1;
            createInfo.compressionType = MTLTextureCompressionType.Lossless;
            createInfo.swizzle = MTLTextureSwizzleChannels(
                MTLTextureSwizzle.Red, 
                MTLTextureSwizzle.Green, 
                MTLTextureSwizzle.Blue, 
                MTLTextureSwizzle.Alpha
            );
            this.handle_ = mtlDevice.handle.newTexture(createInfo);
        });
    }

    void createTextureView(NioMTLTexture texture, NioTextureDescriptor desc, uint baseSlice, uint baseLevel) {
        .autorelease(() {
            this.desc_ = NioTextureDescriptor(
                type: desc.type,
                format: desc.format,
                storage: texture.storageMode,
                usage: texture.usage,
                width: texture.width,
                height: texture.height,
                depth: texture.depth,
                levels: desc.levels,
                slices: desc.slices
            );

            this.handle_ = (cast(MTLTexture)texture.handle).newTextureView(
                desc_.format.toMTLPixelFormat(),
                desc_.type.toMTLTextureType(),
                NSRange(baseSlice, desc_.levels),
                NSRange(baseLevel, desc_.slices),
            );
        });
    }

    void referenceTexture(MTLTexture texture) {
        .autorelease(() {
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
                slices: cast(uint)texture.arrayLength
            );
            this.handle_ = texture;
        });
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
    override @property void* handle() => cast(void*)handle_;

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
            baseSlice = Base texture slice
            baseLevel = Base mip level
    */
    this(NioDevice device, NioTexture texture, NioTextureDescriptor desc, uint baseSlice, uint baseLevel) {
        super(device);
        this.createTextureView(cast(NioMTLTexture)texture, desc, baseSlice, baseLevel);
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
    override @property uint slices() => desc_.slices;

    /**
        Mip level count of the texture.
    */
    override @property uint levels() => desc_.levels;

    /**
        Whether the texture can be shared between process boundaries.
    */
    override @property bool isShareable() => handle_.shareable;

    /**
        Exported handle for the texture.
    */
    override @property NioSharedResourceHandle sharedHandle() => null;

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
        auto mtlregion = MTLRegion(
            MTLOrigin(region.x, region.y, region.z),
            MTLSize(region.width, region.height, region.depth),
        );
        uint rRowStride = rowStride > 0 ? rowStride*format.toStride() : region.width*format.toStride();
        uint rImageStride = region.depth > 1 ? rRowStride*region.height : 0;

        this.handle_.replace(
            mtlregion,
            level,
            slice,
            data.ptr,
            rRowStride,
            rImageStride
        );
        return this;
    }
    
    /**
        Downloads data from a texture.
        
        Params:
            region =    Region to download
            level =     Mip level to download
            slice =     Array slice to download
            rowStride = The stride of a single row of pixels.
        
        Returns:
            A nogc slice of data on success,
            $(D null) otherwise.
    */
    override void[] download(NioRegion3D region, uint level, uint slice, uint rowStride) {
        auto mtlregion = MTLRegion(
            MTLOrigin(region.x, region.y, region.z),
            MTLSize(region.width, region.height, region.depth),
        );
        
        void[] result = cast(void[])nu_malloca!ubyte(region.extent.height*rowStride);
        handle_.getBytes(result.ptr, rowStride, 0, mtlregion, level, slice);
        return result;
    }

    /**
        Creates a new texture which reinterprets the data of this
        texture.

        Params:
            format =    Pixel format to interpret the texture as.
        
        Returns:
            A new $(D NioTexture) on success,
            $(D null) otherwise.
    */
    override NioTexture createView(NioPixelFormat format) {
        return nogc_new!NioMTLTexture(device, this, NioTextureDescriptor(format: format), 0, 0);
    }

    /**
        Creates a new texture which reinterprets the data of this
        texture.

        Params:
            format =        Pixel format to interpret the texture as.
            type =          The texture type to interpret the texture as.
            baseLevel =     The base mip level to interpret
            baseSlice =     The base array slice to interpret
            levels =        The levels to interpret.
            slices =        The slices to interpret.
        
        Returns:
            A new $(D NioTexture) on success,
            $(D null) otherwise.
    */
    override NioTexture createView(NioPixelFormat format, NioTextureType type, uint baseLevel, uint baseSlice, uint levels, uint slices) {
        return nogc_new!NioMTLTexture(device, this, NioTextureDescriptor(type: type, format: format, levels: levels, slices: slices), baseSlice, baseLevel);
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