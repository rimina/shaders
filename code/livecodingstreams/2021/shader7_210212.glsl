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
float fft = texture(texFFTIntegrated, 1.0).r;

const float E = 0.001;
const float FAR = 40.0;
const int STEPS = 64;

vec3 glow = vec3(0.0);

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
  
  return length(max(d, 0.0) + min(max(d.x, max(d.y, d.z)), 0.0));
}

float scene(vec3 p){
  vec3 pp = p;
  
  pp.z = mod(pp.z - 21.0, 42.0)+21.0;
  
  for(int i = 0; i < 4; ++i){
    pp = abs(pp) - vec3(4.0, 3.0, 5.0);
    rot(pp.xy, fract(time));
    rot(pp.yz, fft);
  }
  
  float a = box(pp, vec3(1.0, 1.0, FAR));
  float b = box(pp-vec3(2.0, 4.0, 0.0), vec3(1.0, 1.0,FAR));
  float c = sphere(pp, 2.0);
  
  vec3 g = vec3(0.5, 0.2, 0.6)*0.1 / (0.05+abs(a));
  g += vec3(0.1, 0.5, 0.1)*0.01 / (0.1+abs(b));
  g += vec3(0.8, 0.1, 0.0)*0.1 / (0.01+abs(c));
  g *= 0.33;
  
  glow += g;
  
  a = max(abs(a), 0.5);
  c = max(abs(c), 0.9);
  
  return min(a, min(b, c));
}


float march(vec3 ro, vec3 rd, out vec3 p){
  p = ro;
  float t = E;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    
    t += d;
    p += d*rd;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, time*0.5);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  
  vec3 p = vec3(0.0);
  float t = march(ro, rd, p);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = vec3(0., 0.6, 0.8);
  }
  col += glow;
  
  col += prev;
  col *= 0.5;
  
  prev = texture(texPreviousFrame, uv*0.35).rgb;
  col += prev;
  col *= 0.5;

  
  
	out_color = vec4(col, 1.0);
}