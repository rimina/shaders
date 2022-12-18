// Copyright 2020-2022 rimina.
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

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 120;

int M = 0;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

//FROM HG_SDF http://mercury.sexy/hg_sdf
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

//From https://iquilezles.org/articles/distfunctions/
float sdTriPrism( vec3 p, vec2 h)
{
  vec3 q = abs(p);
  return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float sbruce(vec3 p, float h, float w){
  
  vec3 pp = p;
  
  float top = fCone(pp-vec3(0.0, h/4., 0.0), 0.4*w, h/6.);
  float middle = fCone(pp, 0.75*w, h/3.);
  float bottom = fCone(pp-vec3(0.0, -h/4.0, 0.0), w, h/2.);
  
  return min(top, min(middle, bottom));
}

float star(vec3 p, float size){
  vec3 pp = p;
  float star = sdTriPrism(pp, vec2(size, 0.02));
  rot(pp.xy, radians(180.0));
  star = min(star, sdTriPrism(pp, vec2(size, 0.02)));
  return star;
}

float scene(vec3 p){
  vec3 pp = p;
  
  float tree = sbruce(pp-vec3(0., 2.5/4.0, 0.0), 2.5, 0.7);
  
  pp.xz = abs(pp.xz)-vec2(1.2, 0.5);
  rot(pp.xz, 0.628);
  pp.xz = abs(pp.xz)-vec2(2.1, 1.0);
  pp.xz = mod(pp.xz+vec2(2.0, 1.5), vec2(4.0, 3.0))-vec2(2.0, 1.5);
  
  tree = min(tree, sbruce(pp-vec3(0.0, 1.5/4.0, 0.0), 1.5, 0.4));
  
  
  pp = p;
  pp -= vec3(0.0, 1.75, 0.0);
  float top = star(pp, 0.15);
  
  if(tree < top){
    M = 0;
  }
  else{
    M = 1;
  }
  
  return min(tree, top);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd * t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 n = normals(p);
  float l = max(dot(n, ld), 0.0);
  
  vec3 col = M == 0 ? vec3(1., 1.5, 1.25)*0.33 : vec3(0.9, 0.8, 0.0);
  
  return l * col;
}

//From https://iquilezles.org/articles/fog/
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld, vec3 lc, vec3 fcol){
  float dist = length(p-ro);
	float sunAmount = max( dot( rd, ld ), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.04);
	vec3  fogColor = mix(fcol, lc, pow(sunAmount, 8.0));
  return mix(col, fogColor, fogAmount);
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = uv-0.5;
	q /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec3 ro = vec3(5.0*cos(time*0.2), 2.5, 5.0*sin(time*0.2));
  vec3 rt = vec3(0.0, 1.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(60.0)));
  
  vec3 fcol = vec3(0.7, 0.8, 0.9);
  vec3 col = vec3(fcol);
  
  
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  vec3 ld = normalize(vec3(0., 2.5, -4.5));
  if(t < FAR){
    col = shade(p, rd, ld);
  }
  col = fog(col, p, ro, rd, ld, vec3(0.8, 0.8, 0.75), fcol);
  

	out_color = vec4(col, 1.0);
}