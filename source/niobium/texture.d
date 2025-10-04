/**
    Niobium Textures
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.texture;
import niobium.pixelformat;
import niobium.resource;
import niobium.device;
import niobium.types;

/**
    Used to construct a $(D NioTexture) from a device,
    the descriptor is used to describe the texture.
*/
struct NioTextureDescriptor {

    /**
        The kind of texture being made.
    */
    NioTextureType type = NioTextureType.type2D;
    
    /**
        The format of pixels in the texture.
    */
    NioPixelFormat format;

    /**
        Storage mode of the texture.
    */
    NioStorageMode storage = NioStorageMode.privateStorage;

    /**
        Usage flags for the texture.
    */
    NioTextureUsage usage = NioTextureUsage.transfer | NioTextureUsage.sampled;
    
    /**
        Width of the texture in pixels.
    */
    uint width;
    
    /**
        Height of the texture in pixels.
    */
    uint height;
    
    /**
        Depth of the texture in pixels.
    */
    uint depth = 1;
    
    /**
        Mip level count of the texture.
    */
    uint levels = 1;
    
    /**
        Array layer count of the texture.
    */
    uint layers = 1;
}

/**
    A texture.
*/
abstract
class NioTexture : NioResource {
protected:
@nogc:

    /**
        Constructs a new texture.

        Params:
            device = The device that "owns" this texture.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        Extent of the texture in pixels.
    */
    final @property NioExtent3D extent() => NioExtent3D(width, height, depth); 

    /**
        The pixel format of the texture.
    */
    abstract @property NioPixelFormat format();

    /**
        The type of the texture.
    */
    abstract @property NioTextureType type();

    /**
        The usage flags of the texture.
    */
    abstract @property NioTextureUsage usage();

    /**
        Width of the texture in pixels.
    */
    abstract @property uint width();

    /**
        Height of the texture in pixels.
    */
    abstract @property uint height();

    /**
        Depth of the texture in pixels.
    */
    abstract @property uint depth();

    /**
        Array layer count of the texture.
    */
    abstract @property uint layers();

    /**
        Mip level count of the texture.
    */
    abstract @property uint levels();

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
    abstract NioTexture upload(NioRegion3D region, uint level, uint slice, void[] data, uint rowStride);
}



/**
    Bit flags describing how a texture may be used.
*/
enum NioTextureUsage : uint {

    /**
        No usage flags is set.
    */
    none                = 0x00000000U,

    /**
        Image may be transferred from and to.
    */
    transfer            = 0x00000001U,

    /**
        Texture may be sampled in a shader.
    */
    sampled             = 0x00000002U,

    /**
        Texture may be attached to a pipeline for rendering.
    */
    attachment          = 0x00000004U,

    /**
        Texture may be used as a video encoding desination or
        source.
    */
    videoEncode         = 0x00000010U,

    /**
        Texture may be used as a video decoding desination or
        source.
    */
    videoDecode         = 0x00000020U,
}

/**
    Different kinds of types a texture can be.
*/
enum NioTextureType : uint {
    
    /**
        1-dimensional texture.
    */
    type1D                  = 0x00000010,

    /**
        1-dimensional array texture.
    */
    type1DArray             = 0x00000011,
    
    /**
        2-dimensional texture.
    */
    type2D                  = 0x00000020,
    
    /**
        2-dimensional array texture.
    */
    type2DArray             = 0x00000021,
    
    /**
        2-dimensional multisampled texture.
    */
    type2DMultisample       = 0x00000022,
    
    /**
        2-dimensional multisampled array texture.
    */
    type2DMultisampleArray  = 0x00000023,
    
    /**
        3-dimensional texture.
    */
    type3D                  = 0x00000030,
    
    /**
        Cubemap texture.
    */
    typeCube                = 0x00000040,
    
    /**
        Cubemap array texture.
    */
    typeCubeArray           = 0x00000041,
}