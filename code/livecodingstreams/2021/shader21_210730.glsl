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
const float FAR = 60.0;
const int STEPS = 64;

int M = 0;

struct Material{
  vec3 l;
  vec3 s;
  float shine;
  bool refl;
};

Material getMaterial(){
  Material m;
  m.l = vec3(0.3);
  m.s = vec3(0.5);
  m.shine = 40.0;
  m.refl = false;
  if(M == 1){
    m.l = vec3(0.0);
    m.s = vec3(0.1);
    m.shine = 8.0;
    m.refl = true;
  }
  else if(M == 2){
    m.l = vec3(0.5, 0.55, 0.6);
    m.s = vec3(0.6, 0.95, 1.0);
    m.shine = 20.0;
    m.refl = true;
  }
  else if(M == 3){
    m.l = vec3(1.0);
    m.s = vec3(1.5);
    m.shine = 10.0;
    m.refl = true;
  }
  return m;
}

float plane(vec3 p, vec3 n, float d){
  return dot(p, n) + d;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

void rotate(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opSmoothUnion( float d1, float d2, float k ){
  float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
  return mix( d2, d1, h ) - k*h*(1.0-h);
}

float scene(vec3 p){
  vec3 pp = p;
  vec3 ppp = p;
  
  float repY = 10.0;
  pp.y = mod(pp.y+repY*0.5, repY)-repY*0.5;
  float room = -box(pp, vec3(12.0, 6.0, 12.0));
  
  ppp = abs(pp) - vec3(5.0, 0.0, 5.0);
  rotate(ppp.xz, time);
  float pilars = box(ppp, vec3(0.5, 5.0, 0.5));
  
  ppp = p-vec3(0.0, -time*3.0, 0.0);
  repY = 8.0;
  ppp.y = mod(ppp.y+repY*0.5, repY)-repY*0.5;
  rotate(ppp.xy, time);
  rotate(ppp.xz, time);
  float thing = box(ppp, vec3(1.5));
  
  if(thing < room && thing < pilars){
    M = 1;
  }
  else if(pilars < room && pilars < thing){
    M = 2;
  }
  else if(pp.y > 2.0 && pp.y < 5.0){
    M = 3;
  }
  else if(pp.y > -2.0 && pp.y < 0.0){
    M = 1;
  }
  else{
    M = 0;
  }
  
  return min(opSmoothUnion(room, pilars, 0.3), thing);
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

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p+e.xyy) - scene(p-e.xyy),
    scene(p+e.yxy) - scene(p-e.yxy),
    scene(p+e.yyx) - scene(p-e.yyx)
  ));
}

vec3 shade(vec3 rd, vec3 p, vec3 n, vec3 ld, Material m){
  float lambertian = max(dot(ld, n), 0.0);
  float shine = 20.0;
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float specular = pow(a, m.shine);
  
  return m.l*lambertian + m.s*specular;
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld, vec3 lc){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.035);
	vec3  fogColor = mix(vec3(0.5), lc, pow(sunAmount, 4.0));
  return mix(col, fogColor, fogAmount);
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	vec2 uvv = -1.0 +  2.0*uv;
  uvv.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(9.0*cos(time*0.2), time*2.0, 9.0*sin(time*0.2));
  vec3 rt = vec3(0.0, 6.0+ro.y, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(uvv, radians(60.0)));
  vec3 ld = -rd;
  vec3 lc = vec3(0.5, 0.9, 0.95);
  vec3 ld2 = normalize(vec3(0.0) - vec3(-10.0, ro.y, 10.0));
  vec3 lc2 = vec3(1.0, 0.9, 0.85); 
  
  float t = march(ro, rd);
  
  vec3 col = vec3 (0.0);
  vec3 p = ro + rd*t;
  if(t < FAR){
    
    Material m = getMaterial();
    vec3 n = normals(p);
    col = shade(rd, p, n, ld, m);
    col += shade(rd, p, n, ld2, m);
    col *= 0.5;
    
    vec3 r_ro = p + n*E*2.0;
    vec3 r_rd = reflect(rd, n);
    vec3 r_col = vec3(0.0);
    vec3 r_p = p;
    
    for(int i = 0; i < 2; ++i){
      if(m.refl){
        t = march(r_ro, r_rd);
        if(t < FAR){
          r_p = r_ro + r_rd*t;
          m = getMaterial();
          n = normals(r_p);
          r_col = shade(r_rd, r_p, n, ld, m);
          r_col += shade(r_rd, r_p, n, ld2, m);
          r_col *= 0.5;
          col = mix(col, r_col, 0.5);
        }
        r_ro = r_p + n*E*2.0;
        r_rd = reflect(rd, n);
      }
      else{
        break;
      }
    }
  }
  
  vec3 fg = fog(col, p, ro, rd, ld, lc);
  fg += fog(col, p, ro, rd, ld2, lc2);
  fg *= 0.5;
  
  col = fg;
  
  col = smoothstep(-0.1, 1.2, col)* smoothstep(0.8, 0.005*0.799, distance(uv, vec2(0.5))*(0.9+0.005));
  
  col = pow(col, 1.0/vec3(1.7));
  

	out_color = vec4(col, 1.0);
}