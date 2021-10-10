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

const float E = 0.001;
const float FAR = 200.0;
const int STEPS = 60;

float M = 0.0;

const vec3 FOG_COLOR = vec3(0.3, 0.6, 0.8);
const vec3 LIGHT_COLOR = vec3(1.0, 0.9, 0.6);

//Duck out of cubes
layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float cylinder(vec3 p, float r, float lenght){
  float l = length(p.yz) - r;
  l = max(l, abs(p.x) - lenght);
  return l;
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  
  rot(pp.xz, radians(-25.0));
  
  pp += vec3(time*1.5, 0.0, 0.0);
  float cell = 5.0;
  pp.x = mod(pp.x+cell*0.5, cell)-cell*0.5;
  
  pp.y += sin(time*0.5);
  
  float ground = box(pp-vec3(0.0, -3.1, 0.0), vec3(5.0, 1.0, FAR*2.0));
  
  vec3 ppp = pp;
  ppp -= vec3(0.1*fract(time*2.5), 0.0, 0.0);
  float head = box(ppp, vec3(0.5));
  ppp = ppp-vec3(-0.75, -0.1, 0.0);
  float beak = box(ppp, vec3(0.25, 0.075, 0.5));
  
  ppp = pp;
  ppp.z = abs(ppp.z)-0.2;
  ppp -= vec3(-0.6, 0.23, 0.0);
  
  float eye = cylinder(ppp, 0.1, 0.2);
  
  ppp = pp;
  ppp = ppp-vec3(1.0, -1.0, 0.0);
  rot(ppp.yz, 0.03*sin(-time*5.5));
  float body = box(ppp, vec3(1.0, 0.75, 0.75));
  float tail = box(ppp-vec3(1.0+(0.1*fract(time*2.5)), 0.9, 0.0), vec3(0.3, 0.2, 0.7));
  body = min(tail, body);
  body = min(head, body);
  
  ppp = pp;
  rot(ppp.yz, 0.07*sin(time*5.5));
  ppp.z = abs(ppp.z)-0.5;
  ppp -= vec3(1.0, -1.8, 0.0);
  float leg = box(ppp, vec3(0.1, 0.21, 0.1));
  ppp -= vec3(-0.2, -0.2, 0.0);
  leg = min(leg, box(ppp, vec3(0.45, 0.1, 0.25)));
  
  
  if(body <= beak && body <= leg && body <= eye && body < ground){
    M = 1.0;
  }
  else if(eye <= beak && eye <= leg && eye <= body && eye < ground){
    M = 0.0;
  }
  else{
    M = 2.0;
  }
  
  body = min(beak, body);
  
  float duck = min(body, leg);
  
  if(ground < duck){
    M = 3.0;
  }
  
  return min(duck, ground);
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t += d;
    p = ro + rd*t;
    
    if(d < E || t > FAR){
      break;
    }
  }
  
  return t;
}

vec3 getColor(){
  vec3 col = vec3(1.0);
  if(M == 1.0){
    //yellow
    col = vec3(1.0, 0.75, 0.3);
  }
  else if(M == 2.0){
    //Orange
    col = vec3(0.9, 0.45, 0.2);
  }
  else if(M == 0.0){
    //black for eyes
    col = vec3(0.0);
  }
  else{
    //green for ground
    col = vec3(0.1, 0.6, 0.1);
  }
  
  return col;
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.03);
	vec3  fogColor = mix(FOG_COLOR, LIGHT_COLOR, pow(sunAmount, 16.0));
  return mix(col, fogColor, fogAmount);
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x / v2Resolution.y;
  
  vec3 ro = vec3(0.0, 1.5+sin(time*0.1)*0.5, 10.0);
  vec3 rt = vec3(0.0, 0.5, 1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(50.0)));
  
  vec3 col = vec3(0.0);
  float t = march(ro, rd);
  vec3 p = ro + rd * t;
  
  vec3 lp = vec3(4.0, 6.0, 2.0);
  vec3 lt = ro;
  vec3 ld = normalize(lt-lp);
  
  if(t < FAR){
    col = getColor()+(1.0/t)*0.5;
  }
  col = fog(col, p, ro, rd, ld);

	out_color = vec4(col, 1.0);
}