/**
    Niobium Metal Buffers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.resource.buffer;
import niobium.mtl.resource;
import niobium.mtl.device;
import niobium.mtl.heap;
import foundation;
import metal.resource;
import metal.buffer;
import numem;

public import niobium.buffer;
public import niobium.vertexformat;

/**
    Metal Buffer
*/
class NioMTLBuffer : NioBuffer {
private:
@nogc:
    MTLBuffer               handle_;
    NioBufferDescriptor     desc_;

    void createBuffer(NioBufferDescriptor desc) {
        auto nmtlDevice = cast(NioMTLDevice)device;

        this.desc_ = desc;
        this.handle_ = nmtlDevice.handle.newBuffer(
            desc.size,
            cast(MTLResourceOptions)(
                MTLResourceOptions.CacheModeDefaultCache |
                desc.storage.toMTLStorageMode() << MTLResourceStorageModeShift |
                MTLResourceOptions.HazardTrackingModeDefault
            )
        );
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
    final @property MTLBuffer handle() => handle_;

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => cast(uint)handle_.allocatedSize;

    /**
        The usage flags of the buffer.
    */
    override @property NioBufferUsage usage() => desc_.usage;

    /**
        Storage mode of the resource.
    */
    override @property NioStorageMode storageMode() => desc_.storage;

    /// Destructor
    ~this() {
        handle_.release();
    }

    /**
        Constructs a new $(D NioMTLBuffer) from a descriptor.

        Params:
            device =    The device to create the texture on.
            desc =      Descriptor used to create the texture.
    */
    this(NioDevice device, NioBufferDescriptor desc) {
        super(device);
        this.createBuffer(desc);
    }
    
    /**
        Maps the buffer, increasing the internal mapping
        reference count.

        Returns:
            The mapped buffer.
    */
    override void[] map() {
        if (desc_.storage.privateStorage)
            return null;
        
        return handle_.contents[0..handle_.length];
    }

    
    /**
        Unmaps the buffer, decreasing the internal mapping
        reference count.
    */
    override void unmap() {
        if (desc_.storage.privateStorage)
            return;

        if (desc_.storage & NioStorageMode.managedStorage)
            handle_.didModifyRange(NSRange(0, handle_.length));
    }

    /**
        Uploads data to the buffer.
        
        Note:
            Depending on the implementation this may be done during 
            the next frame in an internal staging buffer.

        Params:
            data =      The data to upload.
            offset =    Offset into the buffer to upload the data.
    */
    override void upload(void[] data, size_t offset) {
        import nulib.math : min;

        if (desc_.storage.privateStorage)
            return;
        
        void[] mapped = this.map();
            size_t start = min(offset, mapped.length);
            size_t end = min(offset+data.length, mapped.length);
            size_t srcEnd = mapped.length-end;
            mapped[start..end] = data[0..srcEnd];
        this.unmap();
    }

    /**
        Downloads data from a buffer.
        
        Params:
            offset =    Offset into the buffer to download from.
            length =    Length of data to download, in bytes.
        
        Returns:
            A nogc slice of data on success,
            $(D null) otherwise.
    */
    override void[] download(size_t offset, size_t length) {
        // TODO: Implement a staging buffer just for private resources.
        return null; 
    }
}