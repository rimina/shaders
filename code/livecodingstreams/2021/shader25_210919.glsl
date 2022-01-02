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

const float E = 0.001;
const int STEPS = 60;
const float FAR = 100.0;

const vec3 FOG_COLOR = vec3(0.3, 0.6, 0.8);


//Hash method from https://www.shadertoy.com/view/4djSRW
#define HASHSCALE3 vec3(.1031, .1030, .0973)

vec2  Hash22F(vec2  p ){
    vec3 p3 = fract(vec3(p.xyx ) * HASHSCALE3); 
    p3 += dot(p3, p3.yzx  + 19.19);
    return fract((p3.xx   + p3.yz  ) * p3.zy  );
}

vec2 noise(vec2 p){
  vec2 d = p;
  
  int octaves = 3;
  float gain = 0.5;
  float l = 1.5;
  
  float amplitude = 1.5;
  float freq = 1.0;
  
  for(int i = 0; i < octaves; ++i){
    d += amplitude * Hash22F(freq*d);
    freq *= l;
    amplitude *= gain;
  }
  
  return d;
}

float voronoi(vec2 q, inout vec2 mm){
  vec2 qq = q * 5.0;
  vec2 f = fract(qq);
  vec2 i = floor(qq);
  float m = 1.0;
  mm = vec2(1.0);
  
  for(int y = -1; y <= 1; ++y){
    for(int x = -1; x <= 1; ++x){
      vec2 neighbor = vec2(float(x), float(y));
      vec2 point = Hash22F(i + neighbor);
      
      point = 0.5 + 0.5*sin(fft*10.5 + 9.0 * point);
      
      float d = length(neighbor + point - f);
      //m = min(m, d);
      if(d < m){
        m = d;
        mm = point;
      }
    }
  }
  
  return m;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec2 m = vec2(1.0);
  vec3 pp = p;
  
  
  rot(pp.xz, time*0.1);
  
  float disp = voronoi(pp.zx, m);
  
  pp -= vec3(0.0, -1.0, 0.0);
  float ball = sphere(pp, 3.0)+disp*0.1;
  float shape = box(p-vec3(0.0, -1.0, 0.0), vec3(7.0, 0.6, 5.0))-disp*.15;
  
  return min(ball, shape);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd *t;
    
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

vec3 shade(vec3 p, vec3 d, vec3 ld){
  vec3 n = normals(p);
  float l = max(dot(n, ld), 0.0);
  vec3 a = reflect(n, ld);
  float s = pow(max(dot(d, a), 0.0), 10.0);
  
  return vec3(0.2, 0.8, 0.8)*l + vec3(0.8, 0.6, 0.2)*s;
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 fc){
  float dist = length(p-ro);
	float fogAmount = 1.0 - exp( -dist*0.08);
  return mix(col, fc, fogAmount);
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + uv*2.0;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 col = vec3(0.0);
  vec2 mm = vec2(1.0);
  float m = voronoi(q, mm);
  col.rb = mm*0.25;
  
  vec3 ro = vec3(0.0, 0.2, 5.0);
  vec3 rt = vec3(0.0, 0.0, -10.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, radians(60.0)));
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  vec3 lp = vec3(0.0, -20.0, 0.0);
  vec3 ld = normalize(p-lp);
  
  if(t < FAR){
    col = shade(p, rd, ld);
    col += 1.0/t * 0.2;
  }
  col = fog(col, p, ro, rd, mix(FOG_COLOR, vec3(mm.x, 0.0, mm.y)*vec3(0.8, 0.5, 1.2), 0.75));
  
  col = smoothstep(-0.2, 1.1, col);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.9);
  
  
	out_color = vec4(col, 1.0);
}