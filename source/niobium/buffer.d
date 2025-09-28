/**
    Niobium Buffers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.buffer;
import niobium.resource;
import niobium.device;
import numem;

/**
    Usage flags of a buffer.
*/
enum NioBufferUsage : uint {

    /**
        Buffer may be used as the source for transfer operations.
    */
    transferSource          = 0x00000001,
    
    /**
        Buffer may be used as the destination for transfer operations.
    */
    transferDestination     = 0x00000002,
    
    /**
        Buffer may be used as a uniform block.
    */
    uniformBuffer           = 0x00000004,
    
    /**
        Buffer may be used as a storage buffer.
    */
    storageBuffer           = 0x00000008,
    
    /**
        Buffer may be used as a index buffer.
    */
    indexBuffer             = 0x00000010,
    
    /**
        Buffer may be used as a vertex buffer.
    */
    vertexBuffer            = 0x00000020,
    
    /**
        Buffer may be used as a source for video decoding.
    */
    videoDecodeSource       = 0x01000000,
    
    /**
        Buffer may be used as a destination for video decoding.
    */
    videoDecodeDestination  = 0x02000000,
    
    /**
        Buffer may be used as a source for video encoding.
    */
    videoEncodeSource       = 0x04000000,
    
    /**
        Buffer may be used as a destination for video encoding.
    */
    videoEncodeDestination  = 0x08000000,
}

/**
    A buffer of data.
*/
abstract
class NioBuffer : NioResource {
protected:
@nogc:

    /**
        Constructs a new buffer.

        Params:
            device = The device that "owns" this buffer.
    */
    this(NioDevice device) {
        super(device);
    }

public:
@nogc:

    /**
        The usage flags of the buffer.
    */
    abstract @property NioBufferUsage usage();
    
    /**
        Maps the buffer, increasing the internal mapping
        reference count.

        Returns:
            The mapped buffer.
    */
    abstract void[] map();

    
    /**
        Unmaps the buffer, decreasing the internal mapping
        reference count.
    */
    abstract void unmap();

    /**
        Uploads data to the buffer.
        
        Note:
            Depending on the implementation this may be done during 
            the next frame in an internal staging buffer.

        Params:
            data =      The data to upload.
            offset =    Offset into the buffer to upload the data.
    */
    abstract void upload(void[] data, size_t offset);
}