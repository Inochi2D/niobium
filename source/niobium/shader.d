/**
    Niobium Shaders
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.shader;
import niobium.device;
import niobium.types;
import niobium.meta;
import nir.library;
import nir.types;
import numem;


/**
    A shader
*/
abstract
class NioShader : NioDeviceObject {
private:
@nogc:
    NirLibrary library_;

protected:

    /**
        The NIR Library attached to this shader.
    */
    final @property NirLibrary library() => library_;

    /**
        Constructs a new shader.

        Params:
            device =    The device that "owns" this shader.
            library =   The library used to create the shader.
    */
    this(NioDevice device, NirLibrary library) {
        super(device);
        if (library)
            this.library_ = library.retained();
    }

public:

    /// Destructor
    ~this() {
        if (library_)
            library_.release();
    }

    /**
        Gets a named non-specialized function from the shader.

        Params:
            name = The name of the function.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    abstract NioShaderFunction getFunction(string name);

    /**
        Creates a new specialized function instance from the given descriptor.

        Params:
            desc = The descriptor.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    abstract NioShaderFunction makeFunction(NioShaderFunctionDescriptor desc);
}

/**
    A single shader constant.
*/
struct NioShaderConstant {
    
    /**
        ID of the constant
    */
    uint id;

    /**
        Type of the constant value.
    */
    NioDataType type;

    /**
        Untyped constant value.
    */
    void[64] data;
}

/**
    A descriptor used to create specialized shader functions.
*/
struct NioShaderFunctionDescriptor {
public:
@nogc:

    /**
        Name of the function.
    */
    string name;

    /**
        Shader constants.
    */
    NioShaderConstant[] constants;

    /**
        Sets constant with the given ID.

        Params:
            id =    The ID of constant to set.
            value = The value to set the constant to.
    */
    void setConstant(T)(uint id, T value) nothrow {
        foreach(ref c; constants) {
            if (c.id == id) {
                c.type = toNioDataType!T();
                c.data[0..T.sizeof] = (cast(void*)&value)[0..T.sizeof];
                return;
            }
        }

        // Add new constant.
        constants = constants.nu_resize(constants.length+1);
        constants[$-1] = NioShaderConstant(id, toNioDataType!T(), (cast(void*)&value)[0..T.sizeof]);
    }
}

/**
    A shader function.
*/
abstract
class NioShaderFunction : NioDeviceObject {
protected:
@nogc:
    
    /**
        The function's specialization constants, if any.
    */
    NioShaderConstant[] constants;

    /**
        Constructs a new shader.

        Params:
            device = The device that "owns" this shader.
    */
    this(NioDevice device, NioShaderConstant[] constants = null) {
        super(device);
    }

public:

    /**
        Name of the function
    */
    abstract @property string name();

    /**
        The shader stage this shader conforms to.
    */
    abstract @property NirShaderStage stage();

    // Destructor
    ~this() {
        nu_cleara(constants);
    }
}