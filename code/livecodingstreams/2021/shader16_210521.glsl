// Copyright 2021-2022 rimina.
// All rights to the likeness of the visuals reserved.

// Any individual parts of the code that produces the visuals is
// available in the public domain or licensed under the MIT license,
// whichever suits you best under your local legislation.

// This is to say: you can NOT use the code as a whole or the visual
// output it produces for any purposes without an explicit permission,
// nor can you remix or adapt the work itself without a permission.*
// You absolutely CANNOT mint any NFTs based on the Work or part of it.
// You CAN however use any individual algorithms or parts of the Code
// for any purpose, commercial or otherwise, without attribution.

// *(In practice, for most reasonable requests, I will gladly grant
//   any wishes to remix or adapt this work :)).

#version 410 core

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)
uniform float fFrameTime; // duration of the last frame, in seconds

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texPreviousFrame; // screenshot of the previous frame
uniform sampler2D texChecker;
uniform sampler2D texNoise;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;
uniform sampler2D texTexBee;
uniform sampler2D texTexOni;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

const float PIXELR = (0.5/1280.0);
const float E = 0.001;
const float FAR = 60.0;
const int STEPS = 64;

const vec3 FOG_COLOR = vec3(0.08, 0.08, 0.085);
const vec3 LIGHT_COLOR = vec3(0.8, 0.5, 0.8);

float time = fGlobalTime;

const float PI  = 3.14159265;
const float PHI = (sqrt(5)*0.5 + 0.5);

vec3 glow = vec3(0.0);

struct Material{
  vec3 l_col;
  vec3 s_col;
  float l_i;
  float s_i;
  float shiny;
};

Material getMaterial(){
  Material m;
  m.l_col = vec3(0.3, 0.5, 0.9);
  m.s_col = vec3(0.5, 0.8, 1.0);
  m.l_i = 0.6;
  m.s_i = 0.4;
  m.shiny = 8.0;
  
  return m;
}

Material getSkin(){
  Material m;
  m.l_col = vec3(0.8, 0.7, 0.4);
  m.s_col = vec3(0.8, 0.7, 0.4);
  m.l_i = 0.9;
  m.s_i = 0.1;
  m.shiny = 1.0;
  
  return m;
}

Material getHair(){
  Material m;
  m.l_col = vec3(0.2, 0.7, 0.8);
  m.s_col = vec3(0.4, 0.8, 0.9);
  m.l_i = 0.3;
  m.s_i = 0.7;
  m.shiny = 30.0;
  
  return m;
}

Material getEye(){
  Material m;
  m.l_col = vec3(0.1, 0.2, 0.1);
  m.s_col = vec3(0.2, 0.5, 0.3);
  m.l_i = 0.2;
  m.s_i = 0.8;
  m.shiny = 10.0;
  
  return m;
}

Material getLips(){
  Material m;
  m.l_col = vec3(3.0, 0.1, 0.6);
  m.s_col = vec3(8.0, 0.2, 0.8);
  m.l_i = 0.2;
  m.s_i = 0.7;
  m.shiny = 20.0;
  
  return m;
}

Material MATERIAL;

//SOME FUNCTIONS FROM HG_SDF

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0)?-1:1;
}

