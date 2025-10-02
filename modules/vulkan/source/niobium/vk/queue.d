/**
    Niobium Vulkan Command Queues
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.queue;
import niobium.vk.surface;
import niobium.vk.device;
import niobium.vk.cmd;
import niobium.surface;
import niobium.device;
import niobium.queue;
import niobium.cmd;
import vulkan.khr.swapchain;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import nulib.threading.mutex;
import nulib.threading.atomic;

/**
    Represents an individual queue for command submission on the device.
*/
class NioVkCommandQueue : NioCommandQueue {
private:
@nogc:
    // State
    NioCommandQueueDescriptor   desc_;
    VK_KHR_swapchain            swapFuncs;
    
    // Submission
    VkSwapchainKHR[]            submitSwapchains;
    uint[]                      submitSwapchainImages;
    VkSemaphoreSubmitInfo[]     submitWaitSemaphores;
    Mutex                       submitMutex;

    // Command Buffers
    Mutex                   bufferQueueMutex;
    Atomic!uint             activeBufferCount;
    NioVkCommandBuffer[]    cmdBuffers;
    VkSemaphore[]           cmdSemaphores;
    VkFence[]               cmdFences;

    // Handles
    VkQueue handle_;
    VkCommandPool pool_;

    void createPool(NioCommandQueueDescriptor desc, VkQueue handle, uint familyIndex) {
        auto nvkDevice = (cast(NioVkDevice)device);
        this.handle_ = handle;

        auto createInfo = VkCommandPoolCreateInfo(
            queueFamilyIndex: familyIndex
        );
        vkEnforce(vkCreateCommandPool(nvkDevice.vkDevice, &createInfo, null, &pool_));
        nvkDevice.vkDevice.loadProcs(swapFuncs);

        this.cmdBuffers = nu_malloca!NioVkCommandBuffer(desc.maxCommandBuffers);
        this.cmdSemaphores = nu_malloca!VkSemaphore(desc.maxCommandBuffers);
        this.cmdFences = nu_malloca!VkFence(desc.maxCommandBuffers);
    }

    void cleanup() {
        auto nvkDevice = (cast(NioVkDevice)device);

        // Clean up all buffers that have been submitted. 
        bufferQueueMutex.lock();
        uint total = 0;
        foreach(i; 0..cmdBuffers.length) {
            if (vkWaitForFences(nvkDevice.vkDevice, 1, &cmdFences[i], VK_TRUE, 0) == VK_SUCCESS) {
                vkResetFences(nvkDevice.vkDevice, 1, &cmdFences[i]);
                
                // Reset layout and queue bindings.
                foreach(j; 0..cmdBuffers[i].toPresent.length) {
                    cmdBuffers[i].toPresent[j].vkReset();
                }
                cmdBuffers[i].toPresent.clear();
                
                // Release buffer, no longer in use.
                cmdBuffers[i].release();
            } else {
                cmdBuffers[total++] = cmdBuffers[i];
            }
        }
        cmdBuffers[total..$] = null;
        activeBufferCount = total;
        bufferQueueMutex.unlock();
    }

    void enqueue(NioVkCommandBuffer buffer) {
        auto nvkDevice = (cast(NioVkDevice)device);
        bufferQueueMutex.lock();
        uint bufferOffset = activeBufferCount;
        uint bufferCount = activeBufferCount+1;

        // Grow storage if needed.
        if (bufferCount > cmdBuffers.length) {
            this.cmdBuffers =    cmdBuffers.nu_resize(bufferCount);
            this.cmdSemaphores = cmdSemaphores.nu_resize(bufferCount);
            this.cmdFences =     cmdFences.nu_resize(bufferCount);

            auto semCreateInfo = VkSemaphoreCreateInfo();
            vkCreateSemaphore(nvkDevice.vkDevice, &semCreateInfo, null, &cmdSemaphores[bufferOffset]);
            
            auto fenCreateInfo = VkFenceCreateInfo();
            vkCreateFence(nvkDevice.vkDevice, &fenCreateInfo, null, &cmdFences[bufferOffset]);
        }
        cmdBuffers[bufferOffset] =                     buffer.retained();
        cmdBuffers[bufferOffset].completionSemaphore = cmdSemaphores[bufferOffset];
        cmdBuffers[bufferOffset].completionFence =     cmdFences[bufferOffset];

        activeBufferCount = bufferCount;
        bufferQueueMutex.unlock();
    }

