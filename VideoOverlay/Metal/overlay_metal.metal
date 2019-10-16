//
//  overlay_metal.metal
//  VideoOverlay
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//


#include <metal_stdlib>
#include <metal_common>
#include <metal_math>

using namespace metal;

float4 getPoint(uint2 ngid, texture2d<float, access::read> inTexture, float width, float height, float o_x, float o_y, bool reversed) {
    
    float ratio_w = inTexture.get_width() / width;
    float ratio_h = inTexture.get_height() / height;
    float ratio = ratio_w < ratio_h ? ratio_w : ratio_h;
    
    uint x = (ngid.x - (o_x - width / 2)) * ratio /*+ ratio == ratio_w ? 0 : (inTexture.get_width() / ratio - width) / 2*/;
    uint y = (ngid.y - (o_y - height / 2)) * ratio /*+ ratio == ratio_h ? 0 : (inTexture.get_height() / ratio - height) / 2*/;
    
    if (ratio == ratio_w) {
        y += (inTexture.get_height() - height * ratio) / 2;
    } else {
        x += (inTexture.get_width() - width * ratio) / 2;
    }
    
    return inTexture.read(uint2(x, reversed ? inTexture.get_height() - y : y));
}

bool isInCircle(uint2 uv, float2 center, float radius) {
    
    return pow((float)uv.x - center.x, 2) + pow((float)uv.y - center.y, 2) < pow(radius,2);
}

bool isInRectangle(uint2 uv, float2 center, float width, float height) {
    
    float x = (float) uv.x;
    float y = (float) uv.y;
    
    return x > center.x - width / 2 && x < center.x + width / 2 &&
    y > center.y - height / 2 && y < center.y + height / 2;
}

bool isInRegion(uint2 uv, float2 center, float width, float height, float cornerRadius) {
    if (cornerRadius > width / 2 && cornerRadius > height / 2) {
        return isInCircle(uv, center, cornerRadius);
    } else if (cornerRadius > width / 2) {
        float r_height = height / 2 - cornerRadius;
        float2 circle1 = float2(center.x, center.y + r_height);
        float2 circle2 = float2(center.x, center.y - r_height);
        return isInCircle(uv, circle1, cornerRadius) ||
        isInCircle(uv, circle2, cornerRadius) ||
        isInRectangle(uv, center, width, 2 * r_height);
    } else if (cornerRadius > height / 2) {
        float r_width = width / 2 - cornerRadius;
        float2 circle1 = float2(center.x + r_width, center.y);
        float2 circle2 = float2(center.x - r_width, center.y);
        return isInCircle(uv, circle1, cornerRadius) ||
        isInCircle(uv, circle2, cornerRadius) ||
        isInRectangle(uv, center, 2 * r_width, height);
    } else {
        float r_width = width / 2 - cornerRadius;
        float r_height = height / 2 - cornerRadius;
        float2 circle1 = float2(center.x + r_width, center.y + r_height);
        float2 circle2 = float2(center.x + r_width, center.y - r_height);
        float2 circle3 = float2(center.x - r_width, center.y + r_height);
        float2 circle4 = float2(center.x - r_width, center.y - r_height);
        return isInCircle(uv, circle1, cornerRadius) ||
        isInCircle(uv, circle2, cornerRadius) ||
        isInCircle(uv, circle3, cornerRadius) ||
        isInCircle(uv, circle4, cornerRadius) ||
        isInRectangle(uv, center, 2 * r_width, height) ||
        isInRectangle(uv, center, width, 2 * r_height);
    }
}

bool isInRegionStroke(uint2 uv, float2 center, float width, float height, float cornerRadius, float stroke_width) {
    return !isInRegion(uv, center, width, height, cornerRadius) && isInRegion(uv, center, width + 2 * stroke_width, height + 2 * stroke_width, cornerRadius + stroke_width);
}

kernel void produce_frame(texture2d<float, access::read> back_Texture [[ texture(0) ]],
                          texture2d<float, access::read> front_Texture [[ texture(1) ]],
                          texture2d<float, access::write> outTexture [[ texture(2) ]],
                          device const float *progress [[ buffer(0) ]],
                          device const float *borderColor_r [[ buffer(1) ]],
                          device const float *borderColor_g [[ buffer(2) ]],
                          device const float *borderColor_b [[ buffer(3) ]],
                          device const float *borderColor_a [[ buffer(4) ]],
                          device const float *borderWidth [[ buffer(5) ]],
                          device const float *cornerRadius [[ buffer(6) ]],
                          device const float *originX [[ buffer(7) ]],
                          device const float *originY [[ buffer(8) ]],
                          device const float *l_width [[ buffer(9) ]],
                          device const float *l_height [[ buffer(10) ]],
                          device const float *borderColor_r1 [[ buffer(11) ]],
                          device const float *borderColor_g1 [[ buffer(12) ]],
                          device const float *borderColor_b1 [[ buffer(13) ]],
                          device const float *borderColor_a1 [[ buffer(14) ]],
                          device const float *borderWidth1 [[ buffer(15) ]],
                          device const float *cornerRadius1 [[ buffer(16) ]],
                          device const float *originX1 [[ buffer(17) ]],
                          device const float *originY1 [[ buffer(18) ]],
                          device const float *l_width1 [[ buffer(19) ]],
                          device const float *l_height1 [[ buffer(20) ]],
                          device const float *backgroundColor_r [[ buffer(21) ]],
                          device const float *backgroundColor_g [[ buffer(22) ]],
                          device const float *backgroundColor_b [[ buffer(23) ]],
                          device const float *backgroundColor_a [[ buffer(24) ]],
                          device const bool *back_reverse [[ buffer(25) ]],
                          device const bool *front_reverse [[ buffer(26) ]],
                          uint2 gid [[ thread_position_in_grid ]])
{
    sampler displacementMap;
    
    float prog = *progress;
    
    float4 borderColor_back = float4(*borderColor_r, *borderColor_g, *borderColor_b, *borderColor_a);
    float4 borderColor_front = float4(*borderColor_r1, *borderColor_g1, *borderColor_b1, *borderColor_a1);
    
    float2 back_origin = float2(*originX, *originY);
    float2 front_origin = float2(*originX1, *originY1);
    
    float4 background_color = float4(*backgroundColor_r, *backgroundColor_g, *backgroundColor_b, *backgroundColor_a);
    
    if (isInRegionStroke(gid, front_origin, *l_width1, * l_height1, *cornerRadius1, *borderWidth1)) {
        float4 point = borderColor_front;
        outTexture.write(point, gid);
    } else if (isInRegion(gid, front_origin, *l_width1, * l_height1, *cornerRadius1)) {
        float4 point = getPoint(gid, front_Texture, *l_width1, *l_height1, *originX1, *originY1, *front_reverse);
        outTexture.write(point, gid);
    } else if (isInRegionStroke(gid, back_origin, *l_width, * l_height, *cornerRadius, *borderWidth)) {
        float4 point = borderColor_back;
        outTexture.write(point, gid);
    } else if (isInRegion(gid, back_origin, *l_width, * l_height, *cornerRadius)) {
        float4 point = getPoint(gid, back_Texture, *l_width, *l_height, *originX, *originY, *back_reverse);
        outTexture.write(point, gid);
    } else {
        float4 point = background_color;
        outTexture.write(point, gid);
    }
    
}

