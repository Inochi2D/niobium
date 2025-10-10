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
import nulib.memory.endian;
import numem;

public import nir.types;

/**
    The type of shader stored in the NIR Library
*/
enum NirShaderType : uint {
    
    /**
        NIR Bytecode
    */
    nir =           0x00000001U,
    
    /**
        Metal Shading Language
    */
    msl =           0x00000002U,
}

/**
    The amount of shader stages that are supported.
*/
enum NirShaderStageCount = __traits(allMembers, NirShaderStage).length;

/**
    Magic bytes for a Nir Library.
*/
enum ubyte[4] NirLibraryMagic = cast(ubyte[4])"NIO\0";

/**
    Magic bytes for a Nir Library section.
*/
enum ubyte[4] NirLibrarySectionMagic = cast(ubyte[4])"NIO\1";

/**
    Gets whether a stage flag specifies multiple stages.
*/
bool isMultistage(NirShaderStage stages) @nogc {
    uint count = 0;
    foreach(i; 0..NirShaderStageCount)
        count += (stages >> i) & 0x01;
    
    return count > 1;
}

/**
    A collection of shaders.
*/
class NirLibrary : NuRefCounted {
private:
@nogc:
    NirShader[] shaders_;

    /// Adds a shader to the library.
    void addShaderImpl(ref NirShader shader) {
        
        // We already have a shader like this...
        if (this.findShader(shader.type) != -1) 
            return;

        shaders_ = shaders_.nu_resize(shaders_.length+1);
        shaders_[$-1] = NirShader(
            name: shader.name.nu_dup(),
            type: shader.type,
            code: shader.code.nu_dup()
        );
    }

    /// Finds a shader within the list.
    ptrdiff_t findShader(NirShaderType type) {
        foreach(i, ref installed; shaders_) {
            if (installed.type == type)
                return i;
        }
        return -1;
    }

public:

    ~this() {
        foreach(ref shader; shaders_) {
            nu_freea(shader.name);
            nu_freea(shader.code);
        }
        nu_freea(shaders_);
    }

    this() { }

    /**
        The shaders stored in the library.
    */
    final @property NirShader[] shaders() => shaders_;

    /**
        Adds a shader to the library.

        Note:
            The library keeps an internal

        Params:
            shader = The shader to add.
    */
    void addShader(NirShader shader) {
        this.addShaderImpl(shader);
    }

    /**
        Finds a shader within the library that is of the given
        type and which supports the given shader stage.

        Params:
            type =  The type of shader to find
        
        Returns:
            A $(D NirShader*) if a shader with the given stage(s) if found,
            $(D null) otherwise.
    */
    NirShader* find(NirShaderType type) {
        ptrdiff_t idx = this.findShader(type);
        return idx != -1 ? &shaders_[idx] : null;
    }

    /**
        Reads a library from memory.

        Params:
            memory = The memory to read from.

        Returns:
            The shader library or $(D null) on failure.
    */
    static NirLibrary fromMemory(ubyte[] memory) {
        auto memstream = nogc_new!MemoryStream(memory.nu_dup());
        auto library = NirLibrary.fromStream(memstream);
        
        nogc_delete(memstream);
        return library;
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
        if (reader.readU32LE() != *cast(int*)&NirLibraryMagic)
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
        writer.stream.write(NirLibraryMagic);
        writer.writeLE!uint(cast(uint)shaders_.length);  // Shader count

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
    NirShaderType type;
    ubyte[] code;
}

/**
    Writes a single shader to a stream.

    Params:
        writer = The stream writer to use to write to the stream
        shader = The shader to write to the stream.
*/
void writeShader(ref StreamWriter writer, ref NirShader shader) @nogc {
    writer.stream.write(NirLibrarySectionMagic);
    writer.writeLE!uint(shader.type);
    writer.writeLE!uint(cast(uint)shader.name.length);
    writer.stream.write(cast(ubyte[])shader.name);
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
    if (magic != *cast(int*)&NirLibrarySectionMagic)        // "NIO\1"
        return NirShader.init;

    NirShader result;
    result.type = cast(NirShaderType)reader.readU32LE();

    result.name = nu_malloca!(immutable(char))(reader.readU32LE());
    reader.stream.read(cast(ubyte[])result.name);

    result.code = nu_malloca!(ubyte)(reader.readU32LE());
    reader.stream.read(result.code);
    return result;
}