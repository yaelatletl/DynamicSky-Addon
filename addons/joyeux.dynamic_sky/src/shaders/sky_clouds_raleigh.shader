shader_type canvas_item;

// Shader combined from two other shaders by Leo Gallatin
// Optimization and cleanup by Yael Atletl

//clouds
// USING https://www.shadertoy.com/view/XtBXDw (based on it)
// Ported to Godot by Danil S
uniform sampler2D iChannel0;
uniform sampler2D night_sky : hint_black_albedo;
uniform mat3 rotate_night_sky;

uniform float COVERAGE :hint_range(0,1); //0.5
uniform float THICKNESS :hint_range(0,100); //25.
uniform float ABSORPTION :hint_range(0,10); //1.030725
uniform float WIND_SPEED : hint_range(0,3); // 1.3 for now
uniform vec3 WIND_VEC = vec3(0.01, 0.00, 0.01); // :hint_range(0,100); //25
uniform int STEPS :hint_range(0,100); //25

uniform float EXPOSURE :hint_range(0.,1.);

//sky
// Atmosphere code from: https://github.com/wwwtyro/glsl-atmosphere
// Ported to Godot by Bastiaan Olij
uniform float saturate = 0.3;

uniform float earth_radius_km = 6371;
uniform float atmo_radius_km = 6471;
uniform float cam_height_m = 1.8;
uniform vec3 direction = vec3(0.0, 0.1, -0.5);
uniform float sun_intensity = 22.0;
uniform vec3 rayleigh_coeff = vec3(5.5, 13.0, 22.4); // we divide this by 100000
uniform float mie_coeff = 21.0; // we divide this by 100000
uniform float rayleigh_scale = 800;
uniform float mie_scale = 120;
uniform float mie_scatter_dir = 0.758;



float noise( in vec3 x )
{
    x*=0.01;
	float  z = x.z*256.0;
	vec2 offz = vec2(0.317,0.123);
	vec2 uv1 = x.xy + offz*floor(z); 
	vec2 uv2 = uv1  + offz;
	return mix(textureLod( iChannel0, uv1 ,0.0).x,textureLod( iChannel0, uv2 ,0.0).x,fract(z));
}

float fbm(vec3 pos,float lacunarity){
	vec3 p = pos;
	float
	t  = 0.51749673 * noise(p); p *= lacunarity;
	t += 0.25584929 * noise(p); p *= lacunarity;
	t += 0.12527603 * noise(p); p *= lacunarity;
	t += 0.06255931 * noise(p);
	return t;
}

float get_noise(vec3 x)
{
	float FBM_FREQ=2.76434;
	return fbm(x, FBM_FREQ);
}


vec3 ray_dir_from_uv(vec2 uv) {
	float PI = 3.14159265358979;
	vec3 dir;
	
	float x = sin(PI * uv.y);
	dir.y = cos(PI * uv.y);
	
	dir.x = x * sin(2.0 * PI * (0.5 - uv.x));
	dir.z = x * cos(2.0 * PI * (0.5 - uv.x));
	
	return dir;
}

vec2 uv_from_ray_dir(vec3 dir) {
	float PI = 3.14159265358979;
	vec2 uv;
	
	uv.y = acos(dir.y) / PI;
	
	dir.y = 0.0;
	dir = normalize(dir);
	uv.x = acos(dir.z) / (2.0 * PI);
	if (dir.x < 0.0) {
		uv.x = 1.0 - uv.x;
	}
	uv.x = 0.5 - uv.x;
	if (uv.x < 0.0) {
		uv.x += 1.0;
	}
	
	return uv;
}

vec2 rsi(vec3 r0, vec3 rd, float sr) {
	// ray-sphere intersection that assumes
	// the sphere is centered at the origin.
	// No intersection when result.x > result.y
	float a = dot(rd, rd);
	float b = 2.0 * dot(rd, r0);
	float c = dot(r0, r0) - (sr * sr);
	float d = (b*b) - 4.0*a*c;
	if (d < 0.0) return vec2(100000.0,-100000.0);
	return vec2(
		(-b - sqrt(d))/(2.0*a),
		(-b + sqrt(d))/(2.0*a)
	);
}

