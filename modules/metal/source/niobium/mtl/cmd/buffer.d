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
import niobium.mtl.memory;
import niobium.mtl.device;
import niobium.mtl.surface;
import niobium.mtl.sync;
import niobium.mtl.cmd;
import niobium.queue;
import niobium.cmd;
import metal.commandbuffer;
import metal.commandencoder;
import foundation;
import numem;
import nulib;
import nulib.threading.mutex;
import objc.autorelease;

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
        Whether the command buffer is still recording.
    */
    override @property bool isRecording() => handle_.status < MTLCommandBufferStatus.Committed;

    /**
        The underlying metal handle.
    */
    final @property MTLCommandBuffer handle() => handle_;

    /// Destructor
    ~this() {
        nogc_delete(encoderMutex_);
        handle_.release();
    }

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
    */
    this(NioMTLCommandQueue queue, MTLCommandBuffer handle) {
        super(queue);
        this.handle_ = handle;
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
        if (this.activeEncoder) {
            encoderMutex_.unlock();
            return null;
        }

        // TODO: Create NioRenderCommandEncoder here.
        this.activeEncoder = nogc_new!NioMTLRenderCommandEncoder(this, desc);
        encoderMutex_.unlock();
        return cast(NioMTLRenderCommandEncoder)activeEncoder;
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
        if (this.activeEncoder) {
            encoderMutex_.unlock();
            return null;
        }
        
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
        if (drawable.queue)
            return;

        .autorelease(() {
            handle_.present((cast(NioMTLDrawable)drawable).handle);
            drawable.release();
        });
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
    import foundation : NSString, NSError;

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
        .autorelease(() {
            mtlcmdbuffer.pushDebugGroup(NSString.create(name));
        });
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


    /**
        Inserts a barrier that ensures that subsequent commands 
        of type $(D afterStages) submitted to the command queue does 
        not proceed until the work in $(D beforeStages) completes.

        Params:
            afterStages =   A mask that defines the stages of work to wait for.
            beforeStages =  A mask that defines the work that must wait.
    */
    override void insertBarrier(NioPipelineStage afterStages, NioPipelineStage beforeStages) {
        handle.barrier(afterStages.toMTLStages(), beforeStages.toMTLStages());
    }
}