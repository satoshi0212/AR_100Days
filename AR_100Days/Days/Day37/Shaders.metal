#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands.
#import "Day37_ShaderTypes.h"

using namespace metal;

typedef struct {
    float2 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
} Day37_ImageVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} Day37_ImageColorInOut;

// Convert from YCbCr to rgb.
float4 Day37_ycbcrToRGBTransform(float4 y, float4 CbCr) {
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
} Day37_FogVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoordCamera;
    float2 texCoordScene;
} Day37_FogColorInOut;

// Fog the image vertex function.
vertex Day37_FogColorInOut fogVertexTransform(const device Day37_FogVertex* cameraVertices [[ buffer(0) ]],
                                        const device Day37_FogVertex* sceneVertices [[ buffer(1) ]],
                                        unsigned int vid [[ vertex_id ]]) {
    Day37_FogColorInOut out;

    const device Day37_FogVertex& cv = cameraVertices[vid];
    const device Day37_FogVertex& sv = sceneVertices[vid];

    out.position = float4(cv.position, 0.0, 1.0);
    out.texCoordCamera = cv.texCoord;
    out.texCoordScene = sv.texCoord;

    return out;
}

float sigmoid(float a, float f) {
    return 1.0 / (1.0 + exp(-f * a));
}

fragment half4 fogFragmentShader(Day37_FogColorInOut in [[ stage_in ]],
                                 texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                                 texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                                 depth2d<float, access::sample> arDepthTexture [[ texture(2) ]],
                                 texture2d<uint> arDepthConfidence [[ texture(3) ]])
{
    const float fogMax = 5.0;

    const half4 fogColor = half4(215.0/255.0, 125.0/255.0, 173.0/255.0, 1.0);

    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float4 rgb = Day37_ycbcrToRGBTransform(
                                     cameraImageTextureY.sample(s, in.texCoordCamera),
                                     cameraImageTextureCbCr.sample(s, in.texCoordCamera)
                                     );
    half4 cameraColor = half4(rgb);

    // Sample this pixel's depth value.
    float depth = arDepthTexture.sample(s, in.texCoordCamera);

    // Ignore depth values greater than the maximum fog distance.
    depth = clamp(depth, 0.0, fogMax);

    // Determine this fragment's percentage of fog.
    float fogPercentage = depth / fogMax;

    //    float edgeStrength = length(fwidth(cameraColor));
    //    edgeStrength = sigmoid(edgeStrength - 0.2, 15.0);
    //    half4 filteredColor = half4(half3(edgeStrength), 1.0);

    // Mix the camera and fog colors based on the fog percentage.
    //half4 foggedColor = mix(cameraColor, filteredColor, fogPercentage);
    half4 foggedColor = mix(cameraColor, fogColor, fogPercentage);

    return foggedColor;
}