    void submitImpl(NioVkCommandBuffer buffer) {

        // Don't allow null buffers or double submission.
        if (!buffer || buffer.completionFence)
            return;

        this.enqueue(buffer);

        // Add submission semaphores for awaiting the presentation
        // texture(s) being ready.
        auto presentCount = buffer.toPresent.length;
        if (presentCount > submitWaitSemaphores.length) {
            this.submitWaitSemaphores = submitWaitSemaphores.nu_resize(presentCount);
            this.submitSwapchainImages = submitSwapchainImages.nu_resize(presentCount);
            this.submitSwapchains = submitSwapchains.nu_resize(presentCount);
        }

        foreach(i; 0..presentCount) {
            this.submitWaitSemaphores[i] = VkSemaphoreSubmitInfo(
                semaphore: buffer.toPresent[i].semaphore,
                value: 1,
                stageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR,
                deviceIndex: 0
            );
        }

        auto cmdBufferInfo = VkCommandBufferSubmitInfo(
            commandBuffer: buffer.handle,
            deviceMask: 0
        );

        auto cmdSigInfo = VkSemaphoreSubmitInfo(
            semaphore: buffer.completionSemaphore,
            value: 1,
            stageMask: VK_PIPELINE_STAGE_2_ALL_GRAPHICS_BIT,
            deviceIndex: 0
        );

        auto submitInfo = VkSubmitInfo2(
            waitSemaphoreInfoCount: cast(uint)presentCount,
            pWaitSemaphoreInfos: submitWaitSemaphores.ptr,
            commandBufferInfoCount: 1,
            pCommandBufferInfos: &cmdBufferInfo,
            signalSemaphoreInfoCount: 1,
            pSignalSemaphoreInfos: &cmdSigInfo
        );
        vkQueueSubmit2(handle_, 1, &submitInfo, buffer.completionFence);

        if (presentCount > 0) {
            foreach(i; 0..presentCount) {
                this.submitSwapchains[i] = buffer.toPresent[i].swapchain;
                this.submitSwapchainImages[i] = buffer.toPresent[i].index;
            }
            auto presentInfo = VkPresentInfoKHR(
                waitSemaphoreCount: 1,
                pWaitSemaphores: &cmdSigInfo.semaphore,
                swapchainCount: cast(uint)presentCount,
                pSwapchains: submitSwapchains.ptr,
                pImageIndices: submitSwapchainImages.ptr,
                pResults: null
            );
            swapFuncs.vkQueuePresentKHR(handle_, &presentInfo);
        }
        buffer.release();
    }

protected:
    

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override void onLabelChanged(string label) {
        auto vkDevice = (cast(NioVkDevice)device).vkDevice;

        import niobium.vk.device : setDebugName;
        vkDevice.setDebugName(VK_OBJECT_TYPE_QUEUE, handle_, label);
        vkDevice.setDebugName(VK_OBJECT_TYPE_COMMAND_POOL, pool_, label);
    }

public:

    /// Destructor
    ~this() {
        auto nvkDevice = (cast(NioVkDevice)device);

        // Device must be idle first.
        vkDeviceWaitIdle(nvkDevice.vkDevice);

        // Then destroy fences and semaphores.
        foreach(i; 0..cmdFences.length)
            vkDestroyFence(nvkDevice.vkDevice, cmdFences[i], null);

        foreach(i; 0..cmdSemaphores.length)
            vkDestroySemaphore(nvkDevice.vkDevice, cmdSemaphores[i], null);
        
        nu_freea(submitSwapchainImages);
        nu_freea(submitSwapchains);
        nu_freea(submitWaitSemaphores);
        nu_freea(cmdBuffers);
        nu_freea(cmdSemaphores);
        nu_freea(cmdFences);
        
        vkDestroyCommandPool(nvkDevice.vkDevice, pool_, null);
        nogc_delete(bufferQueueMutex);
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
        this.bufferQueueMutex = nogc_new!Mutex();
        this.submitMutex = nogc_new!Mutex();

        this.createPool(desc, handle, familyIndex);
    }

    /**
        Fetches a $(D NioCommandBuffer) from the queue,
        the queue may contain an internal pool of command buffers.
    */
    override NioCommandBuffer fetch() {
        this.cleanup();
        return nogc_new!NioVkCommandBuffer(device, this);
    }

    /**
        Submits a single command buffer onto the queue.
        
        Params:
            buffer = The buffer to enqueue.
    */
    override void submit(NioCommandBuffer buffer) {
        submitMutex.lock();
        this.submitImpl(cast(NioVkCommandBuffer)buffer);
        submitMutex.unlock();
    }

    /**
        Submits a slice of command buffers into the queue.

        Params:
            buffers = The buffers to enqueue.
    */
    override void submit(NioCommandBuffer[] buffers) {
        submitMutex.lock();
        foreach(buffer; buffers)
            this.submitImpl(cast(NioVkCommandBuffer)buffer);
        submitMutex.unlock();
    }

    /**
        Allocates a command buffer from the queue
        associated with this object.

        Returns:
            A new $(D VkCommandBuffer)
    */
    VkCommandBuffer allocateCmdBuffer(VkCommandBufferLevel level) {
        VkCommandBuffer result;
        auto nvkDevice = (cast(NioVkDevice)device);

        auto allocInfo = VkCommandBufferAllocateInfo(
            commandPool: pool_,
            level: level,
            commandBufferCount: 1,
        );
        vkEnforce(vkAllocateCommandBuffers(nvkDevice.vkDevice, &allocInfo, &result));
        return result;
    }
}

/**
    A queue for encoding video.
*/
class NioVkVideoEncodeQueue : NioVideoEncodeQueue {
private:
@nogc:
    VkQueue handle_;

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device, VkQueue handle) {
        super(device);
        this.handle_ = handle;
    }

}

/**
    A queue for decoding video.
*/
class NioVkVideoDecodeQueue : NioVideoDecodeQueue {
private:
@nogc:
    VkQueue handle_;

public:

    /**
        Constructs a new queue.

        Params:
            device = The device that "owns" this queue.
            handle = Vulkan handle 
    */
    this(NioDevice device, VkQueue handle) {
        super(device);
        this.handle_ = handle;
    }
    
}