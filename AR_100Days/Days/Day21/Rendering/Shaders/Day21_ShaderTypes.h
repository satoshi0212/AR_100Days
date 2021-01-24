//#ifndef ShaderTypes_h
//#define ShaderTypes_h

#include <simd/simd.h>

typedef enum Day21_BufferIndices {
    Day21_kBufferIndexMeshPositions    = 0,
    Day21_kBufferIndexMeshGenerics     = 1,
    Day21_kBufferIndexInstanceUniforms = 2,
    Day21_kBufferIndexSharedUniforms   = 3,
    Day21_kBufferIndexDebug            = 4,
    Day21_kBufferIndexVBO              = 5
} Day21_BufferIndices;

typedef enum Day21_VertexAttributes {
    Day21_kVertexAttributePosition  = 0,
    Day21_kVertexAttributeTexcoord  = 1,
    Day21_kVertexAttributeNormal    = 2,
    Day21_kVertexAttributeTangent = 3,
    Day21_kVertexAttributeBitangent = 4
} Day21_VertexAttributes;

typedef struct {
    // Camera Uniforms
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 deviceMatrix;   // device in space
    
    float pointSize;
    float progress; // 0 for pre-intro, 1 for intro Complete

} Day21_SharedUniforms;

typedef struct {
    matrix_float4x4 modelMatrix;
    simd_float4 color;
    int fadeType;
} Day21_InstanceUniforms;

//#endif /* ShaderTypes_h */
