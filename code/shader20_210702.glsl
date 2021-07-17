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
const int STEPS = 64;

int M = 0;

const vec3 FOG_COLOR = vec3(0.6, 0.7, 0.8);
const vec3 LIGHT_COLOR = vec3(0.9, 0.9, 0.7);

float plane(vec3 p, vec3 n, float d){
  return dot(p, n) + d;
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float cosNoise(vec2 p){
  return 0.5*(sin(p.x) + sin(p.y));
}

float scene(vec3 p){
  
  vec3 pp = p;
  vec3 ppp = p;
  
  //For the ground distortion I have taken some inspiration from here:
  //https://www.shadertoy.com/view/XlSSzK
  float h = 0.0;
  vec2 q = p.xz*0.5;
  float s = 0.5;

  const mat2 m2 = mat2(1.,-1.,1., 0.5);
  
  float a = time;
  float b = 0.0;
  if(p.z > -30.0){

    for(int i = 0; i < 6; ++i){
      h += s*cosNoise(q+a); 
      q = m2*q*0.8; 
      q += vec2(5.41+b+cos(a+b),3.13+b+sin(a+b));
      s *= 0.52 + 0.2*h;
    }
    h *= 1.2;
  }
  
  //maa = ground
  float maa = plane(p, vec3(0.0, 1.0, 0.0), 0.0)-h;
  //pallo = ball
  float pallo = sphere(p-vec3(0.0, 1.0, -10.0), 1.5);
  
  vec2 offset = vec2(40.0, 20.0);
  vec2 offset2 = vec2(25.0, 40.0);
  
  float building = 100.0;
  
  vec2 id = floor((p.xz + offset*0.5)/offset);
  pp.xz = mod(p.xz + offset*0.5, offset) - offset*0.5;
  
  vec2 id2 = floor((p.xz + offset2*0.5)/offset2);
  ppp.xz = mod(p.xz + offset2*0.5, offset2) - offset2*0.5;
  
  if(p.z < -30.0){
    building = box(pp, vec3(10.0, 20.0-cosNoise(id)*5.0, 6.0));
    building = min(building, box(ppp, vec3(7.0, 30.0-cosNoise(id2)*10.0, 4.0)));
  }
  float guard = -box(pp, vec3(20.0, 50.0, 10.0));
  guard = abs(guard) + offset.x * 0.1;
  
  float guard2 = -box(ppp, vec3(10.0, 50.0, 20.0));
  guard2 = abs(guard2) + offset2.y * 0.1;
  
  guard = min(guard, guard2);


  
  if(maa < pallo && maa < building){
    M = 1;
  }
  else if(building < pallo && building < maa){
    M = 2;
  }
  else{
    M = 0;
  }
  
  return min(maa, min(pallo, min(guard , building)));
}

//ro = ray origin, rd = ray direction
float march(vec3 ro, vec3 rd){
  float t = E;
  //p = position
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
    scene(p + e.xyy) - scene(p - e.xyy),
    scene(p + e.yxy) - scene(p - e.yxy),
    scene(p + e.yyx) - scene(p - e.yyx)
  ));
}

vec3 shade(vec3 rd, vec3 p, vec3 n, vec3 ld){
  float l = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(ld, n), rd), 0.0);
  float shiny = 20.0;
  vec3 col = vec3(0.1, 0.3, 0.35);
  vec3 col2 = vec3(0.7, 0.9, 1.0);
  if(p.z < -30.0){
    col = vec3(0.5, 0.8, 0.2);
    col2 = vec3(0.5, 1.0, 0.4);
    shiny = 1.0;
  }
  
  if(M == 0){
    col = col.rrg;
    shiny = 2.0;
  }
  else if( M == 2){
    col = vec3(1.0, 0.0, 1.0);
    col2 = col + 0.2;
    shiny = 2.0;
  }
  else{
  }
  
  float s = pow(a, shiny);
  
  return l * col*0.4 + s * col2*0.6;
  
}

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
	float sunAmount = max( dot(rd, -ld), 0.0 );
	float fogAmount = 1.0 - exp( -dist*0.035);
	vec3  fogColor = mix(FOG_COLOR, LIGHT_COLOR, pow(sunAmount, 4.0));
  return mix(col, fogColor, fogAmount);
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	uv = -1.0 + uv*2.0;
	uv *= vec2(v2Resolution.x / v2Resolution.y, 1);
  
  //ray origin
  vec3 ro = vec3(15.0, 40.5, 80.0-time*2.0);
  //ray target
  vec3 rt = vec3(15.0, 30.0, ro.z-20.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(uv, radians(60.0)));
  
  vec3 col = FOG_COLOR;
  float t = march(ro, rd);
  
  vec3 p = ro + rd *t;
  vec3 n = normals(p);
  
  vec3 lp = vec3(30.0, -50.0, 100.0);
  vec3 lt = ro;
  vec3 ld = normalize(lt-lp);
  
  if(t < FAR){
    col = shade(rd, p, n, ld);
    
    if((M == 1 && p.z > -30.0) || M == 2){
      vec3 refd = reflect(rd, n);
      vec3 refo = p + 2.0*E*n;
      t = march(refo, refd);
      vec3 pr = refo + refd * t;
      if(t < FAR){
        n = normals(pr);
        col += shade(refd, pr, n, ld);
        col *= 0.5;
      }
    }
    
  }
  //col += vec3(0.9, 0.9, 0.7)*0.2;
  
  col = fog(col, p, ro, rd, -ld);

	out_color = vec4(col, 1.0);
}