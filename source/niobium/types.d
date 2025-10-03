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

/**
    3D Region
*/
union NioRegion3D {
    struct {
        uint x;
        uint y;
        uint z;
        uint width;
        uint height;
        uint depth;
    }
    struct {
        NioOrigin3D origin;
        NioExtent3D extent;
    }
}

/**
    An RGBA color value.
*/
struct NioColor {
    float r;
    float g;
    float b;
    float a;
}

/**
    A viewport
*/
struct NioViewport {

    /**
        The X coordinate of upper-left corner of the viewport.
    */
    float originX;

    /**
        The Y coordinate of upper-left corner of the viewport.
    */
    float originY;

    /**
        The width of the viewport, in pixels.
    */
    float width;

    /**
        The height of the viewport, in pixels.
    */
    float height;

    /**
        The near-plane of the viewport.
    */
    float near;

    /**
        The far-plane of the viewport.
    */
    float far;
}

/**
    A scissor rectangle
*/
struct NioScissorRect {

    /**
        The X coordinate of upper-left corner of the 
        scissor rectangle.
    */
    float x;

    /**
        The Y coordinate of upper-left corner of the 
        scissor rectangle.
    */
    float y;

    /**
        The width of the viewport, in pixels.
    */
    float width;

    /**
        The height of the viewport, in pixels.
    */
    float height;
}