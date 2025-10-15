/**
    Niobium Samplers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.sampler;
import niobium.device;

/**
    Addressing modes for a sampler.
*/
enum NioSamplerWrap : uint {

    /**
        Clamps the coordinates to the edges of the texture.
    */
    clampToEdge             = 0x00000000U,
    
    /**
        Infinitely repeats the texture in all directions.
    */
    repeat                  = 0x00000001U,
    
    /**
        Clamps the coordinates to the edges of the texture,
        the texture is addtionally mirrored in every negative
        axis.
    */
    mirroredClampToEdge     = 0x00000002U,
    
    /**
        Infinitely repeats the texture in all directions,
        but mirrored at every wraparound.
    */
    mirroredRepeat          = 0x00000003U,
    
    /**
        Any coordinates that fall outside of the texture's bounds
        will be set to the given border color.
    */
    clampToBorderColor      = 0x00000004U,
}

/**
    Minification+Magnification filter.
*/
enum NioMinMagFilter : uint {
    
    /**
        Texture coordinates will snap to the nearest pixel.
    */
    nearest     = 0x00000000U,
    
    /**
        Texture cordinates will linearly sample at fractional
        pixel indices.
    */
    linear      = 0x00000001U,
}

/**
    Mipmap filter.
*/
enum NioMipFilter : uint {
    
    /**
        No mipmapping is enabled.
    */
    none        = 0x00000000U,
    
    /**
        The "nearest" mip level is snapped to.
    */
    nearest     = 0x00000001U,
    
    /**
        Linearly interpolates between multiple mip
        levels when at fractional mip level.
    */
    linear      = 0x00000002U,
}

/**
    Descriptor used to create a $(D NioSampler).
*/
struct NioSamplerDescriptor {

    /**
        Wrapping mode for U (horizontal) axis.
    */
    NioSamplerWrap wrapU;

    /**
        Wrapping mode for V (vertical) axis.
    */
    NioSamplerWrap wrapV;

    /**
        Wrapping mode for W (forward) axis.
    */
    NioSamplerWrap wrapW;

    /**
        Minification filter.
    */
    NioMinMagFilter minFilter;

    /**
        Magnification filter.
    */
    NioMinMagFilter magFilter;

    /**
        Mipmap filter.
    */
    NioMipFilter mipFilter;

    /**
        Minimum level-of-detal
    */
    float minLod;

    /**
        Maximum level-of-detal
    */
    float maxLod;

    /**
        Bias to apply to level-of-detal calculations.
    */
    float mipLodBias;

    /**
        Max anisotropy to apply.
    */
    float maxAnisotropy;

    /**
        Whether the sampler uses normalized coordinates.

        When enabled, the texture **must**:
            * Be either 1D or 2D.
            * Have only a single layer and mip level.
    */
    bool normalizedCoordinates = true;
}

/**
    A sampler state object.

    Once a sampler is created its state is immutable.
*/
abstract
class NioSampler : NioDeviceObject {
private:
@nogc:
    NioSamplerDescriptor desc_;

protected:

    /**
        Constructs a new sampler.

        Params:
            device =    The device that "owns" this sampler.
            desc =      The descriptor for this sampler.
    */
    this(NioDevice device, NioSamplerDescriptor desc) {
        super(device);
        this.desc_ = desc;
    }
public:

    /**
        Wrapping mode for U (horizontal) axis.
    */
    final @property NioSamplerWrap wrapU() => desc_.wrapU;

    /**
        Wrapping mode for V (vertical) axis.
    */
    final @property NioSamplerWrap wrapV() => desc_.wrapV;

    /**
        Wrapping mode for W (forward) axis.
    */
    final @property NioSamplerWrap wrapW() => desc_.wrapW;

    /**
        Minification filter.
    */
    final @property NioMinMagFilter minFilter() => desc_.minFilter;

    /**
        Magnification filter.
    */
    final @property NioMinMagFilter magFilter() => desc_.magFilter;

    /**
        Mipmap filter.
    */
    final @property NioMipFilter mipFilter() => desc_.mipFilter;
}