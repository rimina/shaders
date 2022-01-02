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

//I'm using HG_SDF library! http://mercury.sexy

#define PI 3.14159265
#define TAU (2*PI)
#define PHI (sqrt(5)*0.5 + 0.5)

#define saturate(x) clamp(x, 0, 1)

float time = fGlobalTime;
float fft = texture(texFFTIntegrated, 0.1).r;

const float E = 0.001;
const int STEPS = 64;
const float FAR = 80.0;

const vec3 BC = vec3(0.2, 0.7, 0.9);
const vec3 FC = vec3(0.2, 0.2, 0.5);
const vec3 LC = vec3(0.8, 0.6, 0.4);

int ID = 0;

vec3 glow = vec3(0.0);

// Sign function that doesn't return 0
float sgn(float x) {
    return (x<0)?-1:1;
}

float sphere(vec3 position, float radius){
  return length(position)-radius;
}

float box(vec3 position, vec3 dimensions){
  vec3 b = abs(position)-dimensions;
  return length(max(b, 0.0)) + min(max(b.x, max(b.y, b.z)), 0.0); 
  
}

void rotate(inout vec2 position, float angle){
  position = cos(angle) * position + sin(angle) * vec2(position.y, -position.x);
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

float scene(vec3 position){
  
  vec3 p = position;
  rotate(p.xy, fft*20.0);
  
  float n = noise(position + time * sqrt(5.0)*0.5 + 0.5);
  
  float tunnel = -box(p, vec3(5.0, 5.0, FAR*2.0)) - sin(n)*0.5;
  
  p = position;
  
  float id = floor((p.z + 2.0) / 4.0);
  p.z = mod(p.z + 2.0, 4.0) - 2.0;
  p -= vec3(0.0, sin(time+id), 0.0);
  rotate(p.yz, time);
  
  float boxes = box(p, vec3(0.45));
  
  if(boxes <= tunnel){
    ID = 1;
  }
  else{
    ID = 0;
  }
  
  glow += LC * 0.01 / (abs(boxes) + 0.01);
  
  
  return min(tunnel, boxes);
}


//Sphere marching loop
float march(vec3 ro, vec3 rd){
  float t = E;
  vec3 position = ro;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(position);
    t +=d;
    position = ro + rd*t;
    
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

//http://www.iquilezles.org/www/articles/fog/fog.htm
vec3 fog(vec3 col, vec3 p, vec3 ro, vec3 rd, vec3 ld){
  float dist = length(p-ro);
    float sunAmount = max( dot(rd, -ld), 0.0 );
    float fogAmount = 1.0 - exp( -dist*0.05);
    vec3  fogColor = mix(FC, LC, pow(sunAmount, 6.0));
  return mix(col, fogColor, fogAmount);
}


vec3 shade(vec3 rd, vec3 p, vec3 ld){
  
  vec3 n = normals(p);
  float lambertian = max(dot(n, ld), 0.0);
  float angle = max(dot(reflect(ld, n), rd), 0.0);
  float specular = pow(angle, 10.0);
  
  float m = mod(p.z - time, 8.0) - 4.0;
  vec3 col = BC;
  if(ID == 0){
    if(m < -1.0){
      col = BC.brg;
    }
    else if( m > 1.0){
      col = BC.gbr;
    }
  }
  else{
    col = vec3(1.0);
  }
  
  return lambertian * col * 0.5 + specular * (col * vec3(1.1, 1.2, 1.2)) * 0.8;
}


void main(void)
{
  vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 uvv = -1.0 + 2.0*uv;
  uvv.x *= v2Resolution.x / v2Resolution.y;
  
  vec3 rayOrigin = vec3(0.0, 3.0, 1.0);
  vec3 lookAt = vec3(0.0, 1.0, -1.0);
  
  vec3 z = normalize(lookAt - rayOrigin);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rayDirection = normalize(mat3(x, y, z) * vec3(uvv, radians(60.00)));
  
  vec3 lightDirection = -rayDirection;
  
  vec3 col = vec3(0.0);
  
  float t = march(rayOrigin, rayDirection);
  vec3 position = rayOrigin + t * rayDirection;
  if(t < FAR){
    col = shade(rayDirection, position, lightDirection);
    if(ID == 0){
      vec3 n = normals(position);
      vec3 refl_dir  = reflect(rayDirection, n);
      vec3 refl_orig = position + n*2.0*E;
      float refl_t = march(refl_orig, refl_dir);
      
      if(refl_t < FAR){
        vec3 refl_p = refl_orig + refl_dir * refl_t;
        col += shade(refl_dir, refl_p, lightDirection);
        col *= 0.5;
      }
    }
  }
  
  col += glow*0.8;
  
  col = fog(col, position, rayOrigin, rayDirection, lightDirection);
  
  
  vec4 pcol = vec4(0.0);
  vec2 puv = vec2(2.0/v2Resolution.x, 2.0/v2Resolution.y);
  vec4 kertoimet = vec4(0.1531, 0.12245, 0.0918, 0.051);
  pcol = texture2D(texPreviousFrame, uv) * 0.1633;
  pcol += texture2D(texPreviousFrame, uv) * 0.1633;
  for(int i = 0; i < 4; ++i){
    pcol += texture2D(texPreviousFrame, vec2(uv.x - (float(i)+1.0) * puv.y, uv.y - (float(i)+1.0) * puv.x)) * kertoimet[i] +
    texture2D(texPreviousFrame, vec2(uv.x - (float(i)+1.0) * puv.y, uv.y - (float(i)+1.0) * puv.x)) * kertoimet[i] +
    texture2D(texPreviousFrame, vec2(uv.x + (float(i)+1.0) * puv.y, uv.y + (float(i)+1.0) * puv.x)) * kertoimet[i] +
    texture2D(texPreviousFrame, vec2(uv.x + (float(i)+1.0) * puv.y, uv.y + (float(i)+1.0) * puv.x)) * kertoimet[i];
  }
  col += pcol.rgb;
  col *= 0.38;
  
  col = mix(col, texture2D(texPreviousFrame, uv).rgb, 0.8);
  
    out_color = vec4(col, 1.0);
}