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

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.5).r;

const float E = 0.001;
const float FAR = 60.0;
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
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  rot(pp.xz, time*0.5+fft*10.0);
  pp = abs(pp)-vec3(4.0, 4.0, 2.0);
  rot(pp.xy, fft*20.0);
  float a = sphere(pp-vec3(3.0, 3.0, 0.0), 1.0);
  float b = box(pp, vec3(0.5, 0.5, FAR));
  
  glow += vec3(0.6, 0.0, 0.8)*0.05 / (0.01+abs(a));
  glow += vec3(0.8, 0.5, 0.3)*0.01 / (0.01+abs(b));
  
  return min(a, b);
}


float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t +=d;
    p = ro + rd*t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}

vec4 render(vec3 ro, vec3 rd){
  
  float t = march(ro, rd);
  vec4 col = vec4(0.0, 0.0, 0.0, 1.0);
  if(t < FAR){
    col = vec4(0.3, 0.3, 0.3, 0.0);
  }
  
  col += vec4(glow*0.25, 0.0);
  
  return col;
}


void main(void)
{
	vec2 uvv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 uv = -1.0 + 2.0*uvv;
  uv.x *= v2Resolution.x/v2Resolution.y;
  
  float r = length(uv);
  float t = atan(uv.y/uv.x);
  float p = atan(uv.x, uv.y);
  
  vec2 q = vec2(r, t);
  
  vec3 ro = vec3(0.0, 0.0, 3.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = mat3(x,y,z)*vec3(q, radians(50.0));
  
  q = cos(time*0.1+fft*20.0)*q + sin(time*0.1)*vec2(q.y, -q.x);
  
  vec2 m = mod(q*20.0+time+fft*20.0, 8.0)-5.0;
  
  vec4 col = render(ro, rd);
  
  if(m.x*m.y > 0.0){
    col += vec4(0.0, 0.0, 0.0, 1.0);
  }
  else if(m.x < 0.0){
    col += vec4(0.5, 0.0, 0.8, 0.0);
  }
  
  vec4 prev = texture(texPreviousFrame, uvv);
  
  col = mix(col, prev, 0.8);
  
  prev = texture(texPreviousFrame, q);
 col = mix(col, prev, 0.05);
  
	out_color = col;
}