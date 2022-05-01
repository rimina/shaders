// Copyright 2021-2022 rimina.
// All rights to the likeness of the visuals reserved.

// Any individual parts of the code that produces the visuals is
// available in the public domain or licensed under the MIT license,
// whichever suits you best under your local legislation.

// This is to say: you can NOT use the code as a whole or the visual
// output it produces for any purposes without an explicit permission,
// nor can you remix or adapt the work itself without a permission.*
// You absolutely CANNOT mint any NFTs based on the Work or part of it.
// You CAN however use any individual algorithms or parts of the Code
// for any purpose, commercial or otherwise, without attribution.

// *(In practice, for most reasonable requests, I will gladly grant
//   any wishes to remix or adapt this work :)).

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

const float EPSILON = 0.001;
const int STEPS = 128;
const float FAR = 80.0;
const float PIXELR = (0.5/1280.0);

float time = fGlobalTime;

const vec3 LP = vec3(0.0, 5.2, 0.0);
const vec3 FOG = vec3(0.8, 0.0, 0.8);
float density = 0.0;

struct Material{
  vec3 lambertian;
  float li;
  vec3 specular;
  float si;
  float shininess;
  bool light;
};

Material activeMaterial;

//Noise functions from IQ and other sources that I don't exactly remember. However, not my own work.
float noise3D(vec3 p){
	return fract(sin(dot(p ,vec3(12.9898,78.233,128.852))) * 43758.5453)*2.0-1.0;
}

float simplex3D(vec3 p){
	
	float f3 = 1.0/3.0;
	float s = (p.x+p.y+p.z)*f3;
	int i = int(floor(p.x+s));
	int j = int(floor(p.y+s));
	int k = int(floor(p.z+s));
	
	float g3 = 1.0/6.0;
	float t = float((i+j+k))*g3;
	float x0 = float(i)-t;
	float y0 = float(j)-t;
	float z0 = float(k)-t;
	x0 = p.x-x0;
	y0 = p.y-y0;
	z0 = p.z-z0;
	
	int i1,j1,k1;
	int i2,j2,k2;
	
	if(x0>=y0)
	{
		if(y0>=z0){ i1=1; j1=0; k1=0; i2=1; j2=1; k2=0; } // X Y Z order
		else if(x0>=z0){ i1=1; j1=0; k1=0; i2=1; j2=0; k2=1; } // X Z Y order
		else { i1=0; j1=0; k1=1; i2=1; j2=0; k2=1; }  // Z X Z order
	}
	else 
	{ 
		if(y0<z0) { i1=0; j1=0; k1=1; i2=0; j2=1; k2=1; } // Z Y X order
		else if(x0<z0) { i1=0; j1=1; k1=0; i2=0; j2=1; k2=1; } // Y Z X order
		else { i1=0; j1=1; k1=0; i2=1; j2=1; k2=0; } // Y X Z order
	}
	
	float x1 = x0 - float(i1) + g3; 
	float y1 = y0 - float(j1) + g3;
	float z1 = z0 - float(k1) + g3;
	float x2 = x0 - float(i2) + 2.0*g3; 
	float y2 = y0 - float(j2) + 2.0*g3;
	float z2 = z0 - float(k2) + 2.0*g3;
	float x3 = x0 - 1.0 + 3.0*g3; 
	float y3 = y0 - 1.0 + 3.0*g3;
	float z3 = z0 - 1.0 + 3.0*g3;	
				 
	vec3 ijk0 = vec3(i,j,k);
	vec3 ijk1 = vec3(i+i1,j+j1,k+k1);	
	vec3 ijk2 = vec3(i+i2,j+j2,k+k2);
	vec3 ijk3 = vec3(i+1,j+1,k+1);	
            
	vec3 gr0 = normalize(vec3(noise3D(ijk0),noise3D(ijk0*2.01),noise3D(ijk0*2.02)));
	vec3 gr1 = normalize(vec3(noise3D(ijk1),noise3D(ijk1*2.01),noise3D(ijk1*2.02)));
	vec3 gr2 = normalize(vec3(noise3D(ijk2),noise3D(ijk2*2.01),noise3D(ijk2*2.02)));
	vec3 gr3 = normalize(vec3(noise3D(ijk3),noise3D(ijk3*2.01),noise3D(ijk3*2.02)));
	
	float n0 = 0.0;
	float n1 = 0.0;
	float n2 = 0.0;
	float n3 = 0.0;

	float t0 = 0.5 - x0*x0 - y0*y0 - z0*z0;
	if(t0>=0.0)
	{
		t0*=t0;
		n0 = t0 * t0 * dot(gr0, vec3(x0, y0, z0));
	}
	float t1 = 0.5 - x1*x1 - y1*y1 - z1*z1;
	if(t1>=0.0)
	{
		t1*=t1;
		n1 = t1 * t1 * dot(gr1, vec3(x1, y1, z1));
	}
	float t2 = 0.5 - x2*x2 - y2*y2 - z2*z2;
	if(t2>=0.0)
	{
		t2 *= t2;
		n2 = t2 * t2 * dot(gr2, vec3(x2, y2, z2));
	}
	float t3 = 0.5 - x3*x3 - y3*y3 - z3*z3;
	if(t3>=0.0)
	{
		t3 *= t3;
		n3 = t3 * t3 * dot(gr3, vec3(x3, y3, z3));
	}
	return 96.0*(n0+n1+n2+n3);
	
}

