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

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 50.0;
const int STEPS = 40;
const int SSTEPS = 30;
const float PIXELR = 0.5/1280.0;

const vec3 LC = vec3(0.5, 0.5, 0.8);
const vec3 LC2 = vec3(0.5, 0.7, 0.8);
const vec3 FOGC = vec3(0.15, 0.35, 0.4);

#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5)*0.5 + 0.5)

// Clamp to [0,1] - this operation is free under certain circumstances.
// For further information see
// http://www.humus.name/Articles/Persson_LowLevelThinking.pdf and
// http://www.humus.name/Articles/Persson_LowlevelShaderOptimization.pdf
#define saturate(x) clamp(x, 0, 1)

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0)?-1:1;
}


struct Material{
  bool reflective;
  bool refractive;
  vec3 lambertian;
  vec3 specular;
  float s_intensity;
  float l_intensity;
  float shininess;
  float reflectivity;
  float refractivity;
};

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d){
  return a + b*cos(6.28318*(c*t+d));
}

Material getWallMaterial(vec2 index){
  Material mat;
  
  vec3 col = palette(length(index)*1.75,
                       vec3(0.2, 0.1, 0.25),
                       vec3(0.5, 0.5, 0.5),
                       vec3(1., 1., 0.),
                       vec3(0.25, 0.5, 0.8));
  
  mat.reflective = false;
  mat.refractive = false;
  mat.lambertian = col;
  mat.specular = col*1.2;
  
  mat.s_intensity = 0.5;
  mat.l_intensity = 0.8;
  mat.shininess = 10.0;
  
  return mat;
}

Material getRoofMaterial(vec2 index){
  Material mat;
  
  vec3 col = palette(length(index)*1.85,
                       vec3(0.2, 0.1, 0.25),
                       vec3(0.5, 0.5, 0.5),
                       vec3(1., 1., 0.),
                       vec3(0.25, 0.5, 0.8));
  
  mat.reflective = false;
  mat.refractive = false;
  mat.lambertian = col;
  mat.specular = col*1.8;
  
  mat.s_intensity = 0.5;
  mat.l_intensity = 0.8;
  mat.shininess = 3.0;
  
  return mat;
}

Material getBaseMaterial(vec3 p){
  Material mat;
  
  mat.reflective = true;
  mat.refractive = false;
  
  vec3 color = vec3(0.1);
  
  vec2 m = mod(p.xz, 2.0)-vec2(0.5, 1.5);
  if(m.x*m.y > 0.0){
    color = vec3(0.5);
  }
  
  m = mod(p.xz, 4.0)-vec2(1.0, 2.0);
  if(m.x*m.y > 0.0){
    color += vec3(0.2, 0.5, 0.9);
  }
  
  
  mat.lambertian = color;//vec3(0.0, 0.3, 0.5);
  mat.specular = color*1.2;//vec3(0.0, 0.5, 1.0);
  
  mat.s_intensity = 0.5;
  mat.l_intensity = 0.8;
  mat.shininess = 4.0;
  
  mat.reflectivity = 0.5;
  mat.refractivity = 0.0;
  
  return mat;
}

Material getGroundMaterial(vec3 p){
  Material mat;
  
  mat.reflective = false;
  mat.refractive = false;
  
  vec3 color = vec3(0.5);
  
  
  mat.lambertian = color;//vec3(0.0, 0.3, 0.5);
  mat.specular = color*1.2;//vec3(0.0, 0.5, 1.0);
  
  mat.s_intensity = 0.3;
  mat.l_intensity = 0.8;
  mat.shininess = 5.0;
  
  mat.reflectivity = 0.5;
  mat.refractivity = 0.0;
  
  return mat;
}

