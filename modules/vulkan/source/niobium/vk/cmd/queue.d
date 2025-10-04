/**
    Niobium Vulkan Command Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.cmd.queue;
import niobium.vk.surface;
import niobium.vk.device;
import niobium.vk.cmd;
import niobium.cmd;
import vulkan.khr.swapchain;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import nulib.threading.mutex;
import nulib.threading.atomic;

public import niobium.queue;

/**
    Represents an individual queue for command submission on the device.
*/
class NioVkCommandQueue : NioCommandQueue {
private:
@nogc:
    // State
    uint                        queueFamily_;
    NioCommandQueueDescriptor   desc_;
    VK_KHR_swapchain            swapFuncs;
    Mutex                       submitMutex;

    // Pool
    NioCommandPool              pool_;
    uint                        enqueuedCount_;
    NioVkCommandBuffer[]        enqueued_;

    // Handles
    VkQueue                     handle_;

    void setup(NioCommandQueueDescriptor desc, VkQueue handle, uint queueFamily) {
        auto nvkDevice = (cast(NioVkDevice)device);
        nvkDevice.handle.loadProcs(swapFuncs);

        this.desc_ = desc;
        this.handle_ = handle;
        this.queueFamily_ = queueFamily;
        
        this.submitMutex = nogc_new!Mutex();
        this.pool_ = nogc_new!NioCommandPool(this, desc_.maxCommandBuffers);
        this.enqueued_ = nu_malloca!NioVkCommandBuffer(desc_.maxCommandBuffers);
    }

    void commitImpl(NioVkCommandBuffer buffer) {

        // Don't allow null buffers or other-queue submission.
        if (!buffer || buffer.queue !is this)
            return;
        
        if (buffer.isRecording)
            buffer.end();
        
        auto cmdBufferInfo = VkCommandBufferSubmitInfo(
            commandBuffer: buffer.handle,
            deviceMask: 0
        );

        // Present-submit.
        if (buffer.drawable) {
            auto swapchain = buffer.drawable.swapchain;
            auto index =     buffer.drawable.index;

            auto cmdWaitInfo = VkSemaphoreSubmitInfo(
                semaphore: buffer.drawable.semaphore,
                value: 1,
                stageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
                deviceIndex: 0
            );
            
            auto cmdSigInfo = VkSemaphoreSubmitInfo(
                semaphore: buffer.semaphore,
                value: 1,
                stageMask: VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT,
                deviceIndex: 0
            );

            auto submitInfo = VkSubmitInfo2(
                signalSemaphoreInfoCount: 1,
                waitSemaphoreInfoCount: 1,
                commandBufferInfoCount: 1,
                pSignalSemaphoreInfos: &cmdSigInfo,
                pWaitSemaphoreInfos: &cmdWaitInfo,
                pCommandBufferInfos: &cmdBufferInfo,
            );
            vkQueueSubmit2(handle_, 1, &submitInfo, buffer.fence);

            auto presentInfo = VkPresentInfoKHR(
                waitSemaphoreCount: 1,
                pWaitSemaphores: &buffer.semaphore,
                swapchainCount: 1,
                pSwapchains: &swapchain,
                pImageIndices: &index,
                pResults: null
            );
            swapFuncs.vkQueuePresentKHR(handle_, &presentInfo);
            return;
        }

        // Only-submit.
        auto cmdSigInfo = VkSemaphoreSubmitInfo(
            semaphore: buffer.semaphore,
            value: 1,
            stageMask: VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT,
            deviceIndex: 0
        );
        auto submitInfo = VkSubmitInfo2(
            signalSemaphoreInfoCount: 1,
            pSignalSemaphoreInfos: &cmdSigInfo,
            commandBufferInfoCount: 1,
            pCommandBufferInfos: &cmdBufferInfo,
        );
        vkQueueSubmit2(handle_, 1, &submitInfo, buffer.fence);
    }

    void commitImpl() {
        foreach(i; 0..enqueuedCount_) {
            this.commitImpl(enqueued_[i]);
        }
        this.enqueuedCount_ = 0;
    }

