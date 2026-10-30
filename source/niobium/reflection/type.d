/**
    Niobium Shader Type Reflection
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.reflection.type;
import niobium.texture;
import numem;

public import niobium.types;

/**
    A type within a shader.
*/
abstract
class NioType : NuRefCounted {

    /**
        The underlying type.
    */
    abstract @property NioDataType dataType();
}

/**
    Array type.
*/
abstract
class NioArrayType : NioType {

    /**
        Type of an element
    */
    abstract @property NioType elementType();

    /**
        Length of the array
    */
    abstract @property uint length();

    /**
        Stride of the array
    */
    abstract @property uint stride();
}

/**
    Struct type.
*/
abstract
class NioStructType : NioType {

    /**
        The members of the struct
    */
    abstract @property NioStructMember[] members();
}

/**
    A member in a struct type.
*/
abstract
class NioStructMember : NuRefCounted {

    /**
        Name of the member, may be $(D null)
    */
    abstract @property string name();

    /**
        Type of the member
    */
    abstract @property NioType type();

    /**
        Offset of the member, in bytes.
    */
    abstract @property uint offset();

    /**
        Index of the member in the struct.
    */
    abstract @property uint index();
}

/**
    Pointer type.
*/
abstract
class NioPointerType : NioType {

    /**
        Type of the element being pointed to.
    */
    abstract @property NioType elementType();

    /**
        Alignment of the pointer.
    */
    abstract @property uint alignment();

    /**
        Size of the data being pointed to.
    */
    abstract @property uint size();
}

/**
    Texture reference type.
*/
abstract
class NioTextureRefType : NioType {

    /**
        The type of the texture being referenced.
    */
    abstract @property NioTextureType textureType();

    /**
        The data type of the texture.
    */
    abstract @property NioDataType textureDataType();

    /**
        Whether the texture reference is a depth texture,
        or a combined depth-stencil texture.
    */
    abstract @property bool isDepthStencilTexture();
}