float vmax(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

float fSphere(vec3 p, float r) {
	return length(p) - r;
}

// Plane with normal n (n is normalized) at some distance from the origin
float fPlane(vec3 p, vec3 n, float distanceFromOrigin) {
	return dot(p, n) + distanceFromOrigin;
}

// Box: correct distance to corners
float fBox(vec3 p, vec3 b) {
	vec3 d = abs(p) - b;
	return length(max(d, vec3(0))) + vmax(min(d, vec3(0)));
}

// Cylinder standing upright on the xz plane
float fCylinder(vec3 p, float r, float height) {
	float d = length(p.xz) - r;
	d = max(d, abs(p.y) - height);
	return d;
}

// Capsule: A Cylinder with round caps on both sides
float fCapsule(vec3 p, float r, float c) {
	return mix(length(p.xz) - r, length(vec3(p.x, abs(p.y) - c, p.z)) - r, step(c, abs(p.y)));
}

// Cone with correct distances to tip and base circle. Y is up, 0 is in the middle of the base.
float fCone(vec3 p, float radius, float height) {
	vec2 q = vec2(length(p.xz), p.y);
	vec2 tip = q - vec2(0, height);
	vec2 mantleDir = normalize(vec2(height, radius));
	float mantle = dot(tip, mantleDir);
	float d = max(mantle, -q.y);
	float projected = dot(tip, vec2(mantleDir.y, -mantleDir.x));
	
	// distance to tip
	if ((q.y > height) && (projected < 0)) {
		d = max(d, length(tip));
	}
	
	// distance to base ring
	if ((q.x > radius) && (projected > length(vec2(height, radius)))) {
		d = max(d, length(q - vec2(radius, 0)));
	}
	return d;
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
//https://www.shadertoy.com/view/tdS3DG
float fEllipsoid( vec3 p, vec3 r ){
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0*(k0-1.0)/k1;
}

// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
void pR(inout vec2 p, float a){
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opSmoothUnion( float d1, float d2, float k ){
  float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
  return mix( d2, d1, h ) - k*h*(1.0-h);
}

float opSmoothSubtraction( float d1, float d2, float k ){
  float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
  return mix( d2, -d1, h ) + k*h*(1.0-h);
}

// 3D noise function (IQ)
float noise(vec3 p){
	vec3 ip = floor(p);
    p -= ip;
    vec3 s = vec3(7.0,157.0,113.0);
    vec4 h = vec4(0.0, s.yz, s.y+s.z)+dot(ip, s);
    p = p*p*(3.0-2.0*p);
    h = mix(fract(sin(h)*43758.5), fract(sin(h+s.x)*43758.5), p.x);
    h.xy = mix(h.xz, h.yw, p.y);
    return mix(h.x, h.y, p.z);
}

//SCENE STARTS


float scene(vec3 p){
  MATERIAL = getMaterial();
  
  vec3 pp = p;
  
  float n = noise(p*(sqrt(5.0)*0.5 + 0.5)*2.5+time*0.25)*0.15;
  
  //HEAD & HAIR
  vec3 head_offset = vec3(0.0, 1.0, 0.0);
  float head = fSphere(pp-head_offset, 0.45);
  
  pp -= vec3(0.0, 1.1, -0.3);
  pR(pp.yz, PI*0.25);
  float hair = fEllipsoid(pp, vec3(0.63, 0.74, 0.4));
  pp -= vec3(0.0, 0.5, 0.1);
  pR(pp.yz, -PI*0.1);
  hair = opSmoothUnion(hair, fEllipsoid(pp-vec3(0.0, 0.0, 0.1), vec3(0.53, 0.2, 0.2)), 0.25);
  hair -= n;
  pp = p;
  
  //FACE
  //EYES
  pp -= vec3(0.0, 0.95, 0.45);
  pp.x = abs(pp.x)-0.15;
  float socket = fEllipsoid(pp, vec3(0.05, 0.03, 0.05));
  float eye = fEllipsoid(pp-vec3(0.0, 0.0, -0.08), vec3(0.05, 0.015, 0.05));
  head = opSmoothSubtraction(socket, head, 0.09);
  pp = p;
  
  //NOSE
  pp -= head_offset;
  float nose = fEllipsoid(pp-vec3(0.0, -0.18, 0.4), vec3(0.03, 0.035, 0.02));
  head = opSmoothUnion(nose, head, 0.1);
  pp = p;
  
  //LIPS
  pp -= head_offset;
  pp.x = abs(pp.x)-0.02;
  float lips = fEllipsoid(pp-vec3(0.0, -0.27, 0.33), vec3(0.08, 0.06, 0.02));
  pp = p;
  
  //NECK
  float neck = fCapsule(pp, 0.15, 1.0);
  head = opSmoothUnion(neck, head, 0.05);
  
  
  //TORSO
  vec3 torso_offset = vec3(0.0, -0.2, 0.0);
  float torso = fEllipsoid(pp-torso_offset, vec3(0.65, 0.7, 0.5));
  torso_offset = vec3(0.0, -1.4, 0.0);
  torso = opSmoothUnion(torso, fEllipsoid(pp-torso_offset, vec3(0.75, 1.25, 0.66)), 0.05);
  
  //SKIRT
  n = noise(p*3.0 + time*0.5)*0.1;
  vec3 skirt_offset = vec3(0.0, -2.5, 0.0);
  float skirt = fCone(pp-skirt_offset, 1.2, 2.9);
  skirt -=n;
  
  //SHOULDERS
  pR(pp.xy, PI*0.5);
  vec3 shoulder_offset = vec3(0.2, 0.0, 0.0);
  float shoulders = fCapsule(pp-shoulder_offset, 0.25, 0.54);
  
  pp.y = abs(pp.y)-1.0;
  pR(pp.xy, PI*0.2);
  
  //ARMS
  float arms = fCapsule(pp-vec3(0.01, 0.0, 0.0), 0.19, 0.3);
  pR(pp.xy, -PI*0.5);
  pR(pp.yz, -PI*0.2);
  float hands = fCapsule(pp-vec3(-0.4, -0.5, 0.0), 0.16, 0.4);
  arms = opSmoothUnion(arms, hands, 0.12);
  
  
  //MATERIALS
  if((head < torso && head < skirt && head < shoulders && head < arms && head < hair && head < eye && head < lips) ||
    (arms < head && arms < skirt && arms < shoulders && arms < torso && arms < hair && arms < eye && arms < lips)){
    MATERIAL = getSkin();
  }
  else if(hair < head && hair < torso && hair < skirt && hair < shoulders && hair < arms && hair < eye && hair < lips){
    MATERIAL = getHair();
  }
  else if(eye < head && eye < hair && eye < torso && eye < skirt && eye < shoulders && eye < arms && eye < lips){
    MATERIAL = getEye();
  }
  else if(lips < head && lips < hair && lips < eye && lips < torso && lips < skirt && lips < shoulders && lips < arms){
    MATERIAL = getLips();
  }
  
  glow += vec3(0.2, 0.8, 0.8) * 0.02 / (0.05 + abs(hair));
  
  head = min(head, hair);
  head = opSmoothUnion(head, eye, 0.02);
  head = opSmoothUnion(lips, head, 0.01);
  
  torso = opSmoothUnion(torso, head, 0.01);
  torso = opSmoothUnion(torso, skirt, 0.25);
  torso = opSmoothUnion(torso, shoulders, 0.2);
  torso = opSmoothUnion(torso, arms, 0.14);
  
  
  
  
  return torso;
}

//SCENE ENDS


//Enhanced sphere tracing algorithm introduced by Mercury
float march(vec3 ro, vec3 rd){
  float t = E;
  float d = 0.0;

  float omega = 1.0;//muista testata eri arvoilla! [1,2]
  float prev_radius = 0.0;

  float candidate_t = t;
  float candidate_error = 1000.0;
  float sg = sgn(scene(ro));

  vec3 p = ro;

	for(int i = 0; i < STEPS; ++i){
		float sg_radius = sg*scene(p);
		float radius = abs(sg_radius);
		d = sg_radius;
		bool fail = omega > 1. && (radius+prev_radius) < d;
		if(fail){
			d -= omega * d;
			omega = 1.;
		}
		else{
			d = sg_radius*omega;
		}
		prev_radius = radius;
		float error = radius/t;

		if(!fail && error < candidate_error){
			candidate_t = t;
			candidate_error = error;
		}

		if(!fail && error < PIXELR || t > FAR){
			break;
		}
		t += d;
    p = rd*t+ro;
	}
  //discontinuity reduction
  float er = candidate_error;
  for(int j = 0; j < 6; ++j){
    float radius = abs(sg*scene(p));
    p += rd*(radius-er);
    t = length(p-ro);
    er = radius/t;

    if(er < candidate_error){
      candidate_t = t;
      candidate_error = er;
    }
  }
	if(t <= FAR || candidate_error <= PIXELR){
		t = candidate_t;
	}
	return t;
}

vec3 normals(vec3 p){
  vec3 eps = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p+eps.xyy) - scene(p-eps.xyy),
    scene(p+eps.yxy) - scene(p-eps.yxy),
    scene(p+eps.yyx) - scene(p-eps.yyx)
  ));
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.07);
	vec3  fogColor = mix(FOG_COLOR, LIGHT_COLOR, pow(sunAmount, 8.0));
  return mix(col, fogColor, fogAmount);
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 n = normals(p);
  
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float s = pow(a, MATERIAL.shiny);
  
  return l*MATERIAL.l_col*MATERIAL.l_i+s*MATERIAL.s_col*MATERIAL.s_i;
  
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  //vec3 ro = vec3(3.0*cos(time*0.25), 0.5, 3.0*sin(time*0.25));
  //vec3 rt = vec3(0.0, -0.5, 0.0);
  vec3 ro = vec3(0.0, 0.0, 5.0);
  vec3 rt = vec3(0.0, -1.0, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  
  vec3 col = FOG_COLOR;
  float t = march(ro, rd);
  vec3 p = rd*t+ro;
  
  if(t <= FAR){
    col += shade(p, rd, -z);
  }
  
  col += glow*0.2;
  
  col = fog(col, p, ro, rd, -z);
  
	out_color = vec4(col,1.0);
}