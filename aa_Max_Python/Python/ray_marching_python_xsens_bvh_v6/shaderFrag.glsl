#version 330 core

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;

const int jointCount = 28;
const int edgeCount = 27;
const int objectCount = 10;

uniform float iGlobalTime;

in vec2 fragCoord;
out vec4 fragColor;

// camera settings
uniform vec3 camPosition;
uniform float camAngle;

// light settings
uniform vec3 lightPosition;

// background color
uniform vec3 bgColor;
uniform vec3 bgOcclusionColor;

// surface struct

struct Surface 
{
    vec3 color;
    float ambientScale;
    float diffuseScale;
    float specularScale;
    float specularPow;
    float occlusionScale;
    float occlusionRange;
    float occlusionResolution;
    vec3 occlusionColor; 
    float signedDistance;
};

// skeleton joint settings
uniform vec3 jointColor;
uniform float jointAmbientScale;
uniform float jointDiffuseScale;
uniform float jointSpecularScale;
uniform float jointSpecularPow;
uniform float jointOcclusionScale;
uniform float jointOcclusionRange;
uniform float jointOcclusionResolution;
uniform vec3 jointOcclusionColor;

uniform int jointPrimitives[jointCount];
uniform mat4 jointTransforms[jointCount];
uniform vec3 jointSizes[jointCount];
uniform float jointRoundings[jointCount];
uniform float jointSmoothings[jointCount];

// skeleton edge settings
uniform vec3 edgeColor;
uniform float edgeAmbientScale;
uniform float edgeDiffuseScale;
uniform float edgeSpecularScale;
uniform float edgeSpecularPow;
uniform float edgeOcclusionScale;
uniform float edgeOcclusionRange;
uniform float edgeOcclusionResolution;
uniform vec3 edgeOcclusionColor;

uniform int edgePrimitives[edgeCount];
uniform mat4 edgeTransforms[edgeCount];
uniform float edgeLengths[edgeCount];
uniform vec3 edgeSizes[edgeCount];
uniform float edgeRoundings[edgeCount];
uniform float edgeSmoothings[edgeCount];

// object settings
uniform vec3 objectColors[objectCount];
uniform float objectAmbientScales[objectCount];
uniform float objectDiffuseScales[objectCount];
uniform float objectSpecularScales[objectCount];
uniform float objectSpecularPows[objectCount];
uniform float objectOcclusionScales[objectCount];
uniform float objectOcclusionRanges[objectCount];
uniform float objectOcclusionResolutions[objectCount];
uniform vec3 objectOcclusionColors[objectCount];

uniform vec3 objectFrequencies[objectCount];
uniform vec3 objectAmplitudes[objectCount];
uniform vec3 objectPhases[objectCount];

uniform int objectPrimitives[objectCount];
uniform mat4 objectTransforms[objectCount];
uniform vec3 objectSizes[objectCount];
uniform float objectRoundings[objectCount];
uniform float objectSmoothings[objectCount];

// combined smoothing factors

uniform float jointEdgeSmoothing;
uniform float skelObjectSmoothing;

/*
Affine Transformations
*/

// Translation matrix
mat4 translate(vec3 pos) 
{
    return mat4(
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
		vec4(pos.x, pos.y, pos.z, 1)
    );
}

// Rotation matrix around the X axis.
mat4 rotateX(float theta) 
{
    float c = cos(theta);
    float s = sin(theta);
    return mat4(
        vec4(1, 0, 0, 0),
        vec4(0, c, -s, 0),
        vec4(0, s, c, 0),
		vec4(0, 0, 0, 1)
    );
}

// Rotation matrix around the Y axis.
mat4 rotateY(float theta) 
{
    float c = cos(theta);
    float s = sin(theta);
    return mat4(
        vec4(c, 0, s, 0),
        vec4(0, 1, 0, 0),
        vec4(-s, 0, c, 0),
		vec4(0, 0, 0, 1)
    );
}