vec3 atmosphere(vec3 r, vec3 r0, vec3 pSun, float iSun, float rPlanet, float rAtmos, vec3 kRlh, float kMie, float shRlh, float shMie, float g) {
	float PI = 3.14159265358979;
	int iSteps = 16;
	int jSteps = 8;

	// Normalize the sun and view directions.
	pSun = normalize(pSun);
	r = normalize(r);

	// Calculate the step size of the primary ray.
	vec2 p = rsi(r0, r, rAtmos);
	if (p.x > p.y) return vec3(0,0,0);
	p.y = min(p.y, rsi(r0, r, rPlanet).x);
	float iStepSize = (p.y - p.x) / float(iSteps);

	// Initialize the primary ray time.
	float kTime = 0.0;

	// Initialize accumulators for Rayleigh and Mie scattering.
	vec3 totalRlh = vec3(0,0,0);
	vec3 totalMie = vec3(0,0,0);

	// Initialize optical depth accumulators for the primary ray.
	float iOdRlh = 0.0;
	float iOdMie = 0.0;

	// Calculate the Rayleigh and Mie phases.
	float mu = dot(r, pSun);
	float mumu = mu * mu;
	float gg = g * g;
	float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
	float pMie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));

	// Sample the primary ray.
	for (int i = 0; i < iSteps; i++) {
		// Calculate the primary ray sample position.
		vec3 iPos = r0 + r * (kTime + iStepSize * 0.5);

		// Calculate the height of the sample.
		float iHeight = length(iPos) - rPlanet;

		// Calculate the optical depth of the Rayleigh and Mie scattering for this step.
		float odStepRlh = exp(-iHeight / shRlh) * iStepSize;
		float odStepMie = exp(-iHeight / shMie) * iStepSize;

		// Accumulate optical depth.
		iOdRlh += odStepRlh;
		iOdMie += odStepMie;

		// Calculate the step size of the secondary ray.
		float jStepSize = rsi(iPos, pSun, rAtmos).y / float(jSteps);

		// Initialize the secondary ray time.
		float jTime = 0.0;

		// Initialize optical depth accumulators for the secondary ray.
		float jOdRlh = 0.0;
		float jOdMie = 0.0;

		// Sample the secondary ray.
		for (int j = 0; j < jSteps; j++) {
			// Calculate the secondary ray sample position.
			vec3 jPos = iPos + pSun * (jTime + jStepSize * 0.5);

			// Calculate the height of the sample.
			float jHeight = length(jPos) - rPlanet;

			// Accumulate the optical depth.
			jOdRlh += exp(-jHeight / shRlh) * jStepSize;
			jOdMie += exp(-jHeight / shMie) * jStepSize;

			// Increment the secondary ray time.
			jTime += jStepSize;
		}

		// Calculate attenuation.
		vec3 attn = exp(-(kMie * (iOdMie + jOdMie) + kRlh * (iOdRlh + jOdRlh)));

		// Accumulate scattering.
		totalRlh += odStepRlh * attn;
		totalMie += odStepMie * attn;

		// Increment the primary ray time.
		kTime += iStepSize;

	}

	// Calculate and return the final color.
	return iSun * (pRlh * kRlh * totalRlh + pMie * kMie * totalMie);
}

vec3 render_sky_color(vec2 uv) {
	
	uv = vec2(1.-uv.x,1.-uv.y);
	
	vec3 dir = ray_dir_from_uv(uv);
	vec3 sun_dir = normalize(direction);
	
	// determine our sky color
	vec3 color = atmosphere(
		dir
		, vec3(0.0, earth_radius_km * 100.0 + cam_height_m * 0.1, 0.0)
		, direction
		, sun_intensity
		, earth_radius_km * 100.0
		, atmo_radius_km * 100.0
		, rayleigh_coeff / 100000.0
		, mie_coeff / 100000.0
		, rayleigh_scale
		, mie_scale
		, mie_scatter_dir
	);
	
	// Apply exposure.
	color = 1.0 - exp(-1.0 * color);
	
	// Mix in night sky (already sRGB)
	color += texture(night_sky, uv).rgb * clamp(0.5-sun_dir.y, 0., 1.);
	//Old code here didn't actually draw any night sky. Now it does.
	
	//I commented this out but it basically made the sky more saturated. It wasn't very good looking but you can tweak it.
	vec3 gray = vec3(dot(vec3(0.2126,0.7152,0.0722), color));
	vec3 colorfinal = clamp( vec3(mix(color, gray, -saturate)) , 0., 1.); //This makes the skybox more saturated (it looks a little wonky if you turn it up too high)
	
	return colorfinal;
}

//Back to clouds shader

bool SphereIntersect(vec3 SpPos, float SpRad, vec3 ro, vec3 rd, out float t, out vec3 norm) {
    ro -= SpPos;
    
    float A = dot(rd, rd);
    float B = 2.0*dot(ro, rd);
    float C = dot(ro, ro)-SpRad*SpRad;
    float D = B*B-4.0*A*C;
    if (D < 0.0) return false;
    
    D = sqrt(D);
    A *= 2.0;
    float t1 = (-B+D)/A;
    float t2 = (-B-D)/A;
    if (t1 < 0.0) t1 = t2;
    if (t2 < 0.0) t2 = t1;
    t1 = min(t1, t2);
    if (t1 < 0.0) return false;
    norm = ro+t1*rd;
    t = t1;
    return true;
}

