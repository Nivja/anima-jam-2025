// written by groverbuger for g3d
// september 2021
// + edited by EngineerSmith 2025
// MIT license

varying vec4 worldPosition;
varying vec4 viewPosition;
varying vec4 screenPosition;
varying vec3 vertexNormal;
varying vec4 vertexColor;

// this vertex shader is what projects 3d vertices in models onto your 2d screen
#ifdef VERTEX
uniform mat4 projectionMatrix; // handled by the camera
uniform mat4 viewMatrix;       // handled by the camera
uniform mat4 modelMatrix;      // models send their own model matrices when drawn

// the vertex normal attribute must be defined, as it is custom unlike the other attributes
attribute layout(location = 3) vec3 VertexNormal;

// define some varying vectors that are useful for writing custom fragment shaders
vec4 position(mat4 transformProjection, vec4 vertexPosition) {
    // calculate the positions of the transformed coordinates on the screen
    // save each step of the process, as these are often useful when writing custom fragment shaders
    worldPosition = modelMatrix * vertexPosition;
    viewPosition = viewMatrix * worldPosition;
    screenPosition = projectionMatrix * viewPosition;

    // save some data from this vertex for use in fragment shaders
    mat3 normalMatrix = transpose(inverse(mat3(modelMatrix)));
    vertexNormal = normalize(normalMatrix * VertexNormal);

    return screenPosition;
}
#endif


#ifdef PIXEL

uniform bool opaque;
uniform vec3 characterPositions[32];
uniform int numCharacters;
uniform float shadowRadiusX;
uniform float shadowRadiusZ;
uniform float shadowSoftness;
uniform float shadowStrength;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texturecolor = Texel(tex, texture_coords);
    vec4 outColor = texturecolor * color;
    if (outColor.a < 0.000001)
        discard;

    vec2 pixelXZ = worldPosition.xz;
    float overallShadowIntensity = 0.0;
    for (int i = 0; i < min(numCharacters, 32); i++) {
        vec2 characterXZ = characterPositions[i].xz;
        float characterAlpha = characterPositions[i].y;

        float dx = pixelXZ.x - characterXZ.x;
        float dz = pixelXZ.y - characterXZ.y; // pixelXz.y is mapped to worldPosition.z

        float invRadiusX = (shadowRadiusX > 0.0) ? (1.0 / shadowRadiusX) : 0.0;
        float invRadiusZ = (shadowRadiusZ > 0.0) ? (1.0 / shadowRadiusZ) : 0.0;
        float effectiveDistSq = (dx * invRadiusX) * (dx * invRadiusX) + (dz * invRadiusZ) * (dz * invRadiusZ);

        if (effectiveDistSq < 1.0) {
            float effectiveDist = sqrt(effectiveDistSq);
            float intensity = 1.0 - effectiveDist;
            intensity = pow(intensity, shadowSoftness);
            intensity *= characterAlpha;

            overallShadowIntensity = max(overallShadowIntensity, intensity);
        }
    }

    float darkeningFactor = max(1.0 - overallShadowIntensity * shadowStrength, 0.1);
    outColor.rgb *= darkeningFactor;

    if (opaque)
        outColor.a = 1;
    return outColor;
}
#endif