    void enqueueImpl(NioVkCommandBuffer buffer) {
        if (buffer.queue !is this)
            return;

        if (this.findEnqueueIndex(buffer) == -1) {
            enqueued_[enqueuedCount_++] = buffer;
        }
    }

    ptrdiff_t findEnqueueIndex(NioVkCommandBuffer buffer) {
        foreach(i; 0..enqueuedCount_) {
            if (enqueued_[i] is buffer)
                return i;
        }
        return -1;
    }

protected:
    

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override void onLabelChanged(string label) {
        auto vkDevice = (cast(NioVkDevice)device).handle;

        import niobium.vk.device : setDebugName;
        vkDevice.setDebugName(VK_OBJECT_TYPE_QUEUE, handle_, label);
        vkDevice.setDebugName(VK_OBJECT_TYPE_COMMAND_POOL, pool_.handle, label);
    }

public:

    /**
        Underlying vulkan handle
    */
    final @property VkQueue handle() => handle_;

    /**
        The maximum amount of active command buffers you can
        have.
    */
    final @property uint queueFamily() => queueFamily_;

    /**
        The maximum amount of active command buffers you can
        have.
    */
    override @property uint maxCommandBuffers() => desc_.maxCommandBuffers;

    /// Destructor
    ~this() {
        nogc_delete(pool_);

        vkQueueWaitIdle(handle_);
        nogc_delete(submitMutex);
    }

    /**
        Constructs a new queue.

        Params:
            device =        The device that "owns" this queue.
            desc =          Descriptor
            handle =        Vulkan handle 
            familyIndex =   The queue family index.
    */
    this(NioDevice device, NioCommandQueueDescriptor desc, VkQueue handle, uint familyIndex) {
        super(device);
        this.setup(desc, handle, familyIndex);
    }

    /**
        Fetches a command buffer from the queue, the amount of
        command buffers is limited by the command buffer count
        provided during queue initialization.

        If there's no available command buffers in the queue this
        function will block until a command buffer becomes available.

        See_Also:
            $(D maxCommandBuffers)
    */
    override NioCommandBuffer fetch() {
        return this.pool_.fetch();
    }

    /**
        Reserves space in the command queue for the given
        buffer.
        
        Params:
            buffer = The buffer to enqueue.
    */
    override void enqueue(NioCommandBuffer buffer) {
        submitMutex.lock();
        this.enqueueImpl(cast(NioVkCommandBuffer)buffer);
        submitMutex.unlock();
    }

    /**
        Reserves space in the command queue for the given
        buffer.

        Params:
            buffers = The buffers to enqueue.
    */
    override void enqueue(NioCommandBuffer[] buffers) {
        submitMutex.lock();
        foreach(buffer; buffers)
            this.enqueueImpl(cast(NioVkCommandBuffer)buffer);
        submitMutex.unlock();
    }

    /**
        Submits a single command buffer onto the queue.
        
        Params:
            buffer = The buffer to enqueue.
    */
    override void commit(NioCommandBuffer buffer) {
        submitMutex.lock();
            this.enqueueImpl(cast(NioVkCommandBuffer)buffer);
            this.commitImpl();
        submitMutex.unlock();
    }

    /**
        Submits a slice of command buffers into the queue.

        Params:
            buffers = The buffers to enqueue.
    */
    override void commit(NioCommandBuffer[] buffers) {
        submitMutex.lock();
            foreach(buffer; buffers)
                this.enqueueImpl(cast(NioVkCommandBuffer)buffer);
            this.commitImpl();
        submitMutex.unlock();
    }
}

/**
    Wraps a pool of command buffers and their state.
*/
class NioCommandPool {
private:
@nogc:
    // Refs
    NioVkDevice             device_;
    NioVkCommandQueue       queue_;

    // State
    Mutex                   mutex_;
    NioVkCommandBuffer[]    instances_;
    VkCommandBuffer[]       buffers_;
    VkSemaphore[]           semaphores_;
    VkFence[]               fences_;
    size_t                  idx_ = 0;

    // Handles
    VkCommandPool           handle_;

