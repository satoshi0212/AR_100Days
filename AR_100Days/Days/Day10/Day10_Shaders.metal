/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's shaders.
*/

#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands. 
//#import "ShaderTypes.h"

using namespace metal;

//typedef struct {
//    float2 position [[attribute(kVertexAttributePosition)]];
//    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
//} ImageVertex;

typedef struct {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
} Day10_ImageVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} Day10_ImageColorInOut;

// Convert from YCbCr to rgb.
float4 Day10_ycbcrToRGBTransform(float4 y, float4 CbCr) {
    const float4x4 ycbcrToRGBTransform = float4x4(
      float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
      float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
      float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
      float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    float4 ycbcr = float4(y.r, CbCr.rg, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

typedef struct {
    float2 position;
    float2 texCoord;
} Day10_FogVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoordCamera;
    float2 texCoordScene;
} Day10_FogColorInOut;

// Fog the image vertex function.
vertex Day10_FogColorInOut Day10_fogVertexTransform(const device Day10_FogVertex* cameraVertices [[ buffer(0) ]],
                                                         const device Day10_FogVertex* sceneVertices [[ buffer(1) ]],
                                                         unsigned int vid [[ vertex_id ]]) {
    Day10_FogColorInOut out;

    const device Day10_FogVertex& cv = cameraVertices[vid];
    const device Day10_FogVertex& sv = sceneVertices[vid];

    out.position = float4(cv.position, 0.0, 1.0);
    out.texCoordCamera = cv.texCoord;
    out.texCoordScene = sv.texCoord;

    return out;
}

// Fog fragment function.
fragment half4 Day10_fogFragmentShader(Day10_FogColorInOut in [[ stage_in ]],
                                 texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                                 texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                                 depth2d<float, access::sample> arDepthTexture [[ texture(2) ]],
                                 texture2d<uint> arDepthConfidence [[ texture(3) ]])
{
    // Whether to show the confidence debug visualization.
    // - Tag: ConfidenceVisualization
    // Set to `true` to visualize confidence.
    bool confidenceDebugVisualizationEnabled = false;
    
    // Set the maximum fog saturation to 4.0 meters. Device maximum is 5.0 meters.
    const float fogMax = 4.0;
    
    // Fog is fully opaque, middle grey
    //const half4 fogColor = half4(0.5, 0.5, 0.5, 0.0);

    // Confidence debug visualization is red.
    const half4 confidenceColor = half4(1.0, 0.0, 0.0, 1.0);
    
    // Maximum confidence is `ARConfidenceLevelHigh` = 2.
    const uint maxConfidence = 2;
    
    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    // Sample this pixel's camera image color.
    float4 rgb = Day10_ycbcrToRGBTransform(
        cameraImageTextureY.sample(s, in.texCoordCamera),
        cameraImageTextureCbCr.sample(s, in.texCoordCamera)
    );


    float2 offset = in.texCoordScene;
    constexpr sampler s2(coord::normalized, address::clamp_to_edge);
    float width = cameraImageTextureY.get_width();
    float height = cameraImageTextureY.get_width();
    float xPixel = (1 / width) * 4;
    float yPixel = (1 / height) * 3;
    float3 sum = float3(0.0, 0.0, 0.0);
    float3 sum2 = float3(0.0, 0.0, 0.0);

    sum += cameraImageTextureY.sample(s2, float2(offset.x - 4.0*xPixel, offset.y - 4.0*yPixel)).rgb * 0.0162162162;
    sum += cameraImageTextureY.sample(s2, float2(offset.x - 3.0*xPixel, offset.y - 3.0*yPixel)).rgb * 0.0540540541;
    sum += cameraImageTextureY.sample(s2, float2(offset.x - 2.0*xPixel, offset.y - 2.0*yPixel)).rgb * 0.1216216216;
    sum += cameraImageTextureY.sample(s2, float2(offset.x - 1.0*xPixel, offset.y - 1.0*yPixel)).rgb * 0.1945945946;
    sum += cameraImageTextureY.sample(s2, offset).rgb * 0.2270270270;
    sum += cameraImageTextureY.sample(s2, float2(offset.x + 1.0*xPixel, offset.y + 1.0*yPixel)).rgb * 0.1945945946;
    sum += cameraImageTextureY.sample(s2, float2(offset.x + 2.0*xPixel, offset.y + 2.0*yPixel)).rgb * 0.1216216216;
    sum += cameraImageTextureY.sample(s2, float2(offset.x + 3.0*xPixel, offset.y + 3.0*yPixel)).rgb * 0.0540540541;
    sum += cameraImageTextureY.sample(s2, float2(offset.x + 4.0*xPixel, offset.y + 4.0*yPixel)).rgb * 0.0162162162;

    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x - 4.0*xPixel, offset.y - 4.0*yPixel)).rgb * 0.0162162162;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x - 3.0*xPixel, offset.y - 3.0*yPixel)).rgb * 0.0540540541;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x - 2.0*xPixel, offset.y - 2.0*yPixel)).rgb * 0.1216216216;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x - 1.0*xPixel, offset.y - 1.0*yPixel)).rgb * 0.1945945946;
    sum2 += cameraImageTextureCbCr.sample(s2, offset).rgb * 0.2270270270;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x + 1.0*xPixel, offset.y + 1.0*yPixel)).rgb * 0.1945945946;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x + 2.0*xPixel, offset.y + 2.0*yPixel)).rgb * 0.1216216216;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x + 3.0*xPixel, offset.y + 3.0*yPixel)).rgb * 0.0540540541;
    sum2 += cameraImageTextureCbCr.sample(s2, float2(offset.x + 4.0*xPixel, offset.y + 4.0*yPixel)).rgb * 0.0162162162;

    float4 rgb2 = Day10_ycbcrToRGBTransform(float4(sum, 1.0), float4(sum2, 1.0));


    half4 cameraColor = half4(rgb);

    // Sample this pixel's depth value.
    float depth = arDepthTexture.sample(s, in.texCoordCamera);
    
    // Ignore depth values greater than the maximum fog distance.
    depth = clamp(depth, 0.0, fogMax);
    
    // Determine this fragment's percentage of fog.
    //float fogPercentage = depth / fogMax;
    float fogPercentage = depth / 2.0;

    // Mix the camera and fog colors based on the fog percentage.
    //half4 foggedColor = mix(cameraColor, fogColor, fogPercentage);
    half4 foggedColor = mix(cameraColor, half4(rgb2), fogPercentage);

    // Just return the fogged color if confidence visualization is disabled.
    if(!confidenceDebugVisualizationEnabled) {
        return foggedColor;
    } else {
        // Sample the depth confidence.
        uint confidence = arDepthConfidence.sample(s, in.texCoordCamera).x;
        
        // Assign a color percentage based on confidence.
        float confidencePercentage = (float)confidence / (float)maxConfidence;

        // Return the mixed confidence and foggedColor.
        return mix(confidenceColor, foggedColor, confidencePercentage);
    }
}