// Rotation matrix around the Z axis.
mat4 rotateZ(float theta) 
{
    float c = cos(theta);
    float s = sin(theta);
    return mat4(
        vec4(c, -s, 0, 0),
        vec4(s, c, 0, 0),
        vec4(0, 0, 1, 0),
		vec4(0, 0, 0, 1)
    );
}

// Rotation matrix around arbitrary axis
mat4 rotateAxis(vec3 axis, float angle)
{
	axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

/*
Constructive solid geometry
*/

// intersection
float intersectSDF(float distA, float distB) 
{
    return max(distA, distB);
}

// union
float unionSDF(float distA, float distB) 
{
    return min(distA, distB);
}

// difference
float differenceSDF(float distA, float distB) 
{
    return max(distA, -distB);
}

/*
Smoothing Operations
*/

// exponential smooth
float exp_smin( float a, float b, float k )
{
    float res = exp( -k*a ) + exp( -k*b );
    return -log( res )/k;
}

// polynomial smooth
float poly_smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

// power smooth
float power_smin( float a, float b, float k )
{
    a = pow( a, k ); b = pow( b, k );
    return pow( (a*b)/(a+b), 1.0/k );
}

// polynomial smooth min which returns both signed distance and interpolation factor
vec2 poly_smin_surface( float a, float b, float k )
{
    float h = max( k-abs(a-b), 0.0 )/k;
    float m = h*h*0.5;
    float s = m*k*(1.0/2.0);
    return (a<b) ? vec2(a-s,m) : vec2(b-s,1.0-m);
}

// surface smooth union
Surface union_surface(in Surface surface1, in Surface surface2, in float smoothness)
{
    vec2 sd = poly_smin_surface(surface1.signedDistance, surface2.signedDistance, smoothness);

    float signedDistance = sd[0];
    float interpol = sd[1];
    

    vec3 mixColor = mix(surface1.color, surface2.color, interpol);
    float mixAmbientScale = mix(surface1.ambientScale, surface2.ambientScale, interpol);
    float mixDiffuseScale = mix(surface1.diffuseScale, surface2.diffuseScale, interpol);
    float mixSpecularScale = mix(surface1.specularScale, surface2.specularScale, interpol);
    float mixSpecularPow = mix(surface1.specularPow, surface2.specularPow, interpol);
    float mixOcclusionScale = mix(surface1.occlusionScale, surface2.occlusionScale, interpol);
    float mixOcclusionRange = mix(surface1.occlusionRange, surface2.occlusionRange, interpol);
    float mixOcclusionResolution = mix(surface1.occlusionResolution, surface2.occlusionResolution, interpol);
    vec3 mixOcclusionColor = mix(surface1.occlusionColor, surface2.occlusionColor, interpol);

    return Surface(mixColor, mixAmbientScale, mixDiffuseScale, mixSpecularScale, mixSpecularPow, mixOcclusionScale, mixOcclusionRange, mixOcclusionResolution, mixOcclusionColor, signedDistance);
}

/*
Signed Distance Functions
*/

// Sphere (radius r)
float sphereSDF(vec3 p, float r) 
{
    return length(p) - r;
}

// Sphere Ripple
float rippleSphereSDF(vec3 pos, float radius, vec3 frequencies, vec3 amplitudes, vec3 phases)
{
    vec3 normPos = normalize(pos);

    vec3 axisAlign = normPos;

    vec3 surfaceDeformShape = vec3(cos(axisAlign.x * frequencies.x + phases.x), cos(axisAlign.y * frequencies.y + phases.y), cos(axisAlign.z * frequencies.z + phases.z));

    vec3 surfaceDeformScale = vec3(1.0 - abs(axisAlign.x), 1.0 - abs(axisAlign.y), 1.0 - abs(axisAlign.z)) * amplitudes;

    vec3 surfaceDeform = surfaceDeformShape * surfaceDeformScale;

    return length(pos) - radius + length(surfaceDeform);
}

// Box
float boxSDF( vec3 p, vec3 size )
{
    vec3 d = abs(p) - (size / 2.0);
    
    // Assuming p is inside the cube, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    
    // Assuming p is outside the cube, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(d, 0.0));
    
    return insideDistance + outsideDistance;
}

// Box Round
float roundBoxSDF( vec3 p, vec3 size, float radius )
{
    vec3 d = abs(p) - ((size - radius) / 2.0);
    
    // Assuming p is inside the cube, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    
    // Assuming p is outside the cube, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(d, 0.0));
    
    return insideDistance + outsideDistance - radius;
}

// Box Ripple
float rippleBoxSDF(vec3 pos, vec3 size, float radius, vec3 frequencies, vec3 amplitudes, vec3 phases)
{
    vec3 normPos = vec3(clamp(pos.x, -size.x / 2, size.x / 2) / size.x, clamp(pos.y, -size.y / 2, size.y / 2) / size.y, clamp(pos.z, -size.z / 2, size.z / 2) / size.z);

    vec3 surfaceDeformShape = vec3(0.0, 0.0, 0.0);
    surfaceDeformShape.y += cos(normPos.x * frequencies.x + phases.x);
    surfaceDeformShape.z += cos(normPos.x * frequencies.x + phases.x);
    surfaceDeformShape.x += cos(normPos.y * frequencies.y + phases.y);
    surfaceDeformShape.z += cos(normPos.y * frequencies.y + phases.y);
    surfaceDeformShape.x += cos(normPos.z * frequencies.z + phases.z);
    surfaceDeformShape.y += cos(normPos.z * frequencies.z + phases.z);

    vec3 surfaceDeform = surfaceDeformShape * amplitudes;

    vec3 d = abs(pos) - ((size + surfaceDeform - radius) / 2.0);
    
    // Assuming p is inside the cube, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    
    // Assuming p is outside the cube, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(d, 0.0));
    
    return insideDistance + outsideDistance - radius;
}

// Cylinder(XY aligned, height h and radius r)
float cylinderSDF(vec3 p, float h, float r) 
{
    // How far inside or outside the cylinder the point is, radially
    float inOutRadius = length(p.xy) - r;
    
    // How far inside or outside the cylinder is, axially aligned with the cylinder
    float inOutHeight = abs(p.z) - h/2.0;
    
    // Assuming p is inside the cylinder, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(inOutRadius, inOutHeight), 0.0);

    // Assuming p is outside the cylinder, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(vec2(inOutRadius, inOutHeight), 0.0));
    
    return insideDistance + outsideDistance;
}

// Cylinder(XY aligned, height h and radius r)
float roundCylinderSDF(vec3 p, float h, float r, float radius) 
{
    // How far inside or outside the cylinder the point is, radially
    float inOutRadius = length(p.xy) - (r - radius);
    
    // How far inside or outside the cylinder is, axially aligned with the cylinder
    float inOutHeight = abs(p.z) - (h - radius)/2.0;
    
    // Assuming p is inside the cylinder, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(inOutRadius, inOutHeight), 0.0);

    // Assuming p is outside the cylinder, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(vec2(inOutRadius, inOutHeight), 0.0));
    
    return insideDistance + outsideDistance - radius;
}

// Cylinder Ripple
float rippleCylinderSDF(vec3 pos, float height, float r, float radius, vec3 frequencies, vec3 amplitudes, vec3 phases) 
{
    //vec3 normPos = vec3(clamp(pos.x, -radius, radius) / radius, clamp(pos.y, -radius, radius) / radius, clamp(pos.z, -height/2, height/2) / (height / 2));

    vec3 normPos = vec3(normalize(pos).x, normalize(pos).y, clamp(pos.z, -height/2, height/2) / (height / 2));

    vec3 surfaceDeformShape = vec3(0.0, 0.0, 0.0);

    surfaceDeformShape.x += cos(normPos.z * frequencies.z + phases.z);
    surfaceDeformShape.x += cos(normPos.y * frequencies.y + phases.y);
    surfaceDeformShape.y += cos(normPos.x * frequencies.x + phases.x);
    surfaceDeformShape.y += cos(normPos.z * frequencies.z + phases.z);
    surfaceDeformShape.z += cos(normPos.x * frequencies.x + phases.x);
    surfaceDeformShape.z += cos(normPos.y * frequencies.y + phases.y);

    vec3 surfaceDeformScale = amplitudes * 0.2;
    vec3 surfaceDeform = surfaceDeformShape * surfaceDeformScale;

    // How far inside or outside the cylinder the point is, radially
    float inOutRadius = length(pos.xy) - (r - radius) + length(surfaceDeform.xy);

    // How far inside or outside the cylinder is, axially aligned with the cylinder
    float inOutHeight = abs(pos.z) - (height/2.0 - radius)/2.0 + surfaceDeform.z;
    
    // Assuming p is inside the cylinder, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(inOutRadius, inOutHeight), 0.0);

    // Assuming p is outside the cylinder, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(vec2(inOutRadius, inOutHeight), 0.0));
    
    return insideDistance + outsideDistance - radius;
}


// Capsule (XY aligned, height h and radius r)
float CapsuleSDF( vec3 p, float h, float r )
{
	p.z -= clamp( p.z, -h / 2.0, h / 2.0 );
	return length( p ) - r;
}

// Capsule (XY aligned, height h and radius r)
float roundCapsuleSDF( vec3 p, float h, float r, float radius )
{
	p.z -= clamp( p.z, -(h - radius) / 2.0, (h - radius) / 2.0 );
	return length( p ) - r - radius;
}


/**
 * Signed distance function describing the scene.
 * 
 * Absolute value of the return value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */
float sceneSDF(vec3 samplePoint) 
{    
    vec4 samplePoint4D = vec4(samplePoint, 1.0);

    float distJoints = 1000.0;
    
    for(int jI=0; jI<jointCount; ++jI)
    {
        if(jointPrimitives[jI] < 0) // do nothing
        {}
        else if(jointPrimitives[jI] == 0) // sphere
        {
            distJoints = poly_smin( distJoints, sphereSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].x), jointSmoothings[jI] );
        }
        else if(jointPrimitives[jI] == 1) // box
        {
            //distJoints = poly_smin( distJoints, boxSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI]), jointSmoothings[jI] );
            distJoints = poly_smin( distJoints, roundBoxSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI], jointRoundings[jI]), jointSmoothings[jI] );
        }
        else if(jointPrimitives[jI] == 2) // capsule
        {
            //distJoints = poly_smin( distJoints, CapsuleSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].z, jointSizes[jI].x), jointSmoothings[jI] ); 
            distJoints = poly_smin( distJoints, roundCapsuleSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].z, jointSizes[jI].x, jointRoundings[jI]), jointSmoothings[jI] ); 
        }
        else if(jointPrimitives[jI] == 3) // cylinder
        {
            //distJoints = poly_smin( distJoints, cylinderSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].z, jointSizes[jI].x), jointSmoothings[jI] ); 
            distJoints = poly_smin( distJoints, roundCylinderSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].z, jointSizes[jI].x, jointRoundings[jI]), jointSmoothings[jI] ); 
        }
    }
    
    float distEdges = 1000.0;
    

    for(int eI=0; eI<edgeCount; ++eI)
    {
        if(edgePrimitives[eI] < 0) // do nothing
        {}
        else if(edgePrimitives[eI] == 0) // sphere
        {
            distEdges = poly_smin( distEdges, sphereSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z), edgeSmoothings[eI] );
        }
        else if(edgePrimitives[eI] == 1) // box
        {
            //distEdges = poly_smin( distEdges, boxSDF((edgeTransforms[eI] * samplePoint4D).xyz, vec3(edgeSizes[eI].x, edgeSizes[eI].y, edgeLengths[eI] * edgeSizes[eI].z)), edgeSmoothings[eI] );
            distEdges = poly_smin( distEdges, roundBoxSDF((edgeTransforms[eI] * samplePoint4D).xyz, vec3(edgeSizes[eI].x, edgeSizes[eI].y, edgeLengths[eI] * edgeSizes[eI].z), edgeRoundings[eI]), edgeSmoothings[eI] );
        }
        else if(edgePrimitives[eI] == 2) // capsule
        {
            //distEdges = poly_smin( distEdges, CapsuleSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z, edgeSizes[eI].x), edgeSmoothings[eI] ); 
            distEdges = poly_smin( distEdges, roundCapsuleSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z, edgeSizes[eI].x, edgeRoundings[eI]), edgeSmoothings[eI] ); 
        }
        else if(edgePrimitives[eI] == 3) // cylinder
        {
            //distEdges = poly_smin( distEdges, cylinderSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z, edgeSizes[eI].x), edgeSmoothings[eI] ); 
            distEdges = poly_smin( distEdges, roundCylinderSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z, edgeSizes[eI].x, edgeRoundings[eI]), edgeSmoothings[eI] ); 
        }
    }
    
    float distObjects = 1000.0;
    
    for(int oI=0; oI<objectCount; ++oI)
    {    
        if(objectPrimitives[oI] < 0) // do nothing
        {}
        else if(objectPrimitives[oI] == 0) // sphere
        {
            if(objectAmplitudes[oI] == 0) // non-rippling
            {
                distObjects = poly_smin( distObjects, sphereSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].x), objectSmoothings[oI] );
            }
            else
            {
                distObjects = poly_smin( distObjects, rippleSphereSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].x, objectFrequencies[oI], objectAmplitudes[oI], objectPhases[oI] ), objectSmoothings[oI] );
            }
        }
        else if(objectPrimitives[oI] == 1) // box
        {
            if(objectAmplitudes[oI] == 0) // non-rippling
            {
                distObjects = poly_smin( distObjects, roundBoxSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI], objectRoundings[oI]), objectSmoothings[oI] );
            }
            else
            {
                distObjects = poly_smin( distObjects, rippleBoxSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI], objectRoundings[oI], objectFrequencies[oI], objectAmplitudes[oI], objectPhases[oI]), objectSmoothings[oI] );
            }
        }
        else if(objectPrimitives[oI] == 2) // capsule
        {
            distObjects = poly_smin( distObjects, roundCapsuleSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].z, objectSizes[oI].x, objectRoundings[oI]), objectSmoothings[oI] ); 
        }
        else if(objectPrimitives[oI] == 3) // cylinder
        {
            if(objectAmplitudes[oI] == 0) // non-rippling
            {
                distObjects = poly_smin( distObjects, roundCylinderSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].z, objectSizes[oI].x, objectRoundings[oI]), objectSmoothings[oI] ); 
            }
            else
            {
                distObjects = poly_smin( distObjects, rippleCylinderSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].z, objectSizes[oI].x, objectRoundings[oI], objectFrequencies[oI], objectAmplitudes[oI], objectPhases[oI]), objectSmoothings[oI] );
            }
        }
    }
    
    float distJointEdges = 1000.0;
    
    if(distJoints < 1000.0 && distEdges < 1000.0)
    {
        distJointEdges = poly_smin(distJoints, distEdges, jointEdgeSmoothing);
    }
    else if(distJoints < 1000.0)
    {
        distJointEdges = distJoints;
    }
    else if(distEdges < 1000.0)
    {
        distJointEdges = distEdges;
    }
    
    float dist;
    
    if(distObjects < 1000.0)
    {
        dist = poly_smin(distJointEdges, distObjects, skelObjectSmoothing);
    }
    else
    {
        dist = distJointEdges;
    }
    
    return dist;
}

