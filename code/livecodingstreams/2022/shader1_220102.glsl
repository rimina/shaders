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

float E = 0.001;
float FAR = 80.0;
int STEPS = 60;

float sphere(vec3 p, float r){
  return length(p)-r;
}

//from https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float opSmoothUnion(float d1, float d2, float k){
  float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
  return mix(d2, d1, h) - k*h*(1.0-h);
}

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float scene(vec3 p){
  
  vec3 pp = p;

  rot(pp.xz, time);
  rot(pp.xy, time);
  
  vec3 offset = vec3(1.5*sin(time-1.0+fft*1.2), 2.0*sin(time*3.0-1.0+fft), -0.4);
  float balls = sphere(pp-offset, 1.0);
  
  for(int i = 0; i < 7; ++i){
    offset = vec3(1.5*sin(time+i+fft*1.2), 2.0*sin(time*3.0+i+fft), 0.4*-i);
    
    float b = sphere(pp-offset, 1.0);
    balls = opSmoothUnion(b, balls, 0.8);
    
    rot(pp.xy, fft);
    rot(pp.yz, time);
    
  }
  
  return balls;
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

vec3 shade(vec3 rd, vec3 p, vec3 ld){
  vec3 n = normals(p);
  float lambertian = max(dot(n, ld), 0.0);
  float a = max(dot(reflect(rd, ld), n), 0.0);
  float specular = pow(a, 10.0);
  
  vec3 col1 = vec3(0.3, 0.1, 0.8);
  vec3 col2 = vec3(1.0, 0.863, 0.745);
  
  vec3 pp = p;
  rot(pp.xy, time);
  vec2 m = mod(pp.xy, 4.0)-2.0;
  if(m.x > 0.0 && m.x > 1.5){
    col1 = vec3(0.8, 0.0, 0.5);
  }
  else if(m.y < 0.0 && m.y > -0.5){
    col1 = col1.brg;
  }
  else if(m.x < 0.0 && m.x > -0.5){
    col1 = vec3(0.0, 0.6, 0.9);
  }
  else if(m.y > 0.0 && m.y > 1.5){
    col1 = vec3(0.0, 0.7, 0.1);
  }
  
  
  //1.0, 0.863, 0.745
  return col1*lambertian*0.5 + col2*specular*0.8;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0 * uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(5.0*sin(time*0.9), 3.0, 6.0*cos(time*0.9));
  vec3 rt = vec3(0.0, -0.75, 0.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z) * vec3(q, 1.0/radians(60.0)));
  
  vec3 col = vec3(0.01, 0.00, 0.05);
  
  vec3 ld = normalize(ro-rt);
  
  float t = march(ro, rd);
  vec3 p = ro + rd*t;
  
  if(t < FAR){
    col = shade(rd, p, ld);
  }
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  col = mix(col, prev, 0.51);
  

	out_color = vec4(col, 1.0);
}