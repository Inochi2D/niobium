/**
    Niobium Shader Libraries

    A collection of shaders in a single file.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.library;
import nulib.io.stream;
import nulib.io.stream.rw;
import numem;

/**
    The type of shader stored in the NIR Library
*/
enum NirShaderType : uint {
    
    /**
        NIR Bytecode
    */
    nir =           0x00000001U,
    
    /**
        SPIR-V Bytecode
    */
    spirv =         0x00000002U,
    
    /**
        Metal Shading Language
    */
    msl =           0x00000003U,
}

/**
    The different kinds of shader stages that a shader
    can apply to.
*/
enum NirShaderStage : uint {
    
    /**
        Vertex shader stage
    */
    vertex =            0x00000000U,
    
    /**
        Fragment shader stage
    */
    fragment =          0x00000001U,

    /**
        Mesh task shader stage
    */
    task =              0x00000002U,

    /**
        Mesh shader stage
    */
    mesh =              0x00000004U,
    
    /**
        Compute kernel shader stage
    */
    kernel =            0x00000008U,
}

/**
    A collection of shaders.
*/
class NirLibrary : NuRefCounted {
private:
@nogc:
    NirShader[] shaders_;

public:

    /**
        The shaders stored in the library.
    */
    final @property NirShader[] shaders() => shaders_;

    /**
        Adds a shader to the library.
    */
    void addShader(NirShader shader) {
        this.shaders_ = shaders_.nu_resize(shaders_.length+1);
        this.shaders_[$-1] = shader;
    }

    /**
        Reads a library from a byte stream.

        Params:
            stream = The stream to read from.

        Returns:
            The shader library or $(D null) on failure.
    */
    static NirLibrary fromStream(Stream stream) {
        auto reader = nogc_new!StreamReader(stream);
        
        // Wrong magic bytes.
        if (reader.readU32LE() != 0x78737900)
            return null;

        auto result = nogc_new!NirLibrary();
        uint shaderCount = reader.readU32LE();
        foreach(i; 0..shaderCount) {
            result.addShader(reader.readShader());
        }
        return result;
    }

    /**
        Writes the shader library to a stream.

        Params:
            stream = The stream to write to.
    */
    void write(Stream stream) {

        auto writer = nogc_new!StreamWriter(stream);
        writer.writeLE!uint(0x78737900);        // "NIO\0"
        writer.writeLE!uint(cast(uint)shaders_.length);   // Shader count

        foreach(ref shader; shaders_) {
            writer.writeShader(shader);
        }
        nogc_delete(writer);
    }
}

/**
    A shader
*/
struct NirShader {
    string name;
    string entrypoint;
    NirShaderType type;
    NirShaderStage stages;
    ubyte[] code;
}

/**
    Writes a single shader to a stream.

    Params:
        writer = The stream writer to use to write to the stream
        shader = The shader to write to the stream.
*/
void writeShader(ref StreamWriter writer, ref NirShader shader) @nogc {
    uint totalSectionLength = 
        cast(uint)(shader.name.length + 4 +
        shader.entrypoint.length + 4 +
        NirShaderType.sizeof +
        NirShaderStage.sizeof +
        shader.code.length + 4);
    
    writer.writeLE!uint(0x78737901);        // "NIO\1"
    writer.writeLE!uint(totalSectionLength);
    writer.writeLE!uint(shader.type);
    writer.writeLE!uint(shader.stages);
    writer.writeLE!uint(cast(uint)shader.name.length);
    writer.stream.write(cast(ubyte[])shader.name);
    writer.writeLE!uint(cast(uint)shader.entrypoint.length);
    writer.stream.write(cast(ubyte[])shader.entrypoint);
    writer.writeLE!uint(cast(uint)shader.code.length);
    writer.stream.write(shader.code);
}

/**
    Reads a single shader from a stream.

    Params:
        reader = The stream reader to use to read from the stream
    
    Returns:
        The read shader
*/
NirShader readShader(ref StreamReader reader) @nogc {
    uint magic = reader.readU32LE();
    if (magic != 0x78737901)        // "NIO\1"
        return NirShader.init;
    
    // Skip length, since we're not doing section
    // skipping.
    reader.stream.seek(4, SeekOrigin.relative);

    NirShader result;
    result.type = cast(NirShaderType)reader.readU32LE();
    result.stages = cast(NirShaderStage)reader.readU32LE();

    result.name = nu_malloca!(immutable(char))(reader.readU32LE());
    reader.stream.read(cast(ubyte[])result.name);
    
    result.entrypoint = nu_malloca!(immutable(char))(reader.readU32LE());
    reader.stream.read(cast(ubyte[])result.entrypoint);
    
    result.code = nu_malloca!(ubyte)(reader.readU32LE());
    reader.stream.read(result.code);
    return result;
}