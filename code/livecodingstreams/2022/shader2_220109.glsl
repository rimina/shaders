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

const float E = 0.001;
const float FAR = 500.0;
const int STEPS = 60;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything


float sinNoise(vec2 p){
  return 0.5*(sin(p.x) + cos(p.y));
}

float plane(vec3 ro, vec3 rd, vec3 p){
  vec3 n = vec3(0.0, 1.0, 0.0);
  return dot(p-ro, n)/dot(rd, n);
}


vec3 shade(vec3 rd, vec3 p){
  
  float thicness = 0.8;
  
  vec2 m = mod(p.xz, thicness*6.0);
  vec3 col = vec3(0.25, 0., 1.0);
  
  if(m.x < thicness || m.y < thicness){
    //col = vec3(0.25, 0., 1.0);
    col = vec3(-1.0);
  }
  
  return col;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 5.0, time*2.0);
  vec3 rt = vec3(0.0, 4.0, 5.0+ro.z);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z)*vec3(q, 1.0/radians(60.0)));
  
  float tg = plane(ro, rd, vec3(0.0, -8.0, 0.0))-sinNoise(q*5.0);
  
  vec3 p = ro+rd*tg;
  
  vec3 col = vec3(0.0);
  if(tg <= FAR && tg >= E){
    col = shade(rd, p);
  }
  col += vec3(0.8, 0.5, 0.5)-vec3(uv.y*0.75)*vec3(1.0, 0.75, 0.3);
 
  float d = length(p-ro);
  float amount = 1.0 - exp(-d*0.01);
  col = mix(col, vec3(0.55, 0.0, 0.45), amount);
  
  col = smoothstep(0.1, 0.9, col);
  

	out_color = vec4(col, 1.0);
}