float fbm(vec3 p)
{
	float f;
    f  = 0.50000*simplex3D( p ); p = p*2.01;
    f += 0.25000*simplex3D( p ); p = p*2.02; //from iq
    f += 0.12500*simplex3D( p ); p = p*2.03;
    f += 0.06250*simplex3D( p ); p = p*2.04;
    f += 0.03125*simplex3D( p );
	return f;
}

float foggy(vec3 p){
  return fbm(p);
}

Material getWallMaterial(){
  Material mat;
  mat.lambertian = vec3(0.3, 0.2, 0.25);
  mat.li = 0.5;
  mat.specular = mat.lambertian*1.2;
  mat.si = 0.5;
  mat.shininess = 5.0;
  mat.light = false;
  
  return mat;
}

Material getFloorMaterial(){
  Material mat;
  mat.lambertian = vec3(0.3);
  mat.li = 1.0;
  mat.specular = mat.lambertian*0.5;
  mat.si = 1.0;
  mat.shininess = 5.0;
  mat.light = false;
  
  return mat;
}

Material getCeilingMaterial(){
  Material mat;
  mat.lambertian = vec3(0.8);
  mat.li = 0.6;
  mat.specular = mat.lambertian*1.2;
  mat.si = 0.4;
  mat.shininess = 50.0;
  mat.light = false;
  
  return mat;
}

Material getLightMaterial(){
  Material mat;
  mat.lambertian = vec3(1.0, 0.5, 0.5);
  mat.li = 1.0;
  mat.specular = mat.lambertian;
  mat.si = 1.0;
  mat.shininess = 10.0;
  mat.light = true;
  
  return mat;
}

Material getBallMaterial(){
  Material mat;
  mat.lambertian = vec3(0.8, 0.5, 0.8);
  mat.li = 1.0;
  mat.specular = vec3(0.2, 0.8, 0.8);
  mat.si = 1.0;
  mat.shininess = 10.0;
  mat.light = false;
  
  return mat;
}

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0)?-1:1;
}