Surface sceneSDF_surface(vec3 samplePoint) 
{    
    vec4 samplePoint4D = vec4(samplePoint, 1.0);

    // skeleton joints
    float distJoints = 1000.0;
    
    for(int jI=0; jI<jointCount; ++jI)
    {
        if(jointPrimitives[jI] < 0) // do nothing
        {}
        else if(jointPrimitives[jI] == 0) // sphere
        {
            distJoints = poly_smin( distJoints, sphereSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].x), jointSmoothings[jI] );
        }
        else if(jointPrimitives[jI] == 1) // box
        {
            distJoints = poly_smin( distJoints, roundBoxSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI], jointRoundings[jI]), jointSmoothings[jI] );
        }
        else if(jointPrimitives[jI] == 2) // capsule
        {
            distJoints = poly_smin( distJoints, roundCapsuleSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].z, jointSizes[jI].x, jointRoundings[jI]), jointSmoothings[jI] ); 
        }
        else if(jointPrimitives[jI] == 3) // cylinder
        {
            distJoints = poly_smin( distJoints, roundCylinderSDF((jointTransforms[jI] * samplePoint4D).xyz, jointSizes[jI].z, jointSizes[jI].x, jointRoundings[jI]), jointSmoothings[jI] ); 
        }
    }
    
    Surface jointSurface = Surface(jointColor, jointAmbientScale, jointDiffuseScale, jointSpecularScale, jointSpecularPow, jointOcclusionScale, jointOcclusionRange, jointOcclusionResolution, jointOcclusionColor, distJoints);
    
    // skeleton edges
    float distEdges = 1000.0;
    
    for(int eI=0; eI<edgeCount; ++eI)
    {
        if(edgePrimitives[eI] < 0) // do nothing
        {}
        else if(edgePrimitives[eI] == 0) // sphere
        {
            distEdges = poly_smin( distEdges, sphereSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z), edgeSmoothings[eI] );
        }
        else if(edgePrimitives[eI] == 1) // box
        {
            distEdges = poly_smin( distEdges, roundBoxSDF((edgeTransforms[eI] * samplePoint4D).xyz, vec3(edgeSizes[eI].x, edgeSizes[eI].y, edgeLengths[eI] * edgeSizes[eI].z), edgeRoundings[eI]), edgeSmoothings[eI] );
        }
        else if(edgePrimitives[eI] == 2) // capsule
        {
            distEdges = poly_smin( distEdges, roundCapsuleSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z, edgeSizes[eI].x, edgeRoundings[eI]), edgeSmoothings[eI] ); 
        }
        else if(edgePrimitives[eI] == 3) // cylinder
        {
            distEdges = poly_smin( distEdges, roundCylinderSDF((edgeTransforms[eI] * samplePoint4D).xyz, edgeLengths[eI] * edgeSizes[eI].z, edgeSizes[eI].x, edgeRoundings[eI]), edgeSmoothings[eI] ); 
        }
    }
    
    Surface edgeSurface = Surface(edgeColor, edgeAmbientScale, edgeDiffuseScale, edgeSpecularScale, edgeSpecularPow, edgeOcclusionScale, edgeOcclusionRange, edgeOcclusionResolution, edgeOcclusionColor, distEdges);

    // objects
    float distObjects = 1000.0;
    float maxDistObjects = 1000.0;
    Surface objectSurface = Surface(vec3(0.0, 0.0, 0.0), 0.0, 0.0, 0.0, 10.0, 0.0, 0.5, 0.5, vec3(0.0, 0.0, 0.0), 1000.0);
    
    for(int oI=0; oI<objectCount; ++oI)
    {    
        distObjects = 1000.0;
    
        if(objectPrimitives[oI] < 0) // do nothing
        {}
        else if(objectPrimitives[oI] == 0) // sphere
        {
            if(objectAmplitudes[oI] == 0) // non-rippling
            {
                distObjects = poly_smin( distObjects, sphereSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].x), objectSmoothings[oI] );
            }
            else
            {
                distObjects = poly_smin( distObjects, rippleSphereSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].x, objectFrequencies[oI], objectAmplitudes[oI], objectPhases[oI] ), objectSmoothings[oI] );
            }
        }
        else if(objectPrimitives[oI] == 1) // box
        {
            if(objectAmplitudes[oI] == 0) // non-rippling
            {
                distObjects = poly_smin( distObjects, roundBoxSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI], objectRoundings[oI]), objectSmoothings[oI] );
            }
            else
            {
                distObjects = poly_smin( distObjects, rippleBoxSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI], objectRoundings[oI], objectFrequencies[oI], objectAmplitudes[oI], objectPhases[oI]), objectSmoothings[oI] );
            }
        }
        else if(objectPrimitives[oI] == 2) // capsule
        {
            distObjects = poly_smin( distObjects, roundCapsuleSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].z, objectSizes[oI].x, objectRoundings[oI]), objectSmoothings[oI] ); 
        }
        else if(objectPrimitives[oI] == 3) // cylinder
        {
            if(objectAmplitudes[oI] == 0) // non-rippling
            {
                distObjects = poly_smin( distObjects, roundCylinderSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].z, objectSizes[oI].x, objectRoundings[oI]), objectSmoothings[oI] ); 
            }
            else
            {
                distObjects = poly_smin( distObjects, rippleCylinderSDF((objectTransforms[oI] * samplePoint4D).xyz, objectSizes[oI].z, objectSizes[oI].x, objectRoundings[oI], objectFrequencies[oI], objectAmplitudes[oI], objectPhases[oI]), objectSmoothings[oI] );
            }
        }
        
        Surface tmpSurface = Surface(objectColors[oI], objectAmbientScales[oI], objectDiffuseScales[oI], objectSpecularScales[oI], objectSpecularPows[oI], objectOcclusionScales[oI], objectOcclusionRanges[oI], objectOcclusionResolutions[oI], objectOcclusionColors[oI], distObjects);
        objectSurface = union_surface(tmpSurface, objectSurface, objectSmoothings[oI]);
        
        if(maxDistObjects > distObjects)
        {
            maxDistObjects = distObjects;
        }
    }


    // combined surface from skeleton egdes and joints
    Surface skelEdgeSurface = Surface(vec3(0.0, 0.0, 0.0), 0.0, 0.0, 0.0, 10.0, 0.0, 0.5, 0.5, vec3(0.0, 0.0, 0.0), 1000.0);
    
    if(distJoints < 1000.0 && distEdges < 1000.0)
    {
        skelEdgeSurface = union_surface(jointSurface, edgeSurface, jointEdgeSmoothing);
    }
    else if(distJoints < 1000.0)
    {
        skelEdgeSurface = jointSurface;
    }
    else if(distEdges < 1000.0)
    {
        skelEdgeSurface = edgeSurface;
    }
    
    Surface closestSurface;
    
    if(maxDistObjects < 1000.0)
    {
        closestSurface = union_surface(skelEdgeSurface, objectSurface, skelObjectSmoothing);
    }
    else
    {
        closestSurface = skelEdgeSurface;
    }

    return closestSurface;
}

