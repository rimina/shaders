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
const float FAR = 100.0;
const int STEPS = 60;

float M = 0.0;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

//http://www.iquilezles.org/www/articles/palettes/palettes.htm
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d ){
    return a + b*cos( 6.28318*(c*t+d) );
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, vec3(0.0))) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  vec3 pp = p;
  
  float tunnel = -box(pp, vec3(2.0, 2.0, p.z+FAR*2.0));
  
  float size = 15;
  
  float id = floor((pp.z + size*0.5) / size);
  pp.z = mod(pp.z+size*0.5, size)-size*0.5;
  
  
  pp = abs(pp) - vec3(0.5);
  pp -= vec3(0.0, 0.5+sin(time+id)*0.5, 0.0);
  
  rot(pp.xz, time+id);
  rot(pp.xy, id+fft*2.0);
  
  vec3 bsize = vec3(0.25, 4.5, 0.25)*0.75;
  
  float cube = box(pp, bsize);
  
  float guard = -box(pp, bsize);
  guard = abs(guard) + size*0.1;
  
  pp = p;
  
  id = floor((pp.z + size*0.5) / size);
  pp.z = mod(pp.z+size*0.5, size)-size*0.5;
  
  
  rot(pp.xz, time+id);
  rot(pp.xy, id+fft*2.0);
  pp = abs(pp)-vec3(1.0);
  rot(pp.xz, time+id);
  rot(pp.xy, id+fft*2.0);
  
  float cube2 = box(pp, vec3(0.3));
  
  
  if(cube < tunnel && cube < cube2){
    M = 1.0+abs(id);
  }
  else if(cube2 < tunnel && cube2 < cube){
    M = abs(id);
  }
  else{
    M = 0.0;
  }
  
  return min(min(tunnel, cube2), min(cube, guard));
}

float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 p = ro;
  
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
    scene(p+e.yxy) - scene(p-e.xyx),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

vec3 getColor(vec3 p){
  vec3 col = palette(floor(p.z*0.5)+0.7, vec3(0.5, 0.5, 0.25), vec3(0.5), vec3(0.5), vec3(0.2, 0.8, 0.5));//vec3(0.8, 0.5, 0.3);
  if(M > 0.0){
    col = palette((M+time)*0.25, vec3(0.5, 0.5, 0.25), vec3(0.5), vec3(0.5), vec3(0.2, 0.8, 0.5));
  }
  return col;
}


vec3 shade(vec3 p, vec3 rd, vec3 n, vec3 ld){
  vec3 col = getColor(p);

  float l = max(dot(ld, n), 0.0);
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float s = pow(a, 10.0);
  
  return col * l + vec3(0.8, 0.3, 0.7) * s;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, time);
  vec3 rt = vec3(0.0, 0.0, ro.z+1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  vec3 col = vec3(0.0);
  if(t < FAR){
    vec3 n = normals(p);
    col = shade(p, rd, n, -rd)+((1.0/t)*0.4);
  }
  
  float d = distance(p, ro);
  float fog = 1.0 - exp(-d*0.1);
  col = mix(col, vec3(0.15, 0.1, 0.2), fog);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.6);

	out_color =  vec4(col, 1.0);
}