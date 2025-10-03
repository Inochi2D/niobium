/**
    Niobium Types
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.types;

/**
    2D Extents
*/
struct NioExtent2D {
    uint width;
    uint height;
}

/**
    2D Origin
*/
struct NioOrigin2D {
    uint x;
    uint y;
}

/**
    3D Extents
*/
struct NioExtent3D {
    uint width;
    uint height;
    uint depth;
}

/**
    3D Origin
*/
struct NioOrigin3D {
    uint x;
    uint y;
    uint z;
}