float ambientOcclusion(vec3 surfacePos, vec3 surfaceNormal, float occlusionRange, float occlusionResolution)
{
    
    float minT = 0.01;
    float maxT = occlusionRange;
    int stepCount = 8;
    float tIncr = occlusionResolution;
    
    float occlusionFacor = 1.0;
    float dist;
    
    for(float t = minT; t < maxT; t += tIncr)
    {
        dist = sceneSDF( surfacePos + surfaceNormal * t );
        
        if(dist < t - EPSILON)
        {
            float normT = (t - minT) / (maxT - minT);
            occlusionFacor = occlusionFacor * normT + occlusionFacor * dist / t * (1.0 - normT);
        }
        
        if(occlusionFacor <= 0.0) break;
    }
    
    return occlusionFacor;
}

float doAoSSS(vec3 p, vec3 n, float steps, float delta)
{
    float a = 0.0;
    float weight = .5;
    for (float i = 1; i <= steps; i += 1) 
    {
        float d = (i / steps) * delta;
        a = a + weight * (d - sceneSDF(p + n * d));
        weight = weight * 0.6;
    }
    
    return clamp(1.0 - a, 0.0, 1.0);
}

/**
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the ey to march before giving up
 */
float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) 
{
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) 
    {
        float dist = sceneSDF(eye + depth * marchingDirection);
        if (dist < EPSILON) 
        {
			return depth;
        }
        depth += dist;
        if (depth >= end) 
        {
            return end;
        }
    }
    return end;
}

