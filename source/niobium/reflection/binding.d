/**
    Niobium Shader Binding Reflection
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.reflection.binding;
import niobium.reflection.type;
import niobium.texture;
import numem;

/**
    The types of binding
*/
enum NioBindingType : uint {

    /**
        Buffer binding
    */
    buffer      = 0x00000001U,
    
    /**
        Sampler binding
    */
    sampler     = 0x00000002U,
    
    /**
        Texture binding
    */
    texture     = 0x00000003U,
    
    /**
        Tensor binding
    */
    tensor      = 0x00000004U,
}

/**
    A binding in a shader.
*/
abstract
class NioBinding : NuRefCounted {
public:
@nogc:

    /**
        The type of the binding.
    */
    abstract @property NioBindingType type();

    /**
        Set of the binding.
    */
    abstract @property uint set();

    /**
        Index of the binding
    */
    abstract @property uint index();

    /**
        Whether the binding is an entrypoint argument.
    */
    abstract @property bool isArgument();

    /**
        Whether the binding is used.
    */
    abstract @property bool isUsed();

    /**
        Name of the binding, may be $(D null) if there's no
        debug info.
    */
    abstract @property string name();
}

/**
    A binding to a buffer.
*/
abstract
class NioBufferBinding : NioBinding {

    /**
        Required alignment of data in the buffer.
    */
    abstract @property uint alignment();

    /**
        Size of the buffer, in bytes.
    */
    abstract @property uint size();

    /**
        Type of the buffer.
    */
    abstract @property NioType bufferType();

    /**
        Type of the data stored in the buffer.

        Will either be $(D NioDataType.pointer) or $(D NioDataType.structure)
    */
    abstract @property NioDataType dataType();
}

/**
    A binding to a texture.
*/
abstract
class NioTextureBinding : NioBinding {

    /**
        Type of the buffer.
    */
    abstract @property NioTextureType type();

    /**
        Type of the data stored in the texture.
    */
    abstract @property NioDataType dataType();

    /**
        Length of the texture array.
    */
    abstract @property uint arrayLength();

    /**
        Whether the texture reference is a depth texture,
        or a combined depth-stencil texture.
    */
    abstract @property bool isDepthStencilTexture();
}