/**
    Niobium Metal Resources
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.resource;
import niobium.mtl.device;

public import niobium.resource;
public import niobium.mtl.resource.texture;
public import niobium.mtl.resource.buffer;


/**
    Creates a new shared resource handle from a system handle.

    Params:
        device =    The device which will be importing the handle.
        handle =    The underlying system handle to create a shared 
                    resource handle for.
*/
export extern(C) NioSharedResourceHandle nio_shared_resource_handle_create(NioDevice device, void* handle) @nogc {
    return null; // TODO: Implement this.
}