Surface shortestDistanceToSurface_surface(vec3 eye, vec3 marchingDirection, float start, float end) 
{
    float depth = start;
    Surface closestSurface;

    for (int i = 0; i < MAX_MARCHING_STEPS; i++) 
    {
        closestSurface = sceneSDF_surface(eye + depth * marchingDirection);

        if (closestSurface.signedDistance < EPSILON) 
        {
            closestSurface.signedDistance = depth;
            return closestSurface;
        }

        depth += closestSurface.signedDistance;

        if (depth >= end) 
        {
            closestSurface.signedDistance = end;
            closestSurface.color = bgColor;
            return closestSurface;
        }
    }
    
    closestSurface.color = bgColor;
    closestSurface.ambientScale = 1.0;
    closestSurface.diffuseScale = 0.0;
    closestSurface.specularScale = 0.0;
    closestSurface.specularPow = 1.0;
    closestSurface.occlusionScale = 0.0;
    closestSurface.occlusionRange = 1.0;
    closestSurface.occlusionResolution = 1.0;
    closestSurface.occlusionColor = bgOcclusionColor;
    closestSurface.signedDistance = end;
    
    return closestSurface;
}
            

/**
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 fragCoord) 
{
    float z = 1.0 / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(fragCoord, -z));
}

/**
 * Using the gradient of the SDF, estimate the normal on the surface at point p.
 */
