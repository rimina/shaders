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

//From HG sdf library: http://mercury.sexy/hg_sdf/
#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5)*0.5 + 0.5)

float time = fGlobalTime;
float E = 0.001;
float FAR = 60.0;
int STEPS = 64;

int ID = 0;

struct Material{
    vec3 absorbed;
    vec3 base;
    vec3 highlight;
    
    bool reflective;
    bool refractive;
    float reflectivity;
    float refractivity;
};

Material getMaterial(){
  Material m;
  
  if(ID == 0){
    m.absorbed = vec3(0.5, 0.9, 0.7);
    m.base = vec3(0.2, 0.5, 0.6);
    m. highlight = vec3(0.5, 0.8, 0.9);
    
    m.reflective = true;
    m.refractive = true;
    m.reflectivity = 0.001;
    m.refractivity = 1.125;
  }
  else if(ID == 2){
    m.absorbed = vec3(0.2, 0.0, 0.5);
    m.base = vec3(0.5, 0.1, 0.0);
    m. highlight = vec3(0.8, 0.4, 0.2);
    
    m.reflective = true;
    m.refractive = false;
    m.reflectivity = 0.08;
    m.refractivity = 1.33333;
  }
  else{
    m.absorbed = vec3(0.5, 0.2, 0.2);
    m.base = vec3(0.2, 0.0, 0.2);
    m. highlight = vec3(0.5, 0.2, 0.5);
    
    m.reflective = true;
    m.refractive = true;
    m.reflectivity = 0.01;
    m.refractivity = 1.45;
  }
  
  return m;
}


float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 b){
  vec3 d = abs(p)-b;
  
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

void rotate(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// 3D noise function (IQ)
float noise(vec3 p){
  vec3 ip = floor(p);
  p -= ip;
  vec3 s = vec3(7.0,157.0,113.0);
  vec4 h = vec4(0.0, s.yz, s.y+s.z)+dot(ip, s);
  p = p*p*(3.0-2.0*p);
  h = mix(fract(sin(h)*43758.5), fract(sin(h+s.x)*43758.5), p.x);
  h.xy = mix(h.xz, h.yw, p.y);
  return mix(h.x, h.y, p.z);
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  float safe = sphere(p, 5.0);
  
  float room = -box(p, vec3(12.0, 8.0, 12.0));
  
  //pp.z = mod(pp.z+5.0, 10.0)-5.0;
  //pp.x = mod(pp.x+5.0, 10.0)-5.0;
  
  pp = abs(pp) - vec3(4.0, 0.0, 4.0);
    
  rotate(pp.xz, time*0.5);
  
  rotate(pp.yz, time*0.25);
  
  //pp -= noise(p-time*2.0)*0.1;
  float pilars = box(pp, vec3(1.0, 10.0, 1.0));
  
  if(pilars < room){
    ID = 0;
  }
  else if(p.y > -3.0 && p.y < 3.0){
    ID = 2;
  }
  else{
    ID = 1;
  }
  
  return min(room, pilars);
  //return max(box(pp, vec3(1.0, 10.0, 1.0)), -safe);
  //return sphere(pp, 1.0);
}



bool march(in vec3 ro, in vec3 rd, in bool inside, out float t){
  t = E;
  float dir = inside ? -1.0 : 1.0;
  bool hit = false;
  vec3 p = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = dir*scene(p);
    t += d;
    p = ro + rd*t;
    
    if(abs(d) < E || t > FAR){
      if(abs(d) < E){
        hit = true;
      }
      break;
    }
  }
  
  return hit;
}

vec3 normals(vec3 p){
  vec3 e = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p + e.xyy) - scene(p - e.xyy),
    scene(p + e.yxy) - scene(p - e.yxy),
    scene(p + e.yyx) - scene(p - e.yyx)
  ));
}

bool reflection(inout vec3 rd, in vec3 n, inout vec3 p){
  rd = reflect(rd, n);
  float t = 0.0;
  if(march(p+n*E*2.0, rd, false, t)){
    p = (p+n*E*2.0) + rd * t;
    return true;
  }
  return false;
}

bool refraction(inout vec3 rd, in vec3 n, in float index, in bool side, inout vec3 p){
  rd = refract(rd, n, index);
  float t = 0.0;
  if(march(p-n*2.0*E, rd, side, t)){
    p = (p-n*2.0*E) + rd * t;
    return true;
  }
  
  return false;
}