float vmax(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

float vmax2(vec2 v) {
	return max(v.x, v.y);
}


void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// Shortcut for 45-degrees rotation
void pR45(inout vec2 p) {
	p = (p + vec2(p.y, -p.x))*sqrt(0.5);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float plane(vec3 p, vec3 n, float d){
  return dot(p, n) + d;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
  return length(max(d, vec3(0.0))) + vmax(min(d, vec3(0.0)));
}

// Cheap Box: distance to corners is overestimated
float fBoxCheap(vec3 p, vec3 b) { //cheap box
	return vmax(abs(p) - b);
}

// Repeat space along one axis. Use like this to repeat along the x axis:
// <float cell = pMod1(p.x,5);> - using the return value is optional.
float pMod1(inout float p, float size) {
	float halfsize = size*0.5;
	float c = floor((p + halfsize)/size);
	p = mod(p + halfsize, size) - halfsize;
	return c;
}

// Repeat in two dimensions
vec2 pMod2(inout vec2 p, vec2 size) {
	vec2 c = floor((p + size*0.5)/size);
	p = mod(p + size*0.5,size) - size*0.5;
	return c;
}

// Same, but mirror every second cell so all boundaries match
vec2 pModMirror2(inout vec2 p, vec2 size) {
	vec2 halfsize = size*0.5;
	vec2 c = floor((p + halfsize)/size);
	p = mod(p + halfsize, size) - halfsize;
	p *= mod(c,vec2(2))*2 - vec2(1);
	return c;
}


// Same, but mirror every second cell at the diagonal as well
vec2 pModGrid2(inout vec2 p, vec2 size) {
	vec2 c = floor((p + size*0.5)/size);
	p = mod(p + size*0.5, size) - size*0.5;
	p *= mod(c,vec2(2))*2 - vec2(1);
	p -= size/2;
	if (p.x > p.y) p.xy = p.yx;
	return floor(c/2);
}

// Mirror at an axis-aligned plane which is at a specified distance <dist> from the origin.
float pMirror (inout float p, float dist) {
	float s = sgn(p);
	p = abs(p)-dist;
	return s;
}

// Mirror in both dimensions and at the diagonal, yielding one eighth of the space.
// translate by dist before mirroring.
vec2 pMirrorOctant(inout vec2 p, vec2 dist) {
  vec2 s = sign(p);
	pMirror(p.x, dist.x);
	pMirror(p.y, dist.y);
	if (p.y > p.x)
		p.xy = p.yx;
	return s;
}

// The "Stairs" flavour produces n-1 steps of a staircase:
float fOpUnionStairs(float a, float b, float r, float n) {
	float d = min(a, b);
	vec2 p = vec2(a, b);
	pR45(p);
	p = p.yx - vec2((r-r/n)*0.5*sqrt(2.0));
	p.x += 0.5*sqrt(2.0)*r/n;
	float x = r*sqrt(2.0)/n;
	pMod1(p.x, x);
	d = min(d, p.y);
	pR45(p);
	return min(d, vmax2(p-vec2(0.5*r/n)));
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

float scene(vec3 p, out Material mat){
  
  vec3 pp = p;
  //maa is ground in Finnish
  float maa = plane(p, vec3(0.0, 1.0, 0.0), 1.0)-(sin(noise(p)*0.5)+sin(length(p)*0.25))*0.5;
  
  vec2 ido = pMirrorOctant(pp.xz, vec2(10.0, 12.0));
  vec2 ids = pMod2(pp.xz, vec2(10.0, 14.5));
  
  float idx = pMirror(pp.x, 1.0);
  float idz = pMirror(pp.z, 3.0);
  
  float height = 2.0+sin(length(ids));
  
  //laatikko is box in Finnish
  float laatikko = box(pp-vec3(1.0, 1.5, 1.0), vec3(0.5, 3.0+height, 1.0));
  float pohja = box(pp, vec3(2.2, 0.2, 3.5));
  
  pp -= vec3(0.1, 4.5+height, 0.0);
  rot(pp.xy, radians(60.));
  float katto = box(pp, vec3(0.1, 2.5, 3.0));
  
  float guard = -fBoxCheap(pp, vec3(6.0, 5.0, 10.0)*0.5);
  guard = abs(guard) + 5.0*0.1;
  
  if(pohja <= laatikko && pohja <= maa && pohja <= katto){
    mat = getBaseMaterial(pp);
  }
  else if(maa <= pohja && maa <= laatikko && maa <= katto){
    mat = getGroundMaterial(p);
  }
  else if(katto <= pohja && katto <= laatikko && katto <= maa){
    mat = getRoofMaterial(vec2(idx, idz));
  }
  else{
    mat = getWallMaterial(ids);
  }
  
  laatikko = fOpUnionStairs(laatikko, pohja, 0.5, 4.0);
  laatikko = fOpUnionStairs(laatikko, katto, 0.5, 8.0);
  //maa = fOpUnionStairs(maa, pohja, 1.2, 8.0);
  
  return min(min(guard, laatikko), maa);
}

bool march(vec3 ro, vec3 rd, out vec3 p, in bool inside, inout Material mat){
  p = ro;
  float t = E;
  float dir = inside ? -1.0 : 1.0;
  bool hit = false;
  
  for(int i = 0; i < SSTEPS; ++i){
    p = ro + rd*t;
    float d = dir*scene(p, mat);
    t += d;
    
    if(abs(d) < E || t > FAR){
      if(abs(d) < E){
        hit = true;
      }
      break;
    }
    
  }
  
  return hit;
}

float marchP(vec3 ro, vec3 rd, out Material mat){
  float t = 0.001;//EPSILON;
  float step = 0.0;

  float omega = 1.0;//muista testata eri arvoilla! [1,2]
  float prev_radius = 0.0;

  float candidate_t = t;
  float candidate_error = 1000.0;
  float sg = sgn(scene(ro, mat));

  vec3 p = vec3(0.0);

	for(int i = 0; i < 64; ++i){
		p = rd*t+ro;
		float sg_radius = sg*scene(p, mat);
		float radius = abs(sg_radius);
		step = sg_radius;
		bool fail = omega > 1. && (radius+prev_radius) < step;
		if(fail){
			step -= omega * step;
			omega = 1.;
		}
		else{
			step = sg_radius*omega;
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
		t += step;
	}
    //discontinuity reduction
    float er = candidate_error;
    for(int j = 0; j < 6; ++j){
        float radius = abs(sg*scene(p, mat));
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

//Ambien occlusion & shadow coeffience function modified from las's (Mercury)
//and dechipher's (YUP) methods
//PRAMETERS:
//  p = position,
//  n = normals (ao) or unit vector of light direction (shadow)
//  k = constant
float ambientOcclusion(vec3 p, vec3 n, float k){
    float s = sgn(k);
    float ro = s*.5+.5;
    Material mat;
    for(float i = 0.0; i < 6.0; ++i){
        ro -= (i*k - scene(p+n*i*k*s, mat))/exp2(i);
    }
    return max(min(ro, 1.), 0.);
}

vec3 normals(vec3 p){
  vec3 eps = vec3(E, 0.0, 0.0);
  Material mat;
  return normalize(vec3(
    scene(p+eps.xyy, mat) - scene(p-eps.xyy, mat),
    scene(p+eps.yxy, mat) - scene(p-eps.yxy, mat),
    scene(p+eps.yyx, mat) - scene(p-eps.yyx, mat)
  ));
}

vec3 shade(vec3 p, vec3 dir, vec3 ld, vec3 lp, Material mat){
  vec3 n = normals(p);
  float lamb = max(dot(n, ld), 0.0);
  vec3 angle = reflect(n, ld);
  float spec = pow(max(dot(dir, angle), 0.0), mat.shininess);
  float shadow = ambientOcclusion(p, ld, 0.6);
  float ao = ambientOcclusion(p, n, 0.5);
  
  return (lamb*mat.lambertian*mat.l_intensity + spec*mat.specular*0.5)*shadow*ao;
  
}

vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld, vec3 lc){
  float d = length(p-ro);
  float sa = max(dot(rd, -ld), 0.0);
  float fa = 1.0-exp(-d*0.05);
  vec3 fc = mix(FOGC, lc, pow(sa, 6.0));
  return mix(col, fc, fa);
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;

  //vec3 ro = vec3(10.0*sin(time*0.25), 14.0, 10.0*cos(time*0.25));
  //vec3 rt = vec3(0.0, 4.0, 0.0);
  vec3 ro = vec3(-3.0, 3.0, time*2.0);
  vec3 rt = vec3(2.0, 4.0, 5.0+ro.z);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(50.0)));
  
  Material mat;
  float t = marchP(ro, rd, mat);
  vec3 p = ro+rd*t;
  
  
  vec3 col = vec3(0.0);
  
  vec3 lp = rt - vec3(0.0, 80.0, 0.0);
  vec3 lt = ro - vec3(0.0, 0.0, 80.0);
  vec3 ld = normalize(lt-lp);
  
  vec3 lp2 = rt - vec3(0.0, 1.4, 4.5);
  vec3 lt2 = ro - vec3(0.0, 0.1, 0.1);
  vec3 ld2 = normalize(lt2 - lp2);
 
  bool hit = false;
  if(t < FAR){
    col = shade(p, rd, ld, lp, mat)+LC*0.25;
    col += shade(p, rd, ld2, lp2, mat)+LC2*0.25;
    col *=0.5;
    
    if(mat.reflective){
      vec3 n = normals(p);
      vec3 refd = reflect(rd, n);
      vec3 pr = p;
      Material refmat;
      hit = march(p+n+E*2.0, refd, pr, false, refmat);
      if(hit){
        vec3 cc = shade(pr, refd, -ld, lp, refmat)+LC*0.25;
        cc += shade(pr, refd, -ld2, lp2, refmat)+LC2*0.25;
        cc *= 0.5;
        
        col += cc;
        col *= 0.5;
      }
    }
    
  }
  col = fog(col, p, ro, rd, ld, LC);
  col = fog(col, p, ro, rd, ld2, LC2);
 
	
	out_color = vec4(col, 1.0);
}