vec3 estimateNormal(vec3 p) 
{
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

/**
 * Lighting contribution of a single point light source via Phong illumination.
 * 
 * The vec3 returned is the RGB color of the light's contribution.
 *
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 * lightPos: the position of the light
 * lightIntensity: color/intensity of the light
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongContribForLight(vec3 p, vec3 eye, vec3 lightPos, vec3 diffuseColor, float diffuseScale, vec3 specularColor, float specularScale, float specularPow) 
{
    vec3 N = estimateNormal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));
    
    float dotLN = dot(L, N);
    float dotRV = dot(R, V);
    
    if (dotLN < 0.0) {
        // Light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    } 
    
    if (dotRV < 0.0) {
        // Light reflection in opposite direction as viewer, apply only diffuse
        // component
        return diffuseScale * (diffuseColor * dotLN);
    }
    return diffuseScale * diffuseColor * dotLN + specularScale * specularColor * pow(dotRV, specularPow);
}


/**
 * Return a transform matrix that will transform a ray from view space
 * to world coordinates, given the eye point, the camera target, and an up vector.
 *
 * This assumes that the center of the camera is aligned with the negative z axis in
 * view space when calculating the ray marching direction. See rayDirection.
 */
mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) 
{
    // Based on gluLookAt man page
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}


