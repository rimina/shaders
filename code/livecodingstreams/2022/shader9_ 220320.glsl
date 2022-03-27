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

#define PI 3.14159265

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 500.0;
const int STEPS = 60;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

int M = 0;

struct Material{
  vec3 l;
  vec3 s;
  float sh;
};

vec3 glow = vec3(0.0);

Material getMaterial(int index){
  
  Material m;
  
  if(index == 0){//tulip petals
    m.l = vec3(0.8, 0.6, 0.5);
    m.s = vec3(1.0, 0.3, 0.5);
    m.sh = 40.0;
  }
  else if(index == 1){//stem
    m.l = vec3(0.2, 0.8, 0.5);
    m.s = vec3(0.5, 0.9, 0.7);
    m.sh = 25.0;
  }
  else if(index == 2){//center of the tulip
    m.l = vec3(0.8, 0.6, 0.7);
    m.s = vec3(0.9, 0.9, 0.9);
    m.sh = 10.0;
  }
  else{
    m.l = vec3(0.8, 0.5, 0.8);
    m.s = vec3(1.0, 0.0, 1.0);
    m.sh = 40.0;
  }
  
  return m;
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdEllipsoid( vec3 p, vec3 r ){
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0*(k0-1.0)/k1;
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdVerticalCapsule( vec3 p, float h, float r ){
  p.y -= clamp( p.y, 0.0, h );
  return length( p ) - r;
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float tulipBase(vec3 p){
  vec3 pp = p;
  
  float tulip = sdEllipsoid(pp, vec3(1.0, 1.5, 1.0));
  float inside = sdEllipsoid(pp-vec3(0.0, 0.25, 0.0), vec3(0.82, 1.7, 0.82));
  
  pp.xz = abs(pp.xz) - vec2(0.6, 0.6);
  pp.y -= 1.0;
  rot(pp.xy, PI*0.25);
  rot(pp.yz, PI*0.25);
  float cube = box(pp, vec3(0.5, 0.5, 0.5));
  
  tulip = max(tulip, -cube);
  tulip = max(tulip, -inside);
  
  return tulip;
}

float tulip(vec3 p){
  vec3 pp = p;
  float tulip = tulipBase(pp);
  rot(pp.xz, PI*0.25);
  pp *= 1.03;
  tulip = min(tulip, tulipBase(pp));
  
  pp.y += 0.75;
  float center = sphere(pp, 0.5);
  
  glow += vec3(0.4, 0.1, 0.5) *0.01 / (abs(center)+0.01);
  
  
  pp.y += 5.8;
  float varsi = sdVerticalCapsule(pp, 5.0, 0.25);
  
  
  M = 0;
  if(varsi < tulip && varsi < center){
    M = 1;
  }
  else if(center < varsi && center < tulip){
    M = 2;
  }
  
  tulip = min(tulip, center);
  tulip = min(tulip, varsi);
  return tulip;
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  rot(pp.xz, fft*0.5+time*0.1);

  for(int i = 0; i < 5; ++i){
    pp.xz = abs(pp.xz)-vec2(1., 1.);
    rot(pp.xz, PI/5.5);
    rot(pp.xy, -0.02); 
  }
  
  pp.xz = mod(pp.xz+4.0, vec2(8.0))-4.0;
  
  rot(pp.xy, sin(time)*0.01);
  rot(pp.yz, cos(time)*0.01);
  
  float tulppaani = tulip(pp);
  
  return tulppaani;
}

float march(vec3 ro, vec3 rd){
  vec3 p = ro;
  float t = E;
  
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

vec3 shade(vec3 rd, vec3 p, vec3 ld, Material m){
  vec3 n = normals(p);
  
  float l = max(dot(ld, n), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, m.sh);
  
  return m.s*l + m.l*s;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(10.0*sin(time*0.5), 10.0, 2.0*cos(time*0.5));
  vec3 rt = vec3(0.0, -10.0, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z)*vec3(q, 1.0/radians(120.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  vec3 ld = -rd;
  vec3 fogc = vec3(0.3, 0.5, 0.45);
  //vec3(uv.x*0.75, (sin(time*0.1+fft)+1.0)*0.15, uv.y*0.75);
  
  vec3 col = fogc;
  
  if(t < FAR){
    Material m = getMaterial(M);
    col = shade(rd, p, ld, m);
  }
  
  col += glow*0.75;
  
  float d = length(p-ro);
  float amount = 1.0-exp(-d*0.01);
  col = mix(col, fogc, amount);
  

	out_color = vec4(col, 1.0);
}