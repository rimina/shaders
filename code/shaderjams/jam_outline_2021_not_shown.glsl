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
const float E = 0.001;
const float FAR = 60.0;
const int STEPS = 60;

float fft = texture(texFFTIntegrated, 0.5).r;

vec3 glow = vec3(0.0);

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)),0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec3 pp = p;
  
  pp = mod(pp + 10.0, 20.0)-10.0;
  
  float scale = 2.0;
  float offset = 16.0;
  
  for(int i = 0; i < 3; ++i){
    pp = (abs(pp)-vec3(4.0, 2.0, 8.0))*scale-offset*(scale-1.0);
    rot(pp.xz, fft*2.0);
    rot(pp.xy, time*0.1);
    rot(pp.yz, fft+time*0.2);
  }
  
  rot(pp.yz, time+fft);
  
  float s = sphere(pp-vec3(0.0, -4.0, 0.0), 4.5)*pow(scale, -3.0);
  float k = box(pp, vec3(0.5, 0.5, 20.0))*pow(scale, -3.0);
  float a = box(pp-vec3(0.0, -4.0, 0.0), vec3(4.0, 4.0, 30))*pow(scale, -3.0);
  
  float b = sphere(p, 10.0+fract(fft*10.0));
  
  vec3 g = vec3(0.2, 0.4, 0.5)*0.01 / (0.01+abs(k));
  g += vec3(0.8, 0.4, 0.2)*0.03 / (0.01+abs(s));
  g += vec3(0.3, 0.6, 0.8)*0.01 / (0.01+abs(a));
  
  g += vec3(0.8, 0.7, 0.8)*0.5 / (0.05+abs(b));
  
  g *= 0.25;
  
  glow += g;
  
  a = max(abs(a)+0.01, a);
  b = max(abs(b)+0.1, b);
  
  return min(b, min(a, min(s, k)));
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

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  
  return normalize(vec3(
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.06);
	vec3  fogColor = mix(vec3(0.0, 0.05, 0.05), vec3(0.6, 0.4, 0.5), pow(sunAmount, 7.0));
  return mix(col, fogColor, fogAmount);
}

vec3 shade(vec3 p, vec3 rd, vec3 ld){
  vec3 n = normals(p);
  
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float s = pow(a, 10.0);
  
  return l*vec3(0.6, 0.5, 0.9)*0.5 + s*vec3(0.8, 0.6, 1.0)*0.5;
}

vec3 render(vec3 ro, vec3 rd){
  float t = march(ro, rd);
  vec3 p = ro+rd*t;
  
  vec3 ld = normalize(vec3(0.0, 0.0, FAR) - ro);
  vec3 ld2 = normalize(ro-vec3(0.0, 0.0, FAR));
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = shade(p, rd, ld);
    col += shade(p, rd, ld2);
    col *= 0.5;
  }
  
  col += glow*0.2;
  
  vec3 ff = fog(col, p, ro, rd, ld);
  ff += fog(col, p, ro, rd, ld2);
  ff *= 0.5;
  return ff;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(15+cos(time), 4.0+sin(fft*10.0), 15+sin(time));
  vec3 rt = vec3(0.0, -2.0, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z)*vec3(q, radians(60.0)));
  
  vec3 col = render(ro, rd);
  
  
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  
  
	uv /= vec2(v2Resolution.y / v2Resolution.x, 1);
  
  vec2 uuv = vec2(uv.x, -uv.y);
  vec3 logo = texture(texTexOni, vec2(uuv.x-0.25, uuv.y-0.15)*0.75).rgb;
  
  col = mix(col, (1.0-logo), 0.2);
  
  col = mix(col, prev, 0.8);
  
	out_color = vec4(col, 1.0);
}