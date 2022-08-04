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

float E = 0.001;
float F = 100.;

vec3 glow = vec3(0.);

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.)) + min(max(d.x, max(d.y, d.z)), 0.);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  
  vec3 pp = p;
  float bb = box(pp-vec3(0., -5., 0.), vec3(10., 0.5, 10.));
  
  for(int i = 0; i < 5; ++i){
    pp = abs(pp)-vec3(0.5, 0.8, 0.5);
    rot(pp.xy, time*0.5);
    rot(pp.yz, time*0.25 + fft*2.);
  }
  
  float bc = box(pp, vec3(0.5, 0.1, 0.5));
  
  glow += vec3(0.05, 0.2, 0.2)*0.02/(abs(bc)+0.1);
  
  float cc = length(p)-2.;
  glow += vec3(0.5, 0.2, 0.0)*0.02/(abs(cc)+0.01);
  bc = max(bc, -cc);
  
  cc = length(pp)-1.5;
  
  glow += vec3(0.5, 0.2, 0.3)*0.01/(abs(cc)+0.1);
  
  cc = max(abs(cc), 0.5);
  
  
  
  return min(min(bc, cc), bb);
}

vec3 shade(vec3 rd, vec3 p, vec3 ld){
  vec3 e = vec3(E, 0., 0.);
  vec3 n = normalize(vec3(
    scene(p+e.xyy)-scene(p-e.xyy),
    scene(p+e.yxy)-scene(p-e.yxy),
    scene(p+e.yyx)-scene(p-e.yyx)
  ));
  
  float l = max(dot(-ld, n), 0.);
  float a = max(dot(reflect(rd, ld), n), 0.);
  float s = pow(a, 20.);
  
  return vec3(0.6, 0.5, 0.5)*l + vec3(0.9, 0.6, 0.5)*s;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 q = uv-0.5;
	q /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec3 ro = vec3(20.*cos(time*0.5), 2.0, 25.*sin(time*0.5));
  vec3 rt = vec3(0., 0., -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.,1.,0.)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, 1./radians(60.)));
  
  vec3 p = ro;
  float t = E;
  
  for(int i = 0; i < 64; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd * t;
    
    if(d < E || t > F){
      break;
    }
  }
  vec3 ld = normalize(p-rt);
  vec3 col = vec3(0.1, 0.1, 0.15);
  if(t < F){
    col = shade(rd, p, ld);
  }
  col += glow*0.8;
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.8);
  
  col = smoothstep(-0.2, 1.2, col);
  
	out_color = vec4(col, 1.0);
}