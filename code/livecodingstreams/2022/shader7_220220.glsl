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

const float FAR = 80.0;
const float E = 0.001;
const int STEPS = 80;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, vec3(0.0))) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec3 pp = p;
  
  for(int i = 0; i < 4; ++i){
    pp = abs(pp)-vec3(0.15);
    rot(pp.xy, time*0.5);
    rot(pp.yz, time*0.5);
  }
  rot(pp.xy, time*0.5+fft*5.0);
  rot(pp.xz, time);
  rot(pp.yz, time*0.25+fft);
  
  float b1 = box(pp, vec3(.5));
  
  pp = p;
  for(int i = 0; i < 3; ++i){
    pp = abs(pp)-vec3(0.5, 0.75, 0.5);
    rot(pp.xy, fft*8.0);
    rot(pp.xz, -time);
  }
  rot(pp.xy, -time*0.5+fft*5.0);
  rot(pp.xz, -time);
  rot(pp.yz, -time*0.25+fft);
  
  float b2 = box(pp, vec3(.35, 0.45, 0.8));
  
  return max(b1, -b2);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd * t;
    
    if(d <= E || t >= FAR){
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

//From Flopine <3
//https://www.shadertoy.com/view/sdfyWl
float ambientOcclusion(float e, vec3 p, vec3 n){
  return scene(p+e*n)/e;
}

vec3 shade(vec3 rd, vec3 p, vec3 ld, vec3 coll, vec3 cols){
  vec3 n = normals(p);
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, 10.0);
  
  float ao =ambientOcclusion(0.1, p, n) + ambientOcclusion(0.25, p, n) + ambientOcclusion(0.5, p, n);
  ao *= 0.5;
  return (coll*l + cols*s)*ao;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(q*2.0, -1.0);
  vec3 rd = vec3(0.0, 0.0, 1.0);
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  vec3 ld = normalize(p - vec3(2.0, -15.0, -1.0));
  
  vec3 col = vec3(uv.x, (sin(time*0.1)+1.0)*0.25, uv.y);
  if(t <= FAR){
    col = shade(rd, p, ld, col*1.2, col.gbr*1.5);
  }
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.7);
  
  col = smoothstep(-0.2, 1.2, col);
  col *= smoothstep(0.8, 0.1*0.799, distance(uv, vec2(0.5))*(0.6 + 0.1));

	out_color = vec4(col , 1.0);
}