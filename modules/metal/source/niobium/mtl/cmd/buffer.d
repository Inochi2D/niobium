/**
    Niobium Metal Command Buffers
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.cmd.buffer;
import niobium.mtl.surface;
import niobium.mtl.cmd;
import niobium.cmd;
import niobium.queue;
import niobium.device;
import niobium.surface;
import metal.commandbuffer;
import foundation;
import numem;
import nulib;
import nulib.threading.mutex;

public import niobium.cmd;
public import niobium.mtl.cmd.txrencoder;
public import niobium.mtl.cmd.renderencoder;

/**
    A buffer of commands which can be sent to the GPU
    for processing.

    Note:
        Submitting a command buffer will invalidate it,
        this means that you cannot modify its state any
        longer. Once submitted it's safe to $(D release)
        the command buffer.
*/
class NioMTLCommandBuffer : NioCommandBuffer {
private:
@nogc:
    // State
    bool isRecording_ = true;

    // Handles
    MTLCommandBuffer handle_;
    Mutex encoderMutex_;

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
    final @property MTLCommandBuffer handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
        nogc_delete(encoderMutex_);
    }

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
    */
    this(NioDevice device, NioMTLCommandQueue queue) {
        super(device, queue);
        this.handle_ = queue.handle.commandBuffer();
        this.encoderMutex_ = nogc_new!Mutex();
    }

    /**
        Begins a new render pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Params:
            desc = Descriptor used to start the render pass

        Returns:
            A short lived $(D NioRenderCommandEncoder) on success,
            $(D null) on failure.
    */
    override NioRenderCommandEncoder beginRenderPass(NioRenderPassDescriptor desc) {
        encoderMutex_.lock();
        if (this.activeEncoder)
            return null;

        // TODO: Create NioRenderCommandEncoder here.
        encoderMutex_.unlock();
        return null;
    }

    /**
        Begins a new transfer pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Returns:
            A short lived $(D NioTransferCommandEncoder) on success,
            $(D null) on failure.
    */
    override NioTransferCommandEncoder beginTransferPass() {
        encoderMutex_.lock();
        if (this.activeEncoder)
            return null;
        
        this.activeEncoder = nogc_new!NioMTLTransferCommandEncoder(this);
        encoderMutex_.unlock();
        return cast(NioMTLTransferCommandEncoder)activeEncoder;
    }

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        Params:
            drawable = The drawable to present.
    */
    override void present(NioDrawable drawable) {
        if (!isRecording_)
            return;
        
        if (auto mtldrawable = cast(NioMTLDrawable)drawable) {
            if (mtldrawable.queue)
                return;
            
            mtldrawable.queue = this.queue;
            handle_.present(mtldrawable.handle);
        }
    }

    /**
        Awaits the completion of the command buffer
        execution.
    */
    override void await() {
        handle_.waitUntilCompleted();
    }
}



/*
    Mixin template inserted into the different command encoders
    to make them conform to the NioCommandEncoder class interface.
*/
mixin template MTLCommandEncoderFunctions(EncoderT) {

    /**
        Command encoder handle
    */
    protected EncoderT handle;

    /**
        Metal command buffer.
    */
    protected @property MTLCommandBuffer mtlcmdbuffer() => (cast(NioMTLCommandBuffer)commandBuffer).handle;

    /**
        Pushes a debug group.

        Params:
            name = The name of the debug group
            color = The color of the debug group (optional)
    */
    override void pushDebugGroup(string name, float[4] color) {
        mtlcmdbuffer.pushDebugGroup(NSString.create(name));
    }

    /**
        Pops the top debug group from the debug
        group stack.
    */
    override void popDebugGroup() {
        mtlcmdbuffer.popDebugGroup();
    }

    /**
        Ends the encoding pass, allowing a new pass to be
        begun from the parent command buffer.
    */
    override void endEncoding() {
        handle.endEncoding();
        this.finishEncoding();
    }
}