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
const int STEPS = 64;
const float FAR = 40.0;

int material = 0;

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p , vec3 r){
  vec3 d = abs(p)-r;
  return length(max(d, 0.0)) + min(max(max(d.x, d.y),d.z), 0.0);
}

void rot(inout vec2 p, in float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float repeat1(inout float p, float c){
  float h = 0.5*c;
  p = mod(p + h, c) - h;
  
  return floor((p + h)/h);
}

float scene(vec3 p){
  
  vec3 pp = p;
  
  repeat1(pp.x, 4.0);
  
  rot(pp.xy, time*0.5);
  
  float tunneli = box(pp, vec3(1.0, 1.0, 2.0*FAR));
  
  material = 0;
  
  return tunneli;
}

vec3 normals(vec3 p){
  vec3 eps = vec3(E, 0.0, 0.0);
  return normalize(vec3(
    scene(p+eps.xyy) - scene(p-eps.xyy),
    scene(p+eps.yxy) - scene(p-eps.yxy),
    scene(p+eps.yyx) - scene(p-eps.yyx)
  ));
}

vec3 march(vec3 rd, vec3 ro, vec3 ld, out bool hit, out vec3 p){
  p = ro;
  float t = E;
  vec3 col = vec3(0.0);
  
  float g = 0.0;
  hit = false;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    p += rd*d;
    t += d;
    
    g += 1.0;
    
    if(d < E || t >= FAR){
      break;
    }
    
  }
  
  if(t < FAR){
    if(material == 1){
      col = vec3(0.8, 0.7, 0.8);
    }
    else if(material == 0){
      col = vec3(0.4, 0.2, 0.8);
      float m = mod(p.z-time, 4.0) - 0.5;
      if(m > 0.0 && m < 2.0){
        col = col.bgr;
      }
      else if( m < 0.0 && m > -2.0){
        col = vec3(1.0) + (g/FAR);
      }
      
      
    }
    hit = true;
  }
  
  col *= vec3(1.0, 1.0, 1.2)-(t*0.1 * vec3(0.8, 0.8, 0.6));
  
  return col;
}

void main(void)
{
    vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0+2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 4.0, 2.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x, y, z) * vec3(q, radians(60.0)));
  
  bool hit = false;
  vec3 p = ro;
  vec3 col = march(rd, ro, -rd, hit, p);
  
  float fft = texture(texFFTIntegrated, 1.0).r;
  
  vec3 prev = texture(texPreviousFrame, uv*sin(uv+fft) + uv*cos(uv-fft)).rgb;
  if(!hit){
    col += (vec3(0.8, 1.0, 1.2)-prev);
  }
  else{
    vec3 n = normals(p);
    prev = texture(texPreviousFrame, uv*n.xy).rgb;
    col += prev*0.5;//vec3(0.8, 1.0, 1.2);
  }
  
  if(10.0*sin(time*0.5) > 0.0){
    prev = texture(texPreviousFrame, uv).rgb;
    col = mix(col, prev, vec3(0.2, 0.5, 0.5));
  }
  
    out_color = vec4(col, 1.0);
}