void main()
{
    vec3 viewDir = rayDirection(camAngle, fragCoord);
    vec3 eye = camPosition;
    mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, -1.0));
    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
    
    Surface surface = shortestDistanceToSurface_surface(eye, worldDir, MIN_DIST, MAX_DIST);
    float dist = surface.signedDistance;
    
    if (dist > MAX_DIST - EPSILON) 
    {
        // Didn't hit anything
        fragColor = vec4(surface.color, 1.0);
        return;
    }

    // regular lighting    
    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = eye + dist * worldDir;
    
    vec3 color1 = surface.color * surface.ambientScale;
    color1 += phongContribForLight(p, eye, lightPosition, surface.color, surface.diffuseScale, surface.color, surface.specularScale, surface.specularPow );
    
    // ambient occlusion
    vec3 colorDiff = color1 - surface.occlusionColor;
 
    vec3 surfacePos = eye + dist * worldDir;
    vec3 surfaceNormal = estimateNormal(surfacePos);
    float occlusionStrength = ambientOcclusion(surfacePos, surfaceNormal, surface.occlusionRange, surface.occlusionResolution);
    //float occlusionStrength = doAoSSS(surfacePos, surfaceNormal, surface.occlusionRange, surface.occlusionResolution);
    
   	occlusionStrength = 1.0 - occlusionStrength;
   	occlusionStrength *= surface.occlusionScale;
   	
   	vec3 color2 = vec3(color1.r - occlusionStrength * colorDiff.r, color1.g - occlusionStrength * colorDiff.g , color1.b - occlusionStrength * colorDiff.b);
   	
    fragColor = vec4(color2, 1.0);

}