float vmax(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

float plane(vec3 p, vec3 n, float d){
  return dot(p, n) + d;
}

float sphere(vec3 p, float r){
  return length(p)-r;
}

float box(vec3 p, vec3 r){
  vec3 d = abs(p)-r;
  return length(max(d, vec3(0.0))) + vmax(min(d, vec3(0.0)));
}
//---------------
//SCENE STARTS
//---------------
float scene(vec3 p){
  
  vec3 size = vec3(15.0, 10.0, 15.0);
  float room = /*plane(p, vec3(0.0, 1.0, 0.0), 1.0);*/-box(p, size);
  float ball = sphere(p-vec3(0.0, 0.0, 0.0), 1.5);
  float light = box(p-(LP+vec3(0.0, 0.25, 0.0)), vec3(0.5, 0.01, 2.5));
  
  if(room < ball && room < light/* && p.y >= -size.y*0.99 && p.y <= size.y*0.99*/){
    activeMaterial = getWallMaterial();
  }
  else if(room < ball && room < light && p.y < -size.y*0.99){
    activeMaterial = getFloorMaterial();
  }
  else if(room < ball && room < light && p.y > size.y*0.99){
    activeMaterial = getCeilingMaterial();
  }
  else if(light < room && light < ball){
    activeMaterial = getLightMaterial();
  }
  else{
    activeMaterial = getBallMaterial();
  }
  
  return min(room, min(ball, light));
}
//---------------
//SCENE ENDS
//---------------

float marchS(in vec3 ro, in vec3 rd, in float far, out bool hit, in bool inside){
  float t = EPSILON;
  float dir = inside ? -1.0 : 1.0;
  hit = false;
  for(int i = 0; i < STEPS; ++i){
    vec3 p = ro + rd*t;
    
    float dist = dir*scene(p);
    t += dist;
    
    if(abs(dist) < EPSILON || t > far){
      if(abs(dist) < EPSILON){
        hit = true;
      }
      break;
    }
  }
  return t;
}

float marchFog(vec3 ro, vec3 rd){
  float t = 0.0;
  vec3 p = ro+EPSILON*2.0;
  
  for(int i = 0; i < 12; ++i){
    float d = foggy(p);
    t += d;
    p +=rd*d;
  }
  return t;
}

vec3 normals(vec3 p){
  vec3 eps = vec3(EPSILON, 0.0, 0.0);
  return normalize(vec3(
    scene(p+eps.xyy) - scene(p-eps.xyy),
    scene(p+eps.yxy) - scene(p-eps.yxy),
    scene(p+eps.yyx) - scene(p-eps.yyx)
  ));
}

vec3 shade(vec3 n, vec3 rd, vec3 ld, Material mat){
  float diffuse = max(dot(ld, n), 0.0);
  vec3 a = reflect(n, ld);
  float nh = max(dot(rd, a), 0.0);
  float specular = pow(nh, mat.shininess);
  
  return diffuse*mat.lambertian*mat.li + specular*mat.specular*mat.si;
}

vec3 render(vec3 ro, vec3 rd, vec3 rt){
  bool phit = false;
  float t = marchS(ro, rd, FAR, phit, false);
  float dens = marchFog(ro, rd);

  vec3 col = vec3(0.0);
  if(phit){
    Material mat = activeMaterial;
    vec3 p = ro+rd*t;
    vec3 ld = normalize(LP-p);
    vec3 lp2 = vec3(5.0*sin(time*0.5), -10.0, 5.0*cos(time*0.5));
    vec3 ld2 = normalize(ro-lp2);

    vec3 n = normals(p);
    col = shade(n, rd, ld, mat);
    col *= 0.5;
    

    if(!mat.light){
      bool hit = false;
      hit = false; 
      float shadow = marchS(p+n*EPSILON*2.0, ld, FAR, hit, false);
      vec3 sp = p+ld*shadow;
      if(hit && !activeMaterial.light){
        col *= 0.25;
        dens *= 0.25;
      }
      else if(activeMaterial.light){
        col *= 1.25;
        dens *= 1.25;
      }
    }
  }
  
  col += FOG*dens*0.25;
  
  return col;
}


void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
  vec2 q = -1.0 + 2.0*uv;
  q.x *= v2Resolution.x/v2Resolution.y;
  
  //camera
  vec3 ro = vec3(4.0 * sin(time*0.5), 2.0, 4.0 * cos(time*0.5));
  ro = vec3(0.0, 1.0, 10.0);
  vec3 rt = vec3(0.0, -1.75, 1.0);
  rt = vec3(0.0, 1.2, -1.0);
  
  vec3 z = normalize(rt-ro);
  vec3 x = normalize(cross(z, vec3(0.0, 1.0, 0.0)));
  vec3 y = normalize(cross(x, z));
  
  vec3 rd = mat3(x,y,z)*vec3(q, radians(50.0));
  
  vec3 col = render(ro, rd, rt);
  
  //col += density*0.5;
  

	out_color = vec4(col, 1.0);
}