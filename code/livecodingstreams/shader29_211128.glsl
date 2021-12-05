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

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything'

#define PI 3.14159265359

float time = fGlobalTime;


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  uv *= 2.0;
  uv = fract(uv);
  
  vec2 q = -1.0 + 2.0*uv;
	q /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec2 p = vec2(q.x, q.y);
  float r = length(p)*2.0;
  float a = atan(p.y, p.x)+time*0.5;
  
  float f = cos(a*3.0);
  vec3 color = vec3(smoothstep(f, f+0.01, r));
  color *= vec3(0.1, 0.8, 0.1);
  
  float fft  = texture(texFFT, a*3.0).r*5.0;
  
  float n = 3.0;
  p = cos(time*0.5)*p + sin(time*0.5)*vec2(p.y, -p.x);
  a = atan(p.x, -p.y)+PI;
  r = (PI*2.0)/n;
  float d = cos(floor(0.25+a/r)*r-a)*length(p);
  color -= vec3(smoothstep(0.5, 0.51, d))-fft;
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;

  color = mix(color, prev, 0.8);
	
  out_color = vec4(color, 1);
}