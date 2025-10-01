/**
    nioinfo Utility Application
    
    Lists information about GPUs supported by niobium.

    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module app;
import niobium;
import std.stdio;

void main() {
	writefln("Devices: %s", NioDevice.systemDevices().length);
	foreach(i, device; NioDevice.systemDevices()) {
		writefln("%s: (%s):", i, device.name);
		writefln("  Queues: %s", device.queueCount);
		writefln("  Features:");
		writefln("    presentation=%s", device.features.presentation);
		writefln("    meshShaders=%s", device.features.meshShaders);
		writefln("    geometryShaders=%s", device.features.geometryShaders);
		writefln("    tesselationShaders=%s", device.features.tesselationShaders);
		writefln("    videoEncode=%s", device.features.videoEncode);
		writefln("    videoDecode=%s", device.features.videoDecode);
		writefln("    dualSourceBlend=%s", device.features.dualSourceBlend);
	}
}