    void setup(uint poolSize) {

        // Create pool
        auto createInfo = VkCommandPoolCreateInfo(
            flags: VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            queueFamilyIndex: queue_.queueFamily
        );
        vkEnforce(vkCreateCommandPool(device_.handle, &createInfo, null, &handle_));

        // Allocate
        this.buffers_ =     nu_malloca!VkCommandBuffer(poolSize);
        this.instances_ =   nu_malloca!NioVkCommandBuffer(poolSize);
        this.semaphores_ =  nu_malloca!VkSemaphore(poolSize);
        this.fences_ =      nu_malloca!VkFence(poolSize);

        // Fill buffers
        auto allocInfo = VkCommandBufferAllocateInfo(
            commandPool: handle_,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: poolSize,
        );
        vkEnforce(vkAllocateCommandBuffers(device_.handle, &allocInfo, buffers_.ptr));

        // Fill sync primitives and instances
        foreach(i; 0..poolSize) {
            auto fenceCreateInfo = VkFenceCreateInfo(flags: VK_FENCE_CREATE_SIGNALED_BIT);
            vkCreateFence(device_.handle, &fenceCreateInfo, null, &fences_[i]);

            auto semapCreateInfo = VkSemaphoreCreateInfo();
            vkCreateSemaphore(device_.handle, &semapCreateInfo, null, &semaphores_[i]);

            // Fill out instances.
            this.instances_[i] =            nogc_new!NioVkCommandBuffer(queue_, buffers_[i]);
            this.instances_[i].fence =      fences_[i];
            this.instances_[i].semaphore =  semaphores_[i];
        }
    }

    /// Awaits all completion fences.
    bool awaitAllFences(ulong timeout) {
        return vkWaitForFences(device_.handle, cast(uint)fences_.length, fences_.ptr, VK_TRUE, timeout) == VK_SUCCESS;
    }

    /// Awaits a command buffer being free for use.
    ptrdiff_t awaitFreeBuffer() {
        import nulib.math : min;

        // Special case; only 1 buffer.
        if (instances_.length == 1) {
            if (vkWaitForFences(device_.handle, cast(uint)fences_.length, fences_.ptr, VK_FALSE, ulong.max) == VK_SUCCESS) {
                vkResetFences(device_.handle, 1, &fences_[0]);
                return 0;
            }
            return -1;
        }

        if (vkWaitForFences(device_.handle, cast(uint)fences_.length, fences_.ptr, VK_FALSE, ulong.max) == VK_SUCCESS) {
            foreach(offset; 0..instances_.length) {
                size_t i = idx_ % instances_.length;
                if (vkGetFenceStatus(device_.handle, fences_[i]) == VK_SUCCESS) {
                    vkResetFences(device_.handle, 1, &fences_[i]);
                    idx_++;
                    return i;
                }
            }
        }
        return -1;
    }

public:

    /**
        Underlying Vulkan handle.
    */
    final @property VkCommandPool handle() => handle_;

    /// Destructor
    ~this() {
        this.awaitAllFences(ulong.max);
        vkQueueWaitIdle(queue_.handle);
        foreach(i; 0..buffers_.length) {
            vkDestroyFence(device_.handle, fences_[i], null);
            vkDestroySemaphore(device_.handle, semaphores_[i], null);
        }

        nu_freea(instances_);
        nu_freea(fences_);
        nu_freea(semaphores_);
        vkDestroyCommandPool(device_.handle, handle_, null);
    }

    /**
        Constructs a new command pool.

        Params:
            queue =     Parent queue
            poolSize =  Maximum number of buffers that can be active at once.
    */
    this(NioVkCommandQueue queue, uint poolSize) {
        this.queue_ = queue;
        this.device_ = cast(NioVkDevice)queue.device;
        this.mutex_ = nogc_new!Mutex();
        this.setup(poolSize);
    }

    /**
        Fetches the next available buffer from the pool.
    */
    NioVkCommandBuffer fetch() {
        this.mutex_.lock();
        ptrdiff_t freeBuffer = this.awaitFreeBuffer();
        if (freeBuffer == -1)
            return null;
        this.mutex_.unlock();
        
        return instances_[freeBuffer].retained().begin();
    }
}

