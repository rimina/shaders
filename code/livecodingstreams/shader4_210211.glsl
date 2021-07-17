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
const float E = 0.001;
const float FAR = 60.0;
const int STEPS = 64;

int mat = 0;

vec3 glow = vec3(0.0);

float fft = texture(texFFTIntegrated, 1.0).r;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

void rot(inout vec2 p, float a){
  p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

void mod3(inout vec3 p, in vec3 size){
  p = mod(p + size*0.5, size) - size*0.5;
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 b = abs(p) -r;
  return length(max(b, 0.0)) + min(max(b.x, max(b.y, b.z)), 0.0);
}

float scene(vec3 p){
  vec3 pp = p;
  
  //mod3(pp, vec3(FAR, 10.0, FAR));
  rot(pp.yz, fft);
  
  for(int i = 0; i < 8; ++i){
    pp = abs(pp)-vec3(1.0, 3.0, 4.0);
    rot(pp.xy, fract(time));
    rot(pp.xz, fft+time);
    rot(pp.yz, fft);
  }
  
  
  
  float a = sphere(pp, 1.5);
  vec3 g = vec3(0.2, 0.2, 0.4) * 0.1 / (0.01 + abs(a));
  
  float b = box(pp, vec3(1.0, 1.0+cos(fract(time)+fft), 2.0*FAR));
  
  g += vec3(0.2, 0.1, 0.8) * 0.1 / (0.01 + abs(b));
  
  glow += g*0.5;
  
  float s = -sphere(p, 5.0);
  
  
  b = max(0.1, abs(b));
  a = max(0.5, abs(a));
  return max(min(a, b), s);
}


float march(vec3 ro, vec3 rd){
  vec3 p = ro;
  float t = E;
  
  for(int i = 0; i < STEPS; ++i){
    float d = scene(p);
    t +=d;
    p += rd*d;
    if(d < E || t > FAR){
      break;
    }
    
  }
  
  return t;
}


vec4 plas( vec2 v, float time )
{
	float c = 0.5 + sin( v.x * 10.0 ) + cos( sin( time + v.y ) * 20.0 );
	return vec4( sin(c * 0.2 + cos(time)), c * 0.15, cos( c * 0.1 + time / .4 ) * .25, 1.0 );
}
void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  vec3 ro = vec3(0.0, 0.0, 0.0);
  vec3 rt = vec3(0.0, 0.0, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = normalize(mat3(x,y,z)*vec3(q, radians(60.0)));
  
  float t = march(ro, rd);
  vec3 p = rd*t+ro;
  
  vec3 prev = texture(texPreviousFrame, uv).rgb;
  
  vec3 col  = vec3(0.5, 0.2, 0.7)*0.5;
  float m = mod(length(p)+4.0*fract(time), 8.0)-4.0;
  if(m > 0.0 && m > 2.0){
    col = col.bgr;
  }
  if(m < 0.0 && m < -2.0){
    col = col.brg;
  }
  
  if(t < FAR){
    col *= vec3(0.5, 0.1, 1.0)*0.5;
    
    
  }
  else{
    col = vec3(0.0);
  }
  
  //col -= (t/FAR)*0.05;
  col += glow*0.1;
  
  col = mix(col, prev, 0.5);
  
  //col = 1.0-col;

  col = smoothstep(0.2, 1.2, col);
  col = pow(col, 1.0/vec3(2.2));
  
	out_color = vec4(col, 1.0);// f + t;
}