//referenced from here
//https://blog.demofox.org/2017/01/09/raytracing-reflection-refraction-fresnel-total-internal-reflection-and-beers-law/
float schlick(float f0, float f1, float rr, vec3 n, vec3 d){
    float r = (f0-f1)/(f0+f1);
    r *= r;
    float angle = -dot(n, d);
    if(f0 > f1){
        float f = f0/f1;
        float sinT2 = f*f*(1.0-angle*angle);
        if(sinT2 > 1.0){
            return 1.0;
        }
        angle = sqrt(1.0-sinT2);
    }
    float x = 1.0-angle;
    r = r+(1.0-r)*pow(x, 5.0);
    return rr + (1.0-rr)*r;
}

vec3 bphong(vec3 p, vec3 n, vec3 rd, vec3 ld){
  float lambertian = max(dot(n, ld), 0.0);
  float angle = max(dot(reflect(ld, n), rd), 0.0);
  float specular = pow(angle, 20.0);
  
  return lambertian * vec3(0.8, 0.0, 0.4) + specular * vec3(1.0, 0.2, 0.6);
}


vec3 shade(vec3 p, vec3 n, vec3 rd, vec3 ld, Material m){
  
  //primary ray
  float ff = schlick(1.0, m.refractivity, m.reflectivity, n, rd);
  vec3 col = m.highlight*ff + m.base*(1.0-ff);
  
  //reflection
  vec3 rd_refl = rd;
  vec3 p_refl = p;
  vec3 n_refl = n;
  float f = 0.0;
  Material m_refl = m;
  
  vec3 col_refl = vec3(0.0);
  
  if(m.reflective){
    if(reflection(rd_refl, n_refl, p_refl)){
      m_refl = getMaterial();
      n_refl = normals(p_refl);
      f = schlick(1.0, m_refl.refractivity, m_refl.reflectivity, n_refl, rd_refl);
      col_refl += (m_refl.highlight*f + m_refl.base*(1.0-f));
    }
  }
  
  //refraction
  vec3 rd_refr = rd;
  vec3 p_refr_in = p;
  vec3 p_refr_out = p;
  
  vec3 n_refr = n;
  float refractivity = 1.0;
  float f1 = schlick(refractivity, m.refractivity, m.reflectivity, n, rd);
  float f2 = 0.0;
  Material m_refr_in = m;
  Material m_refr_out = m;
  
  vec3 col_refr = vec3(0.0);
  
  if(m.refractive){
    //ray entering the object
    float index = refractivity/m.refractivity;
    if(refraction(rd_refr, n_refr, index, true, p_refr_in)){
      m_refr_in = getMaterial();
      n_refr = normals(p_refr_in);
      
      col_refr += (m_refr_in.highlight*f1 + m_refr_in.base*(1.0-f1));
      
      f2 = schlick(m_refr_in.refractivity, refractivity, m_refr_in.reflectivity, -n_refr, rd_refr);
      p_refr_out = p_refr_in;
    }
    //ray exiting the object
    if(refraction(rd_refr, -n_refr, m_refr_in.refractivity, false, p_refr_out)){
      m_refr_out = getMaterial();
      n_refr = normals(p_refr_out);
      
      float dist = distance(p_refr_in, p_refr_out);
      vec3 absorbed = exp(-m_refr_in.absorbed * dist);
      
      col_refr += (m_refr_out.highlight*f2 + m_refr_out.base*(1.0-f2));
      col_refr *= absorbed;
    }
  }
  
  col += col_refl + col_refr;
  
  return col * 0.5;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + uv*2.0;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(10.0*sin(time*0.25), 0.0, 10.0*cos(time*0.25));
  vec3 rt = vec3(0.0, 0.0, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  vec3 ld = -rd;
  
  vec3 lp = vec3(8.0*sin(time*0.25), -10.0, 8.0*cos(time*0.25));
  vec3 lt = ro;
  vec3 ld2 = normalize(lt-lp);
  
  float t = 0.0;
  bool hit = march(ro, rd, false, t);
  
  vec3 p = ro + rd * t;
  vec3 n = normals(p);
  
  vec3 col = vec3(0.0);
  if(hit){
    Material m = getMaterial();
    col = shade(p, n, rd, ld, m);
    col += shade(p, n, rd, ld2, m);
    col *= 0.5;
  }
  
  col = smoothstep(-0.1, 1.2, col);
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  col = mix(col, prev, 0.6);

	out_color = vec4(col, 1.0);
}