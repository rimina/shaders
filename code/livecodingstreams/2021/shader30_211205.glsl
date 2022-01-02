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

#define HASHSCALE1 0.1031
#define PI 3.14159265359

float time = fGlobalTime;

const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 60;

const vec3 FOG_COLOR = vec3(0.25, 0.35, 0.45)*1.5;

int MATERIAL = 0;

//Random number [0:1] without sine
float hash(float p){
	vec3 p3  = fract(vec3(p) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
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

float fbm(vec3 p)
{
	float f;
    f  = 0.50000*noise( p ); p = p*2.01;
    f += 0.25000*noise( p ); p = p*2.02; //from iq
    f += 0.12500*noise( p ); p = p*2.03;
    f += 0.06250*noise( p ); p = p*2.04;
    f += 0.03125*noise( p );
	return f;
}

float trace(vec3 ro, vec3 rd){
  float t = 0.0;
  vec3 p = ro+rd;
  for(int i = 0; i < 5; ++i){
    float d = fbm(p+time*0.1);
    t += d;
    p += rd*d;
  }
  
  return t;
}

float plane(vec3 p, vec3 n, float dist){
  return dot(p, n) + dist;
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

// Similar to fOpUnionRound, but more lipschitz-y at acute angles
// (and less so at 90 degrees). Useful when fudging around too much
// by MediaMolecule, from Alex Evans' siggraph slides
float fOpUnionSoft(float a, float b, float r) {
	float e = max(r - abs(a - b), 0.0);
	return min(a, b) - e*e*0.25/r;
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  float n = noise(p+time*0.2);
  float ground = plane(p, vec3(0.0, 1.0, 0.0), 1.0) - n*0.45;
  
  float luminiekka = sphere(p, 2.0);
  luminiekka = fOpUnionSoft(luminiekka, sphere(p-vec3(0.0, 2.0, 0.0), 1.5), 0.5);
  luminiekka = fOpUnionSoft(luminiekka, sphere(p-vec3(0.0, 4.0, 0.0), 1.0), 0.25);
  
  pp.x = abs(p.x)-0.24;
  float eyes = sphere(pp-vec3(0.0, 4.0, 0.9), 0.1);
  
  if(eyes <= luminiekka && eyes < ground){
    MATERIAL = 1;
  }
  else{
    MATERIAL = 0;
  }
  
  luminiekka = min(luminiekka, eyes);
  
  return fOpUnionSoft(ground, luminiekka, 0.75);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd*t;
    
    if(t > FAR || d < E){
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


//Ambient occlusion method from https://www.shadertoy.com/view/4sdGWN

vec3 randomSphereDir(vec2 rnd){
	float s = rnd.x*PI*2.;
	float t = rnd.y*2.-1.;
	return vec3(sin(s), cos(s), t) / sqrt(1.0 + t * t);
}
vec3 randomHemisphereDir(vec3 dir, float i){
	vec3 v = randomSphereDir( vec2(hash(i+1.), hash(i+2.)) );
	return v * sign(dot(v, dir));
}

float ambientOcclusion( in vec3 p, in vec3 n, in float maxDist, in float falloff ){
	const int nbIte = 32;
    const float nbIteInv = 1.0/float(nbIte);
    const float rad = 1.0-1.0*nbIteInv; //Hemispherical factor (self occlusion correction)
    
	float ao = 0.0;
    
    for( int i=0; i<nbIte; i++ )
    {
        float l = hash(float(i))*maxDist;
        vec3 rd = normalize(n+randomHemisphereDir(n, l )*rad)*l; // mix direction with the normal
        													    // for self occlusion problems!
        ao += (l - max(scene( p + rd ),0.)) / maxDist * falloff;
    }
	
    return clamp( 1.-ao*nbIteInv, 0., 1.);
}


float subsurfaceScattering(vec3 p, vec3 rd, vec3 n){
  vec3 d = refract(rd, n, 1.31);
  vec3 pp = p;
  float thick = 0.0;
  const float max_scatter = 2.5;
  for(float i = 0.1; i < max_scatter; i += 0.2){
    pp += i*d;
    float t = scene(pp);
    thick += t;
  }
  thick = max(0.0, -thick);
  const float scatter_strength = 16.0;
  
  return scatter_strength*pow(max_scatter*0.5, 3.0)/thick;
}



vec3 colorify(vec3 p, vec3 ld, vec3 lc, vec3 rd){
  vec3 lcol = vec3(0.65, 0.65, 0.7);
  vec3 scol = vec3(0.5, 0.6, 0.8);
  float l_intensity = 0.9;
  float s_intensity = 0.1;
  float ao1_intensity = 0.5;
  float ao2_intensity = 0.8;
  
    if(MATERIAL == 1){
      lcol = vec3(0.0);
      scol = vec3(0.02);
      l_intensity = 0.8;
      s_intensity = 0.2;
      
      ao1_intensity = 0.01;
      ao2_intensity = 0.02;
    }
  
  
  vec3 n = normals(p);
  float lambertian = max(dot(n, ld), 0.0);
  
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float spec = pow(a, 80.0);
  
  float ao = ambientOcclusion(p, n, 4.0, 1.0);
  float ao2 = ambientOcclusion(p, ld, 1.0, 3.);
  float sss = max(0.0, subsurfaceScattering(p, rd, n));
  
  lambertian = mix(lambertian, smoothstep(0.0, 0.5, pow(sss, 0.6)), 1.31);
  
  return lcol*lambertian*l_intensity + scol*spec*s_intensity + lc*ao*ao1_intensity + lc*ao2*ao2_intensity;
}


vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld, vec3 lc){
  float dist = length(p-ro);
	float sunAmount = max( dot( rd, ld ), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.15);
	vec3  fogColor = mix(FOG_COLOR, lc, pow(sunAmount, 12.0));
  return mix(col, fogColor, fogAmount);
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 2.0, 7.0);
  vec3 rt = vec3(0.0, 1.0, -10.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z)*vec3(q, 1.0/radians(60.0)));
  
  vec3 lp = vec3(-20.0, -20.0, 30.0);
  
  vec3 ld = normalize(ro-lp);
  vec3 lc = vec3(0.8, 0.7, 0.5);
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  float volume = trace(ro, rd);
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = colorify(p, ld, lc, rd);
  }
  
  col = fog(col, p, ro, rd, ld, lc);
  col = col*0.6+(volume*vec3(0.6, 0.65, 0.7)*0.25);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.6);
  
	out_color = vec4(col, 1.0);
}