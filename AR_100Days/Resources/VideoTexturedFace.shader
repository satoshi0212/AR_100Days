/*
 <samplecode>
 <abstract>
 SceneKit shader (geometry) modifier for texture mapping ARKit camera video onto the face.
 </abstract>
 </samplecode>
 */

#pragma arguments
float4x4 displayTransform // from ARFrame.displayTransform(for:viewportSize:)

#pragma body

// Transform the vertex to the camera coordinate system.
float4 vertexCamera = scn_node.modelViewTransform * _geometry.position;

// Camera projection and perspective divide to get normalized viewport coordinates (clip space).
float4 vertexClipSpace = scn_frame.projectionTransform * vertexCamera;
vertexClipSpace /= vertexClipSpace.w;
vertexClipSpace *= 0.93;

// XY in clip space is [-1,1]x[-1,1], so adjust to UV texture coordinates: [0,1]x[0,1].
// Image coordinates are Y-flipped (upper-left origin).
float4 vertexImageSpace = float4(vertexClipSpace.xy * 0.5 + 0.5, 0.0, 1.0);
vertexImageSpace.y = 1.0 - vertexImageSpace.y;

// Apply ARKit's display transform (device orientation * front-facing camera flip).
float4 transformedVertex = displayTransform * vertexImageSpace;

// Output as texture coordinates for use in later rendering stages.
//_geometry.texcoords[0] = transformedVertex.xy;
_geometry.texcoords[0] = transformedVertex.xy;

/**
 * MARK: Post-process special effects
 */

// Make head appear big. (You could also apply other geometry modifications here.)
_geometry.position.xyz *= 1.0;
