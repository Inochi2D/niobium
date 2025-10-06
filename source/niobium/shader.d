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
import nir.library;

/**
    Descriptor used to create a shader.
*/
struct NioShaderDescriptor {

    /**
        The NIR Library to create the shader object from.
    */
    NirLibrary library;
}

/**
    A shader
*/
abstract
class NioShader : NioDeviceObject {
private:
@nogc:
    NioShaderDescriptor desc_;

protected:

    /**
        The shader descriptor used to create the shader.
    */
    final @property NioShaderDescriptor desc() => desc_;

    /**
        Constructs a new shader.

        Params:
            device =    The device that "owns" this shader.
            desc =      The descriptor usde to create the shader.
    */
    this(NioDevice device, NioShaderDescriptor desc) {
        super(device);
        this.desc_ = desc;
    }

public:

    /**
        Gets a named function from the shader.

        Params:
            name = The name of the function.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    abstract NioShaderFunction getFunction(string name);
}

/**
    A shader function.
*/
abstract
class NioShaderFunction : NioDeviceObject {
protected:
@nogc:

    /**
        Constructs a new shader.

        Params:
            device = The device that "owns" this shader.
    */
    this(NioDevice device) {
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
}