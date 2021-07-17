#version 410 core

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)

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
uniform sampler2D texOutline;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float time = fGlobalTime;

const float FAR = 50.0;
const float E = 0.01;
const int STEPS = 60;

float fft = texture(texFFTIntegrated, 0.5).r;

vec3 glow = vec3(0.0);

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec3 pp = p;
  
  rot(pp.xy, time*0.1);
  rot(pp.yz, time*0.3+fft);
  
  vec3 rs = vec3(FAR*2.0, 10.0, 20.0);
  pp = mod(pp+(rs*0.5), rs)-(rs*0.5);
  
  for(int i = 0; i < 4; ++i){
    pp = abs(pp)-vec3(8.0, 5.0, 6.0);
    rot(pp.xy, fft);
    rot(pp.yz, fft*0.5);
    rot(pp.xz, fft*0.25);
  }
  
  rot(pp.xy, time);
  
  float b = box(pp, vec3(FAR, 4.0, 0.2));
  float s = sphere(p-vec3(-1.5, 0.75, -8.0), 5.0);
  
  vec3 g = vec3(0.6, 0.7, 0.8) * 0.1 / (0.01+abs(b));
  g += vec3(0.8, 0.7, 0.8) * 0.5 / (0.05+abs(s));
  
  glow += g;
  
  b = max(b, 0.5+abs(b));
  return b;
}

float march(vec3 ro, vec3 rd){
  vec3 p = ro;
  float t = E;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d*0.9;
    p = ro + rd*t;
    
    if(d < E || t > FAR){
      break;
    }
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

/*vec3 shade(vec3 p, vec3 rd, vec3 ld){
  
}*/

void main(void)
{
  vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 3.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  vec3 col = vec3(0.0);
  col += glow;
  
  float dist = distance(ro, p);
  float fa = 1.0 - exp(-dist*0.08);
  col = mix(col, vec3(0.01, 0.05, 0.05), fa);
  
  vec3 frame = texture(texPreviousFrame, uv).rgb;
  col= mix(col, frame, 0.9);
  
  vec2 uuv = vec2(gl_FragCoord.x / v2Resolution.x, -gl_FragCoord.y / v2Resolution.y);
  vec3 logo = texture(texOutline, q).rgb;
  
  

  out_color = vec4(logo, 1.0);
}