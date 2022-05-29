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
const float E = 0.001;
const float FAR = 100.0;
const int STEPS = 70;

const vec3 FOG_COLOR = vec3(0.05, 0.01, 0.2);

vec3 coll = vec3(0.5);
vec3 cols = vec3(0.6);

//function from https://iquilezles.org/articles/palettes/
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d){
  return a + b*cos(6.28318 * (c*t+d) );
}

//https://www.shadertoy.com/view/4djSRW
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}


float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

void bound(float start, float stop, float off, inout float c, inout float p){
  if(c > stop){
    p += off*(c-stop);
    c = stop;
  }
  if(c < start){
    p += off*(c-start);
    c = start;
  }
}

float scene(vec3 p){
  vec3 pp = p;
  
  vec3 off = vec3(1.0, 2.0, 1.0);
  vec3 c = floor((p + off*0.5)/off);
  
  if(mod(c.x, 2.0) == 0.0 && mod(c.z, 2.0) == 0.0){
    pp -= vec3(0.0, time*0.1, 0.0);
  }
  else{
    pp -= vec3(0.0, -time*0.1, 0.0);
  }
  
  pp = mod(pp + off*0.5, off) - off*0.5;
  
  bound(-8.0, 8.0, off.z, c.z, pp.z);
  bound(-5.0, 5.0, off.x, c.x, pp.x);
  
  float a = time*0.25+length(c.xz)*2.0;
  if(mod(c.x, 2.0) == 0.0 && mod(c.z, 2.0) == 0.0){
    rot(pp.xz, a);
  }
  else{
    rot(pp.xz, -a);
  }
  
  float block = box(pp, vec3(0.1, 0.95, 0.1));
  
  //vectors from https://iquilezles.org/articles/palettes/
  coll = palette(hash12(c.xz)*60.0, vec3(0.5),
    vec3(0.5), vec3(2.0, 1.0, 0.0), vec3(0.5, 0.2, 0.25));
  
  return block;
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

vec3 shade(vec3 rd, vec3 p, vec3 ld){
  vec3 n = normals(p);
  
  float l = max(dot(n, ld), 0.0);
  
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float s = pow(a, 40.0);
  
  return coll*l + cols*s;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(8.0*sin(time*0.025), 1.6, 12.0*cos(time*0.025));
  vec3 rt = vec3(0.0, 1.25, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, 1.0/radians(50.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  vec3 ld = normalize(ro-rt);
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    col = shade(rd, p, ld);
  }
  
  float d = distance(p, ro);
  float amount = 1.0 - exp(-d*0.06);
  
  col = mix(col, FOG_COLOR, amount);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.65);
  
  col = smoothstep(-0.2, 1.2, col);

	out_color = vec4(col, 1.0);
}