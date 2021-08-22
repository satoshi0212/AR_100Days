#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

struct day53_VertexInput {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
    float2 texcoord [[ attribute(SCNVertexSemanticTexcoord0) ]];
};

struct day53_NodeBuffer {
    float4x4 modelViewProjectionTransform;
};

struct day53_CustomBuffer {
    float effectIndex;
    float time;
};

struct day53_VertexOut {
    float4 position [[ position ]];
    float2 texcoord;
    float effectIndex;
    float time;
};

vertex day53_VertexOut day53_textureVertex(day53_VertexInput in [[ stage_in ]],
                               constant SCNSceneBuffer& scn_frame [[ buffer(0) ]],
                               constant day53_NodeBuffer& scn_node [[ buffer(1) ]],
                               constant day53_CustomBuffer& custom [[ buffer(2) ]]) {
    day53_VertexOut out;
    out.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    out.texcoord = in.texcoord;
    out.effectIndex = custom.effectIndex;
    out.time = custom.time;
    return out;
}

float mod(float a, float b) {
    return a - b * floor(a / b);
}

float2 mod(float2 x, float2 y) {
    return x - y * floor(x / y);
}

float pCheckers(float2 p,float n) {
    float2 q = p * n;
    return mod(floor(q.x) + floor(q.y), 2.0);
}

fragment half4 day53_textureFragment0(day53_VertexOut in [[ stage_in ]],
                                     texture2d<float> texture [[ texture(0) ]]) {
    const float TAU = 6.28318530718;
    float letime = in.time * .5 + 23.0;
    float2 p = mod(in.texcoord * TAU, TAU) - 250.0;
    float2 i = float2(p);
    float c = 1.0;
    float inten = .005;
    for (int n = 0; n < 5; n++) {
        float t = letime * (1.0 - (3.5 / float(n+1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + t) / inten), p.y / (cos(i.y + t) / inten)));
    }
    c /= float(5);
    c = 1.17 - pow(c, 1.4);
    float3 col = float3(pow(abs(c), 8.0));
    //col = clamp(col + float3(0.0, 0.35, 0.5), 0.0, 1.0);
    col = clamp(col + float3(0.5, 0.0, 0.0), 0.0, 1.0);
    return half4(half3(col), 1.0);
}

fragment half4 day53_textureFragment1(day53_VertexOut in [[ stage_in ]],
                                      texture2d<float> texture [[ texture(0) ]]) {
    float2 p = in.texcoord;
    p += 0.1 / 1.0 * in.time;
    float l = pCheckers(p, 10.0);
    return half4(half3(0.003, 0.768, 0.650) * l, 1.0);
}

fragment half4 day53_textureFragment2(day53_VertexOut in [[ stage_in ]],
                                     texture2d<float> texture [[ texture(0) ]]) {
    float color = 0.0;
    color += in.texcoord.x + sin(in.time);
    return half4(color, color, 0, 1.0);
}

fragment half4 day53_textureFragment3(day53_VertexOut in [[ stage_in ]],
                                      texture2d<float> texture [[ texture(0) ]]) {
    const float fluid_speed = 108.0;
    const float color_intensity = 0.9;
    float time = in.time;
    float2 p = in.texcoord;
    for (int i = 1; i < 30; i++) {
        float2 newp = p + time * 0.001;
        newp.x += 0.6 / float(i) * sin(float(i) * p.y + time / fluid_speed + 0.8 * float(i)) + 0.15;
        newp.y += 0.6 / float(i) * sin(float(i) * p.x + time / fluid_speed + 0.3 * float(i + 10)) - 0.5;
        p = newp;
    }
    float3 col = float3(color_intensity * sin(3.0 * p.x) + color_intensity, color_intensity * sin(13.0 * p.y) + color_intensity, color_intensity * sin(p.x + p.y) + color_intensity);
    return half4(half3(col), 1.0);
}

fragment half4 day53_textureFragment4(day53_VertexOut in [[ stage_in ]],
                                      texture2d<float> texture [[ texture(0) ]]) {

    float time = in.time;
    float2 position = in.texcoord;

    float color = 0.0;
    color += sin( position.x * cos( time / 30.0 ) * 80.0 ) + cos( position.y * cos( time / 15.0 ) * 20.0 );
    color += sin( position.y * sin( time / 50.0 ) * 40.0 ) + cos( position.x * sin( time / 25.0 ) * 90.0 );
    color += sin( position.x * sin( time / 40.0 ) * 10.0 ) + sin( position.y * sin( time / 35.0 ) * 80.0 );
    color *= sin( time / 10.0 ) * 0.5;

    return half4(half3(color, color * 30.5, sin(color + time / 5.0 ) * 0.35), 1);
}