float density(vec3 pos,vec3 offset,float t){
	vec3 p = pos * .0212242 + offset;
	float dens = get_noise(p);
	
	float cov = 1. - COVERAGE;
	dens *= smoothstep (cov, cov + .05, dens);
	return clamp(dens, 0., 1.);	
}

vec4 render_clouds(vec3 ro,vec3 rd){
	
	vec3 apos=vec3(0, -450, 0);
	float arad=500.;
	vec3 WIND = normalize(WIND_VEC);
	WIND *= WIND_SPEED * TIME;
    vec3 C = vec3(0, 0, 0);
	float alpha = 0.;
    vec3 n;
    float tt;
    if(SphereIntersect(apos,arad,ro,rd,tt,n)){
        float thickness = THICKNESS;
        int steps = STEPS;
        float march_step = thickness / float(steps);
        vec3 dir_step = rd / rd.y * march_step;
        vec3 pos =n;
        float T = 1.;
        
        for (int i = 0; i < steps; i++) {
            float h = float(i) / float(steps);
            float dens = density (pos, WIND, h);
            float T_i = exp(-ABSORPTION * dens * march_step);
            T *= T_i;
            if (T < .01) break;
            C += T * (exp(h) / 1.75) *dens * march_step;
            alpha += (1. - T_i) * (1. - alpha);
            pos += dir_step;
            if (length(pos) > 1e3) break;
        }
		
		C *= EXPOSURE;
		
        return vec4(C, alpha);
    }
    return vec4(C, alpha);
}

float fbm2(in vec3 p)
{
	float f = 0.;
	f += .50000 * noise(.5 * (p+vec3(0.,0.,-TIME*0.275)));
	f += .25000 * noise(1. * (p+vec3(0.,0.,-TIME*0.275)));
	f += .12500 * noise(2. * (p+vec3(0.,0.,-TIME*0.275)));
	f += .06250 * noise(4. * (p+vec3(0.,0.,-TIME*0.275)));
	return f;
}

vec3 rotate_y(vec3 v, float angle)
{
	float ca = cos(angle); float sa = sin(angle);
	return v*mat3(
		vec3(+ca, +.0, -sa),
		vec3(+.0,+1.0, +.0),
		vec3(+sa, +.0, +ca));
}

vec3 rotate_x(vec3 v, float angle){
	float ca = cos(angle); float sa = sin(angle);
	return v*mat3(
		vec3(+1.0, +.0, +.0),
		vec3(+.0, +ca, -sa),
		vec3(+.0, +sa, +ca));
}

void panorama_uv(vec2 fragCoord, out vec3 ro,out vec3 rd, in vec2 iResolution){
    float M_PI = 3.1415926535;
    float ymul = 2.0; float ydiff = -1.0;
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x = 2.0 * uv.x - 1.0;
    uv.y = ymul * uv.y + ydiff;
    ro = vec3(0., 5., 0.);
    rd = normalize(rotate_y(rotate_x(vec3(0.0, 0.0, 1.0),-uv.y*M_PI/2.0),-uv.x*M_PI));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord, in vec2 iResolution, vec2 uv){
    vec3 ro = vec3 (0.,0.,0.);
	vec3 rd = vec3(0.);
    vec3 col=vec3(0.);

    panorama_uv(fragCoord,ro,rd,iResolution);
    
    vec3 sky = render_sky_color(uv); //for sky is gradient
    vec4 cld = vec4(0.);
	float skyPow = dot(rd, vec3(0.0, -1.0, 0.0));
    float horizonPow =1.2-pow(1.0-abs(skyPow), 5.0);
    if(rd.y>0.){
		cld=render_clouds(ro,rd);
		cld=clamp(cld,vec4(0.),vec4(1.));
		cld.rgb+=0.04*cld.rgb*horizonPow; //0.04
		//cld*=clamp((  1.0 - exp(-2.3 * pow(max((0.0), horizonPow), (2.6)))),0.,1.); //This makes the clouds fade away at the horizon, I didn't like it
	}
    col=mix(sky, cld.rgb/(0.0001+cld.a), cld.a);
    fragColor = vec4(col, 1.0);
	
}

void fragment(){
	vec2 iResolution=1./TEXTURE_PIXEL_SIZE;
	mainImage(COLOR,UV*iResolution,iResolution,UV);
}
