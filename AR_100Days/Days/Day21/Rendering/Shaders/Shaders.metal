#include <metal_stdlib>
#include <simd/simd.h>

#import "Day21_ShaderTypes.h"

using namespace metal;

typedef struct {
    float3 position [[attribute(0)]];
    uint category [[attribute(1)]];
} Vertex;

typedef struct {
    float4 position [[position]];
    float4 color;
    half3  eyePosition;
    half3  normal;
    float pointsize [[point_size]];
    int fadeType;
    float distanceFromCenter;
} ColorInOut;

float3 HUEtoRGB(float H) {
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

float3 categoryToRGB(uint c) {
    if (c == 9) {
        return float3(0.f, 1.f, 0.f);
    }

#if NOT_SAMPLE_CODE
    // all white for now, comment this out if you want to use colors
    //return float3(1.0, 1.0, 1.0);
#endif
    
    if (c < 4) {    // 0=none, 1=wall, 2=floor, 3=ceiling
        return float3(1.0, 1.0, 1.0);
    }
    if (c == 4) {   // table
        return float3(1.0, 31.0/255.0, 33.0/255.0);   // red
    }
    if (c == 5) {   // seat
        return float3(1.0, 146.0/255.0, 145.0/255.0);  // pink
    }
    if (c == 6) {   // window
        return float3(43.0/255.0, 170.0/255.0, 1.0); // blue
    }
    if (c == 7) {   // door
        return float3(82.0/255.0, 1.0, 71.0/255.0);  // green
    }
    if (c == 8) {   // flashlight beam
        return float3(1.0, 0.941, 0.337); // yellow
    }
    return float3(1.0, 1.0, 1.0);
}

// Compute shader for particles.
kernel void particleCompute(device Vertex *vertices [[ buffer(Day21_kBufferIndexMeshPositions) ]], device Vertex *vbo [[ buffer(Day21_kBufferIndexVBO) ]], uint vid [[ thread_position_in_grid ]])
{
    vertices[vid].position = vbo[vid].position;
    vertices[vid].category = vbo[vid].category;
}

// Anchor geometry vertex function
vertex ColorInOut particleVertex(
                                 Vertex in [[stage_in]],
                                 constant Day21_SharedUniforms &sharedUniforms [[ buffer(Day21_kBufferIndexSharedUniforms) ]],
                                 uint vid [[vertex_id]]) {
    ColorInOut out;
    
    
    // Make position a float4 to perform 4x4 matrix math on it
    float4 position = float4(in.position, 1.0);

    // Calculate the position of our vertex in clip space and output for clipping and rasterization
    // * instanceUniforms[iid].modelMatrix
    out.position = sharedUniforms.projectionMatrix * sharedUniforms.viewMatrix * position;

    // Calculate the positon of our vertex in eye space
    float3 eyePosition = (sharedUniforms.viewMatrix * position).xyz;
    out.eyePosition = half3(eyePosition);
    
    // Rotate our normals to world coordinates
    float4 normal = float4(0, 1, 0, 0.0f);
    out.normal = normalize(half3(normal.xyz));

    float distanceFromCamera = length(out.eyePosition);
    float pointSizeFactor = (in.category == 9) ? 40.f : 3.f;
    out.pointsize = sharedUniforms.pointSize / distanceFromCamera * pointSizeFactor;

    if (in.category == 9) {
        out.fadeType = 2;
        out.color = float4(0, 1, 0, 1);
        return out;
    }
    out.fadeType = 1;
    float3 rgb = categoryToRGB(in.category);
    out.color = float4(rgb, 1);
    return out;
}

fragment float4 particleFragment(ColorInOut in [[stage_in]],
                                 float2 pointCoord [[point_coord]],
                                 constant Day21_SharedUniforms &uniforms [[ buffer(Day21_kBufferIndexSharedUniforms) ]]) {
    float4 color = in.color;
    float dist = distance(float2(0.5), pointCoord);
    if (dist > 0.5f) {
        discard_fragment();
    }

    if (in.fadeType == 2) {
        
        color.r = 0;
        color.g = 1;
        color.b = 0;
        
        if (dist > 0.25f) {
            color.a = 0.25 - (dist - 0.25f);
        }
        else {
            color.a = 1.f;
        }
    }
    else {
        color.a *= (1.f - (dist * 2.f));
    }
    return color;
}

// Models
struct ModelVertex {
    float4 position [[ attribute(Day21_kVertexAttributePosition) ]];
    float3 normal [[ attribute(Day21_kVertexAttributeNormal) ]];
    float2 uv [[ attribute(Day21_kVertexAttributeTexcoord) ]];
};

vertex ColorInOut modelVertex(const ModelVertex in [[ stage_in ]],
                              constant Day21_SharedUniforms &sharedUniforms [[ buffer(Day21_kBufferIndexSharedUniforms) ]],
                              constant Day21_InstanceUniforms *instanceUniforms [[ buffer(Day21_kBufferIndexInstanceUniforms) ]],
                              ushort iid [[instance_id]]) {


    ColorInOut out;
    
    float4 position = in.position;
    float4x4 modelMatrix = instanceUniforms[iid].modelMatrix;
    float4x4 modelViewMatrix = sharedUniforms.viewMatrix * modelMatrix;


    out.position = sharedUniforms.projectionMatrix * modelViewMatrix * position;
    out.color = instanceUniforms[iid].color;

    float3 eyePosition = (modelViewMatrix * position).xyz;
    out.eyePosition = half3(eyePosition);
    
    // Rotate our normals to world coordinates
    float4 normal = modelMatrix * float4(in.normal.x, in.normal.y, in.normal.z, 0.0f);
    out.normal = normalize(half3(normal.xyz));
    out.fadeType = instanceUniforms[iid].fadeType;
    out.distanceFromCenter = length(in.position);
    return out;
}

fragment float4 modelFragment(ColorInOut in [[ stage_in ]],
                              constant Day21_InstanceUniforms *instanceUniforms [[ buffer(Day21_kBufferIndexInstanceUniforms) ]]) {
    
    float4 color = in.color;

    float minDist = 1.1f;
    if (in.distanceFromCenter < minDist) {
        color.a *= 1.f;
    }
    else {
        float thresh = 4.f;
        float factor = max(0.f, thresh - (in.distanceFromCenter - minDist));
        if (factor == 0) {
            color.a = 0;
        }
        else {
            color.a *= factor/thresh/4.f;
        }
    }

    return color;
}
