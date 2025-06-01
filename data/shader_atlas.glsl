//example of some shaders compiled
plain basic.vs plain.fs
flat basic.vs flat.fs
texture basic.vs texture.fs
skybox basic.vs skybox.fs
depth quad.vs depth.fs
multi basic.vs multi.fs
compute test.cs
phong basic.vs phong.fs
quad quad.vs quad.fs
light_volume basic.vs phong_sphere.fs
brdf basic.vs brdf.fs
ssao quad.vs ssao.fs
ssao_blur quad.vs ssao_blur.fs
black_hole quad.vs blackhole.fs
blackhole3d blackhole3d.vs blackhole3d.fs
black_hole2D quad.vs blackhole2D.fs
ring blackhole3d.vs ring.fs


\blackhole2D.fs
#version 330 core

in vec2 v_uv;
out vec4 FragColor;


uniform vec3 u_blackhole_world_pos;
uniform float u_blackhole_radius;
uniform float u_distortion_strength;
uniform float u_effect_radius;

uniform sampler2D u_scene_texture; // G-buffer color texture
uniform sampler2D u_depth_texture; // G-buffer depth texture


uniform vec2 u_inv_screen_size; // Inverse of screen size for UV calculations
uniform mat4 u_inv_viewprojection; // Inverse view-projection matrix for world position calculations
uniform mat4 u_viewprojection; // View-projection matrix for converting world position to clip space

void main()
{
	
	//Assigment 4 getting data from gbuffer
	vec2 uv = gl_FragCoord.xy * u_inv_screen_size;

	float depth = texture(u_depth_texture, uv).r;
	float depth_clip = depth * 2.0 - 1.0;

	vec2 uv_clip = uv * 2.0 - 1.0;
	vec4 clip_coords = vec4(uv_clip.x, uv_clip.y, depth_clip,1.0);

	vec4 not_norm_world_pos = u_inv_viewprojection * clip_coords;

	vec3 world_pos = not_norm_world_pos.xyz / not_norm_world_pos.w;

    
	// Convert world pos to clip space
    vec4 clip = u_viewprojection * vec4(u_blackhole_world_pos, 1.0);
    vec3 ndc = clip.xyz / clip.w;

    // Convert NDC to screen-space pixel coords
    vec2 blackhole_screen_pos = (ndc.xy * 0.5 + 0.5) / u_inv_screen_size;

    // Get this pixel's screen-space position
    vec2 frag_screen_pos = gl_FragCoord.xy;

    // Distance from black hole center
    float dist = distance(frag_screen_pos, blackhole_screen_pos);

    // If inside black circle radius, return black
	dist = length(blackhole_screen_pos - frag_screen_pos);
    if (dist < u_blackhole_radius*3) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
	if (dist < u_blackhole_radius*3.1) {
        FragColor = vec4(1.0f, 0.8f, 0.3f,1.0);
        return;
    }
	
	dist = length(world_pos - u_blackhole_world_pos);

	dist = length(blackhole_screen_pos - frag_screen_pos);


	//distortion all screen
	//float factor = (u_blackhole_radius - dist) / u_blackhole_radius;
    float strength = u_distortion_strength;// * factor;

    // Approximate direction of distortion in screen-space (can be tweaked)
    vec2 dir = normalize(frag_screen_pos - blackhole_screen_pos);
	//uv = frag_screen_pos;
	vec2 right = vec2(dir.y, -dir.x);

    uv += dir * strength/dist*dist * 0.2;

	uv += right * u_distortion_strength * 0.3/dist*dist * 0.2;
	
	//2D ring
	
		// Ring blending with scene
	vec3 ring_color = vec3(1.0f, 0.8f, 0.3f);
	float ring_inner_radius = u_effect_radius * 100.0 + 10.0;
	float ring_thickness = u_effect_radius * 20.0;
	float ring_outer_radius = ring_inner_radius + ring_thickness;
	float ring_outer_radius_negative = ring_inner_radius - ring_thickness;


	vec4 color = texture(u_scene_texture, uv);

	if (dist > ring_inner_radius && dist < ring_outer_radius) {
		float t = (dist - ring_inner_radius) / ring_thickness;
		float falloff = 1.0 - t;

		float intensity_boost = 0.9;
		vec3 blended_color = mix(color.rgb, ring_color * intensity_boost, falloff);
		color.rgb = blended_color;
	}
	if (dist > ring_outer_radius_negative && dist < ring_inner_radius) {
		float t = (dist - ring_outer_radius_negative) / ring_thickness;
		float falloff = t;

		float intensity_boost = 0.9;
		vec3 blended_color = mix(color.rgb, ring_color * intensity_boost, falloff);
		color.rgb = blended_color;
	}
	
	


	dist = length(blackhole_screen_pos - frag_screen_pos);
	color -= vec4(u_distortion_strength *25 /dist); //black aura
	

    FragColor = color;
}

\ring.fs
#version 330 core

in vec3  v_world_position;
in vec3  v_normal;
in vec2  v_uv;

uniform vec3  u_camera_position;
uniform vec3  u_ring_color_inner;
uniform vec3  u_ring_color_outer;
uniform float u_ring_thickness;
uniform float u_ring_falloff;

out vec4 fragColor;

float fresnel_term(vec3 N, vec3 V) {
    return pow(1.0 - max(dot(N, V), 0.0), 3.0);
}

void main() {
    vec3 view_dir = normalize(u_camera_position - v_world_position);
    vec3 N = normalize(v_normal);

    float f = fresnel_term(N, view_dir);

    float radial = abs(v_uv.y - 0.5) * 2.0;
    float t = clamp((radial - (1.0 - u_ring_thickness)) / u_ring_thickness, 0.0, 1.0);

    vec3 base_color = mix(u_ring_color_inner, u_ring_color_outer, t);
    float alpha = exp(-pow((t - 0.5) * 2.0, 2.0) * u_ring_falloff);

    vec3 final_color = base_color * (0.4 + 0.6 * f);
    fragColor = vec4(final_color, alpha * 0.9);

    if (fragColor.a < 0.01) discard;
}


\blackhole3d.vs
#version 330 core

in vec3 a_vertex;
in vec3 a_normal;
in vec2 a_coord;

uniform mat4 u_model;
uniform mat4 u_viewprojection;

out vec3 v_world_position;
out vec3 v_normal;
out vec4 v_color;
out vec2 v_uv;

void main() {
    vec4 world_pos = u_model * vec4(a_vertex, 1.0);
    v_world_position = world_pos.xyz;
    v_normal = (u_model * vec4(a_normal, 0.0)).xyz;
    v_color = vec4(1.0); // not used
    v_uv = a_coord;

    gl_Position = u_viewprojection * world_pos;
}

\blackhole3d.fs
#version 330 core

in vec3 v_world_position;
in vec3 v_normal;

out vec4 FragColor;

uniform vec3 u_blackhole_world_pos;
uniform vec3 u_camera_position;
uniform float u_distortion_strength;

float fresnel(vec3 N, vec3 V) {
    return pow(1.0 - max(dot(N, V), 0.0), 3.0);
}

void main() {
    vec3 view_dir = normalize(u_camera_position - v_world_position);
    vec3 normal = normalize(v_normal);

    float edge = fresnel(normal, view_dir);
    vec3 glow_color = mix(vec3(1.0, 0.6, 0.2), vec3(1.0, 0.9, 0.6), edge);
    glow_color *= edge * u_distortion_strength * 3.0;

    FragColor = vec4(glow_color, 1.0);
}


\blackhole.fs
#version 330 core

in vec2 v_uv;
out vec4 FragColor;

uniform vec3  u_blackhole_world_pos;
uniform float u_blackhole_radius;
uniform float u_distortion_strength;
uniform float u_effect_radius;

uniform sampler2D u_scene_texture;
uniform sampler2D u_depth_texture;

uniform vec2  u_inv_screen_size;
uniform mat4  u_inv_viewprojection;
uniform mat4  u_viewprojection;
uniform vec3  u_camera_position;

float calcGravitationalBend(float r_px, float schwarzschild_px) {
    float C = schwarzschild_px * 1.0;
    float invR = 1.0 / max(r_px, schwarzschild_px * 0.5);
    float rawAngle = C * invR;
    return clamp(rawAngle, -1.57, 1.57);
}

void main() {
    vec2 uv = gl_FragCoord.xy * u_inv_screen_size;

    // 1) Reconstrucción de posición mundial (si la necesitas para debug)
    float depth = texture(u_depth_texture, uv).r;
    float depth_clip = depth * 2.0 - 1.0;
    vec2 uv_clip = uv * 2.0 - 1.0;
    vec4 clip_coords = vec4(uv_clip, depth_clip, 1.0);
    vec4 view_pos = u_inv_viewprojection * clip_coords;
    vec3 world_pos = view_pos.xyz / view_pos.w;

    // 2) Posición del agujero en pantalla
    vec4 bh_clip = u_viewprojection * vec4(u_blackhole_world_pos, 1.0);
    vec2 bh_ndc = bh_clip.xy / bh_clip.w;
    vec2 bh_uv = bh_ndc * 0.5 + 0.5;
    vec2 bh_px = bh_uv / u_inv_screen_size;
    vec2 frag_px = gl_FragCoord.xy;
    float dist_px = length(frag_px - bh_px);

    // 3) Gravitational bending (igual que antes)
    float schwarzschild_px = u_blackhole_radius * 3.0;
    vec2 dir_px = normalize(frag_px - bh_px);
    float theta = atan(dir_px.y, dir_px.x);
    float bend_angle = calcGravitationalBend(dist_px, schwarzschild_px);
    float new_theta = theta + bend_angle;
    vec2 bent_px = bh_px + dist_px * vec2(cos(new_theta), sin(new_theta));
    vec2 bent_uv = bent_px * u_inv_screen_size;

    // 4) Extra lensing
    vec2 right_n = vec2(dir_px.y, -dir_px.x);
    float lens_radius_px = schwarzschild_px + u_effect_radius * 60.0;
    float falloff = 1.0 - smoothstep(schwarzschild_px, lens_radius_px, dist_px);
    vec2 scene_uv = bent_uv;
    scene_uv += dir_px  * (u_distortion_strength * 0.15 * falloff);
    scene_uv += right_n * (u_distortion_strength * 0.25 * falloff);

    // 5) Muestra el fondo distorsionado
    vec4 baseColor = texture(u_scene_texture, scene_uv);

    // 6) Ya no pintamos anillos 2D aquí. Solo devolvemos baseColor:
    FragColor = baseColor;
}


\PBR_functions
vec3 fresnelSchlick(vec3 V, vec3 H, vec3 F0) {
    float dotHV = max(dot(H, V), 0.0);
    return F0 + (1.0 - F0) * pow(1.0 - dotHV, 5.0);
}
float distributionGGX(vec3 N, vec3 H, float roughness) {
	float PI = 3.1415926535897932384626433832795;
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    return a2 / (PI * denom * denom);
}
float geometrySchlickGGX(float NdotV, float roughness) {
    float k = (roughness * roughness) / 2.0; 

    return NdotV / (NdotV * (1.0 - k) + k);
}

\brdf.fs
#version 330 core

#define MAX_LIGHTS 100
#define MAX_SHADOW_CASTERS 4

#include "PBR_functions"

mat3 cotangentFrame(vec3 N, vec3 p, vec2 uv) {
  // get edge vectors of the pixel triangle
  vec3 dp1 = dFdx(p);
  vec3 dp2 = dFdy(p);
  vec2 duv1 = dFdx(uv);
  vec2 duv2 = dFdy(uv);

  // solve the linear system
  vec3 dp2perp = cross(dp2, N);
  vec3 dp1perp = cross(N, dp1);
  vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
  vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

  // construct a scale-invariant frame 
  float invmax = 1.0 / sqrt(max(dot(T,T), dot(B,B)));
  return mat3(normalize(T * invmax), normalize(B * invmax), N);
}

vec3 perturbNormal(vec3 N, vec3 WP, vec2 uv, vec3 normal_pixel)
{
	normal_pixel = normal_pixel * 255./127. - 128./127.;
	mat3 TBN = cotangentFrame(N, WP, uv);
	return normalize(TBN * normal_pixel);
}

// Inputs from vertex shader
in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

// Camera info
uniform vec3 u_camera_position;

// Material and textures
uniform vec4 u_color;
uniform sampler2D u_texture;
uniform sampler2D u_texture_normal;
uniform sampler2D u_texture_metallic_roughness;

// Light info
uniform int u_numLights;
uniform vec3 u_light_pos[MAX_LIGHTS];
uniform vec3 u_light_color[MAX_LIGHTS];	
uniform float u_light_intensity[MAX_LIGHTS];
uniform int u_light_type[MAX_LIGHTS]; // 0 = point, 1 = directional, 2 = spotlight

// Optional ambient light
uniform bool u_apply_ambient;
uniform vec3 u_ambient_light;
uniform float u_shininess;

// Spotlight data
uniform vec3 u_light_direction[MAX_LIGHTS];
uniform vec2 u_light_cone_info[MAX_LIGHTS]; // x = min angle, y = max angle (in radians)

// Shadow mapping
uniform sampler2D u_shadow_maps[MAX_SHADOW_CASTERS];
uniform mat4 u_shadow_vps[MAX_SHADOW_CASTERS];
uniform float u_shadow_bias;
uniform int    u_numShadowCasters;

// Alpha discard
uniform float u_alpha_cutoff;

out vec4 FragColor; // Final color output
   // color buffer
layout(location = 1) out vec4 NormalColor;  // normal buffer

void main() {
    // Get the base color
    vec4 tex_color = texture(u_texture, v_uv);
    vec4 color = tex_color * u_color;

	// Discard the fragment if its alpha is below the cutoff (transparent)
    if (color.a < u_alpha_cutoff)
        discard;

    vec3 base_color = color.rgb;

	// Store base color for gFBO

    // Ambient term calculation
    vec3 ambient = vec3(0.0);
	if (u_apply_ambient) {
		ambient = u_ambient_light * base_color;
	}

	// Initialize lighting accumulators
    vec3 diffuse_total = vec3(0.0);
    vec3 specular_total = vec3(0.0);

	// Get the perturbed normal from the normal map
    vec3 normal_pixel = texture(u_texture_normal, v_uv).rgb;
    vec3 N = perturbNormal(normalize(v_normal), v_world_position, v_uv, normal_pixel);
    vec3 V = normalize(u_camera_position - v_world_position);

	// Loop through all lights and calculate their contribution
    for (int i = 0; i < u_numLights; i++) {

        float shadow_factor = 1.0; // Default: no shadow

		// Calculate shadow for shadow-casting lights
		if (i < u_numShadowCasters) {
            vec4 proj_pos     = u_shadow_vps[i] * vec4(v_world_position, 1.0);
            float real_depth  = (proj_pos.z - u_shadow_bias) / proj_pos.w;
            proj_pos /= proj_pos.w;
            vec2 shadow_uv    = proj_pos.xy * 0.5 + 0.5;
            float shadow_depth = texture(u_shadow_maps[i], shadow_uv).x;
            float current_depth = real_depth * 0.5 + 0.5;

			// Compare the fragment depth with the shadow depth to apply shadowing
            if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 &&
                shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0)
            {
                if (current_depth > shadow_depth)
                    shadow_factor = 0.0;
            }
        }


		// Light direction and attenuation calculation
        vec3 L;
        float attenuation = 1.0;
		
		// Point light calculation
        if (u_light_type[i] == 0) {
            L = normalize(u_light_pos[i] - v_world_position);
            float distance = length(u_light_pos[i] - v_world_position);
            attenuation = 1.0 / (distance * distance);
        }
		// Directional light calculation
        else if (u_light_type[i] == 1) { // Luz direccional
            L = normalize(u_light_direction[i]);
            attenuation = 1.0;
        }
		// Spotlight calculation
		else if (u_light_type[i] == 2) { // Spotlight
  			L = normalize(u_light_pos[i] - v_world_position);
            float distance = length(u_light_pos[i] - v_world_position);
    
			vec3 D = normalize(u_light_direction[i]);
			float cos_angle = dot(L, D); 

			float cos_alpha_min = cos(u_light_cone_info[i].x);
			float cos_alpha_max = cos(u_light_cone_info[i].y);

			float spot_factor = 0.0;
			if (cos_angle >= cos_alpha_max) {
				spot_factor = clamp(
					(cos_angle - cos_alpha_max) / (cos_alpha_min - cos_alpha_max),
					0.0, 1.0
				);
			}

			attenuation = (1.0 / (distance * distance)) * spot_factor;
		}
		//BDRF
		float NdotL = max(dot(N, L), 0.0);
		vec3 H = normalize(V + L);
		float NdotV = max(dot(N, V), 0.0);
		float NdotH = max(dot(N, H), 0.0);
		float VdotH = max(dot(V, H), 0.0);
		vec3 Mer = texture(u_texture_metallic_roughness, v_uv).rgb;
		vec3 albedo = tex_color.rgb;
		float roughness = Mer.g;

		vec3 F0 = mix(vec3(0.04), albedo, Mer.b);
		vec3 F = fresnelSchlick(V, H, F0);
		float D = distributionGGX(N, H, roughness);
		float G = geometrySchlickGGX(NdotV, roughness);
		vec3 spec = (F * D * G) / max(4.0 * NdotV * NdotL, 0.001);

		// Phong shading calculations: Diffuse and specular
		float N_dot_L = clamp(dot(N, L), 0.0, 1.0);
		vec3 R = reflect(L, N); // Reflection vector
		float R_dot_V = clamp(dot(R, V), 0.0, 1.0); // View reflection term

		// Diffuse and specular lighting contributions
		vec3 light_diffuse = base_color * N_dot_L * u_light_color[i] * u_light_intensity[i] * attenuation;
		vec3 light_specular = spec * u_light_color[i] * u_light_intensity[i] * attenuation * N_dot_L;
		float PI = 3.1415926535897932384626433832795;
		light_diffuse = light_diffuse / PI;
		// Apply shadow factor to light if shadow exists
		if (i < u_numShadowCasters &&(u_light_type[i]==1 || u_light_type[i]==2) ){
			light_diffuse  *= shadow_factor;
			light_specular *= shadow_factor;
		}

        // Accumulate diffuse and specular contributions
		diffuse_total += light_diffuse;
		specular_total += light_specular;
			
    }

	// Final color calculation with ambient, diffuse, and specular components
	vec3 final_color = ambient + (diffuse_total + specular_total);
    FragColor = vec4(final_color, color.a);
	NormalColor = vec4(v_normal * 0.5 + 0.5,1.0); // Store normal in NormalColor for debugging
}

\test.cs
#version 430 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
void main() 
{
	vec4 i = vec4(0.0);
}

\basic.vs

#version 330 core

in vec3 a_vertex;
in vec3 a_normal;
in vec2 a_coord;
in vec4 a_color;

uniform vec3 u_camera_pos;

uniform mat4 u_model;
uniform mat4 u_viewprojection;

//this will store the color for the pixel shader
out vec3 v_position;
out vec3 v_world_position;
out vec3 v_normal;
out vec2 v_uv;
out vec4 v_color;

uniform float u_time;

void main()
{	
	//calcule the normal in camera space (the NormalMatrix is like ViewMatrix but without traslation)
	v_normal = (u_model * vec4( a_normal, 0.0) ).xyz;
	
	//calcule the vertex in object space
	v_position = a_vertex;
	v_world_position = (u_model * vec4( v_position, 1.0) ).xyz;
	
	//store the color in the varying var to use it from the pixel shader
	v_color = a_color;

	//store the texture coordinates
	v_uv = a_coord;

	//calcule the position of the vertex using the matrices
	gl_Position = u_viewprojection * vec4( v_world_position, 1.0 );
}

\quad.vs

#version 330 core

in vec3 a_vertex;
in vec3 a_normal;
in vec2 a_coord;
in vec4 a_color;
out vec2 v_uv;


uniform mat4 u_model;
uniform mat4 u_viewprojection;


//this will store the color for the pixel shader
out vec3 v_position;
out vec3 v_world_position;
out vec3 v_normal;
out vec4 v_color;

uniform float u_time;

void main()
{	

	v_normal = (u_model * vec4( a_normal, 0.0) ).xyz;
	
	//calcule the vertex in object space
	v_position = a_vertex;
	v_world_position = (u_model * vec4( v_position, 1.0) ).xyz;
	
	//store the color in the varying var to use it from the pixel shader
	v_color = a_color;

	v_uv = a_coord;
	gl_Position = vec4( a_vertex, 1.0 );
}

\quad.fs
#version 330 core

#define MAX_LIGHTS 100
#define MAX_SHADOW_CASTERS 4


#include "PBR_functions"

mat3 cotangentFrame(vec3 N, vec3 p, vec2 uv) {
  // get edge vectors of the pixel triangle
  vec3 dp1 = dFdx(p);
  vec3 dp2 = dFdy(p);
  vec2 duv1 = dFdx(uv);
  vec2 duv2 = dFdy(uv);

  // solve the linear system
  vec3 dp2perp = cross(dp2, N);
  vec3 dp1perp = cross(N, dp1);
  vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
  vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

  // construct a scale-invariant frame 
  float invmax = 1.0 / sqrt(max(dot(T,T), dot(B,B)));
  return mat3(normalize(T * invmax), normalize(B * invmax), N);
}

vec3 perturbNormal(vec3 N, vec3 WP, vec2 uv, vec3 normal_pixel)
{
	normal_pixel = normal_pixel * 255./127. - 128./127.;
	mat3 TBN = cotangentFrame(N, WP, uv);
	return normalize(TBN * normal_pixel);
}

//Decoding for normals
vec3 decodeNormal(vec2 enc)
{
	float angle = (enc.x * 2.0 - 1.0) * 3.1415926535897932384626433832795;
	float z = enc.y * 2.0 - 1.0;

	float xyLen = sqrt(max(0.0,1.0 - z * z));

	float x = cos(angle) * xyLen;
	float y = sin(angle) * xyLen;
	return normalize(vec3(x,y,z));
}

// Inputs from vertex shader
in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

// Camera info
uniform vec3 u_camera_position;

// Material and textures
uniform vec4 u_color;
uniform sampler2D u_texture;
uniform sampler2D u_texture_normal;
uniform sampler2D u_texture_metallic_roughness;

// Light info
uniform int u_numLights;
uniform vec3 u_light_pos[MAX_LIGHTS];
uniform vec3 u_light_color[MAX_LIGHTS];	
uniform float u_light_intensity[MAX_LIGHTS];
uniform int u_light_type[MAX_LIGHTS]; // 0 = point, 1 = directional, 2 = spotlight

// Optional ambient light
uniform bool u_apply_ambient;
uniform vec3 u_ambient_light;
uniform float u_shininess;

// Spotlight data
uniform vec3 u_light_direction[MAX_LIGHTS];
uniform vec2 u_light_cone_info[MAX_LIGHTS]; // x = min angle, y = max angle (in radians)

// Shadow mapping
uniform sampler2D u_shadow_maps[MAX_SHADOW_CASTERS];
uniform mat4 u_shadow_vps[MAX_SHADOW_CASTERS];
uniform float u_shadow_bias;
uniform int    u_numShadowCasters;

layout(location = 0) out vec4 FragColor;

// Alpha discard
uniform float u_alpha_cutoff;

//out vec4 FragColor; // Final color output

uniform vec2 u_inv_screen_size;
//Unifroms from gbuffer

uniform sampler2D u_gbuffer_color;
uniform sampler2D u_gbuffer_normal;
uniform sampler2D u_gbuffer_depth;

uniform sampler2D u_gbuffer_baked_ao;  
uniform sampler2D u_ssao_tex;         


uniform samplerCube u_sky_text;

uniform mat4 u_inv_viewprojection;

uniform bool u_first_pass;

uniform bool u_compressnormals;

uniform bool u_brdf;

void main() {

	//Assigment 4 getting data from gbuffer
	vec2 uv = gl_FragCoord.xy * u_inv_screen_size;

	float ssao   = texture(u_ssao_tex,         uv).r;
    float baked  = texture(u_gbuffer_baked_ao, uv).r;
	float ao = min(ssao, baked);

	float depth = texture(u_gbuffer_depth, uv).r;
	float depth_clip = depth * 2.0 - 1.0;

	vec2 uv_clip = uv * 2.0 - 1.0;
	vec4 clip_coords = vec4(uv_clip.x, uv_clip.y, depth_clip,1.0);

	vec4 not_norm_world_pos = u_inv_viewprojection * clip_coords;

	vec3 world_pos = not_norm_world_pos.xyz / not_norm_world_pos.w;

    // Get the base color
    vec4 tex_color = texture(u_texture, v_uv);
    vec4 color = tex_color * u_color;
	color = texture(u_gbuffer_color,uv);


	// Discard the fragment if its alpha is below the cutoff (transparent)
    if (color.a < u_alpha_cutoff)
        discard;

    vec3 base_color = color.rgb;

	// Store base color for gFBO

    // Ambient term calculation
    vec3 ambient = vec3(0.0);
	if (u_apply_ambient && u_first_pass) {
		ambient = u_ambient_light * base_color * ao;
	}

	// Initialize lighting accumulators
    vec3 diffuse_total = vec3(0.0);
    vec3 specular_total = vec3(0.0);

	// Get the perturbed normal from the normal map
    vec3 normal_pixel = texture(u_gbuffer_normal, uv).rgb;
	if(u_compressnormals){
		normal_pixel = decodeNormal(normal_pixel.xy);
	}
	


    vec3 N = normal_pixel * 2.0 - 1.0;
    vec3 V = normalize(u_camera_position - world_pos);

	// Loop through all lights and calculate their contribution
    for (int i = 0; i < u_numLights; i++) {

        float shadow_factor = 1.0; // Default: no shadow

		// Calculate shadow for shadow-casting lights
		if (i < u_numShadowCasters) {
            vec4 proj_pos     = u_shadow_vps[i] * vec4(world_pos, 1.0);
            float real_depth  = (proj_pos.z - u_shadow_bias) / proj_pos.w;
            proj_pos /= proj_pos.w;
            vec2 shadow_uv    = proj_pos.xy * 0.5 + 0.5;
            float shadow_depth = texture(u_shadow_maps[i], shadow_uv).x;
            float current_depth = real_depth * 0.5 + 0.5;

			// Compare the fragment depth with the shadow depth to apply shadowing
            if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 &&
                shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0)
            {
                if (current_depth > shadow_depth)
                    shadow_factor = 0.0;
            }
        }


		// Light direction and attenuation calculation
        vec3 L;
        float attenuation = 1.0;
		
		// Point light calculation
        if (u_light_type[i] == 0 && !u_first_pass) {
            L = normalize(u_light_pos[i] - world_pos);
            float distance = length(u_light_pos[i] - world_pos);
            attenuation = 1.0 / (distance * distance);
        }
		// Directional light calculation
        else if (u_light_type[i] == 1 && u_first_pass) { // Luz direccional
            L = normalize(u_light_direction[i]);
            attenuation = 1.0;
        }
		// Spotlight calculation
		else if (u_light_type[i] == 2 && !u_first_pass) { // Spotlight
  			L = normalize(u_light_pos[i] - world_pos);
            float distance = length(u_light_pos[i] - world_pos);
    
			vec3 D = normalize(u_light_direction[i]);
			float cos_angle = dot(L, D); 

			float cos_alpha_min = cos(u_light_cone_info[i].x);
			float cos_alpha_max = cos(u_light_cone_info[i].y);

			float spot_factor = 0.0;
			if (cos_angle >= cos_alpha_max) {
				spot_factor = clamp(
					(cos_angle - cos_alpha_max) / (cos_alpha_min - cos_alpha_max),
					0.0, 1.0
				);
			}

			attenuation = (1.0 / (distance * distance)) * spot_factor;
		}
		//BDRF
		float NdotL = max(dot(N, L), 0.0);
		vec3 H = normalize(V + L);
		float NdotV = max(dot(N, V), 0.0);
		float NdotH = max(dot(N, H), 0.0);
		float VdotH = max(dot(V, H), 0.0);
		float Mer = texture(u_gbuffer_normal, uv).a;
		vec3 albedo = tex_color.rgb;
		float roughness = texture(u_gbuffer_color, uv).a;

		vec3 F0 = mix(vec3(0.04), albedo, Mer);
		vec3 F = fresnelSchlick(V, H, F0);
		float D = distributionGGX(N, H, roughness);
		float G = geometrySchlickGGX(NdotV, roughness);
		vec3 spec = (F * D * G) / max(4.0 * NdotV * NdotL, 0.001);

		// Phong shading calculations: Diffuse and specular
		float N_dot_L = clamp(dot(N, L), 0.0, 1.0);
		vec3 R = reflect(-L, N); // Reflection vector
		float R_dot_V = clamp(dot(R, V), 0.0, 1.0); // View reflection term

		// Diffuse and specular lighting contributions
		vec3 light_diffuse = vec3(0.0);
		vec3 light_specular = vec3(0.0);
		if(!u_brdf){
			light_diffuse = base_color * N_dot_L * u_light_color[i] * u_light_intensity[i] * attenuation;
			light_specular = base_color * u_light_color[i] * u_light_intensity[i] * attenuation * pow(R_dot_V, u_shininess);
		}
		else{
			light_diffuse = base_color * N_dot_L * u_light_color[i] * u_light_intensity[i] * attenuation;
			light_specular = spec * u_light_color[i] * u_light_intensity[i] * attenuation * N_dot_L;
			float PI = 3.1415926535897932384626433832795;
			light_diffuse = light_diffuse / PI;
		}
		

		// Apply shadow factor to light if shadow exists
		if (i < u_numShadowCasters &&(u_light_type[i]==1 || u_light_type[i]==2) ){
			light_diffuse  *= shadow_factor;
			light_specular *= shadow_factor;
		}

        // Accumulate diffuse and specular contributions
		if(u_first_pass && u_light_type[i] == 1){
			diffuse_total += light_diffuse;
			specular_total += light_specular;
		}
		
			
    }

	if(depth >= 1.0 && u_first_pass)
	{
		// This is the skybox, don't shade
		vec3 E = world_pos - u_camera_position;
		vec4 skybox_color = texture( u_sky_text, E );
		FragColor = skybox_color;
		return;
	}

	// Final color calculation with ambient, diffuse, and specular components
	vec3 final_color = ambient + (diffuse_total + specular_total);
    FragColor = vec4(final_color, color.a);
	
}




\flat.fs

#version 330 core

uniform vec4 u_color;

out vec4 FragColor;

void main()
{
	FragColor = u_color;
}


\texture.fs

#version 330 core

in vec3 v_position;
in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;
in vec4 v_color;

uniform vec4 u_color;
uniform sampler2D u_texture;
uniform float u_time;
uniform float u_alpha_cutoff;
uniform mat4 u_model;
uniform bool u_transparent;
uniform bool u_compressnormals;

uniform float u_roughness;
uniform float u_metallic;

uniform sampler2D u_texture_metallic_roughness;


vec2 encode (vec3 n)
{
    float kPI = 3.1415926535897932384626433832795;
	float angle = atan(n.y,n.x);
	float z = n.z;

    return vec2((angle/kPI +1.0) * 0.5, (z + 1.0) * 0.5);
}

float dither4x4(vec2 position, float brightness)
{
  int x = int(mod(position.x, 4.0));
  int y = int(mod(position.y, 4.0));
  int index = x + y * 4;
  float limit = 0.0;

  if (x < 8) {
    if (index == 0) limit = 0.0625;
    if (index == 1) limit = 0.5625;
    if (index == 2) limit = 0.1875;
    if (index == 3) limit = 0.6875;
    if (index == 4) limit = 0.8125;
    if (index == 5) limit = 0.3125;
    if (index == 6) limit = 0.9375;
    if (index == 7) limit = 0.4375;
    if (index == 8) limit = 0.25;
    if (index == 9) limit = 0.75;
    if (index == 10) limit = 0.125;
    if (index == 11) limit = 0.625;
    if (index == 12) limit = 1.0;
    if (index == 13) limit = 0.5;
    if (index == 14) limit = 0.875;
    if (index == 15) limit = 0.375;
  }

  return brightness < limit ? 0.0 : 1.0;
}

layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec4 NormalColor;
layout(location=2) out vec4 BakedAO;

void main()
{
	vec2 uv = v_uv;
	vec4 color = u_color;
	color *= texture( u_texture, v_uv );

	if (u_transparent) {
        // Apply dithering instead of alpha cutoff
        if (dither4x4(gl_FragCoord.xy, color.a) == 0.0)
            discard;
    } else {
        // Normal alpha cutoff for opaque objects
        if (color.a < u_alpha_cutoff)
            discard;
    }

	vec3 normal = v_normal;
	normal = normalize(normal);
	FragColor = color;
	normal = normal * 0.5 + 0.5;
	NormalColor = vec4(normal,u_roughness);
	if(u_compressnormals){
		vec2 compressnormal = encode(normal);
		NormalColor = vec4(compressnormal, 0.0,u_metallic);
	}

	float baked = texture(u_texture_metallic_roughness, v_uv).r;
	BakedAO = vec4(baked, baked, baked, 1.0);
	
}


\skybox.fs

#version 330 core

in vec3 v_position;
in vec3 v_world_position;

uniform samplerCube u_texture;
uniform vec3 u_camera_position;
layout(location = 0) out vec4 FragColor;    // color buffer

uniform sampler2D u_gbuffer_depth;
uniform vec2 u_inv_screen_size;

void main()
{
	vec3 E = v_world_position - u_camera_position;
	vec4 color = texture( u_texture, E );
	vec2 uv = gl_FragCoord.xy * u_inv_screen_size; //[0,1]

	float depth = texture(u_gbuffer_depth, uv).r;

	if (depth >= 1.0)
	{
		// This is the skybox, don't shade
		FragColor = color;
		return;
	}
	FragColor = vec4(0.0);

}


\multi.fs

#version 330 core

in vec3 v_position;
in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

uniform vec4 u_color;
uniform sampler2D u_texture;
uniform float u_time;
uniform float u_alpha_cutoff;

layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec4 NormalColor;

void main()
{
	vec2 uv = v_uv;
	vec4 color = u_color;
	color *= texture( u_texture, uv );

	if(color.a < u_alpha_cutoff)
		discard;

	vec3 N = normalize(v_normal);

	FragColor = color;
	NormalColor = vec4(N,1.0);
}


\depth.fs

#version 330 core

uniform vec2 u_camera_nearfar;
uniform sampler2D u_texture; //depth map
in vec2 v_uv;
out vec4 FragColor;

void main()
{
	float n = u_camera_nearfar.x;
	float f = u_camera_nearfar.y;
	float z = texture2D(u_texture,v_uv).x;
	if( n == 0.0 && f == 1.0 )
		FragColor = vec4(z);
	else
		FragColor = vec4( n * (z + 1.0) / (f + n - z * (f - n)) );
}


\instanced.vs

#version 330 core

in vec3 a_vertex;
in vec3 a_normal;
in vec2 a_coord;

in mat4 u_model;

uniform vec3 u_camera_pos;

uniform mat4 u_viewprojection;

//this will store the color for the pixel shader
out vec3 v_position;
out vec3 v_world_position;
out vec3 v_normal;
out vec2 v_uv;

void main()
{	
	//calcule the normal in camera space (the NormalMatrix is like ViewMatrix but without traslation)
	v_normal = (u_model * vec4( a_normal, 0.0) ).xyz;
	
	//calcule the vertex in object space
	v_position = a_vertex;
	v_world_position = (u_model * vec4( a_vertex, 1.0) ).xyz;
	
	//store the texture coordinates
	v_uv = a_coord;

	//calcule the position of the vertex using the matrices
	gl_Position = u_viewprojection * vec4( v_world_position, 1.0 );
}

\phong.fs
#version 330 core

#define MAX_LIGHTS 100
#define MAX_SHADOW_CASTERS 4

mat3 cotangentFrame(vec3 N, vec3 p, vec2 uv) {
  // get edge vectors of the pixel triangle
  vec3 dp1 = dFdx(p);
  vec3 dp2 = dFdy(p);
  vec2 duv1 = dFdx(uv);
  vec2 duv2 = dFdy(uv);

  // solve the linear system
  vec3 dp2perp = cross(dp2, N);
  vec3 dp1perp = cross(N, dp1);
  vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
  vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

  // construct a scale-invariant frame 
  float invmax = 1.0 / sqrt(max(dot(T,T), dot(B,B)));
  return mat3(normalize(T * invmax), normalize(B * invmax), N);
}

vec3 perturbNormal(vec3 N, vec3 WP, vec2 uv, vec3 normal_pixel)
{
	normal_pixel = normal_pixel * 255./127. - 128./127.;
	mat3 TBN = cotangentFrame(N, WP, uv);
	return normalize(TBN * normal_pixel);
}

// Exercice 3.1
vec3 degamma(vec3 c) {
    return pow(c, vec3(2.2));
}

vec3 gamma(vec3 c) {
    return pow(c, vec3(1.0 / 2.2));
}

// Exercice 3.3
vec3 tonemapACES(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

// Inputs from vertex shader
in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

// Camera info
uniform vec3 u_camera_position;

// Material and textures
uniform vec4 u_color;
uniform sampler2D u_texture;
uniform sampler2D u_texture_normal;

// Light info
uniform int u_numLights;
uniform vec3 u_light_pos[MAX_LIGHTS];
uniform vec3 u_light_color[MAX_LIGHTS];	
uniform float u_light_intensity[MAX_LIGHTS];
uniform int u_light_type[MAX_LIGHTS]; // 0 = point, 1 = directional, 2 = spotlight

// Optional ambient light
uniform bool u_apply_ambient;
uniform vec3 u_ambient_light;
uniform float u_shininess;

// Spotlight data
uniform vec3 u_light_direction[MAX_LIGHTS];
uniform vec2 u_light_cone_info[MAX_LIGHTS]; // x = min angle, y = max angle (in radians)

// Shadow mapping
uniform sampler2D u_shadow_maps[MAX_SHADOW_CASTERS];
uniform mat4 u_shadow_vps[MAX_SHADOW_CASTERS];
uniform float u_shadow_bias;
uniform int    u_numShadowCasters;

// Alpha discard
uniform float u_alpha_cutoff;

out vec4 FragColor; // Final color output
   // color buffer
layout(location = 1) out vec4 NormalColor;  // normal buffer

// SSAO Texture
uniform sampler2D u_ssao_tex;

void main() {
    // Get the base color
    vec4 tex_color = texture(u_texture, v_uv);
    vec4 colorNL = tex_color * u_color;

	float alpha = colorNL.a;

	vec3 color = degamma(colorNL.rgb);

	// Discard the fragment if its alpha is below the cutoff (transparent)
    if (alpha < u_alpha_cutoff)
        discard;

    vec3 base_color = color.rgb;

	// Store base color for gFBO

	float ao = texture(u_ssao_tex, v_uv).r;

    // Ambient term calculation
    vec3 ambient = vec3(0.0);
	if (u_apply_ambient) {
		ambient = u_ambient_light * base_color * ao;
	}


	// Initialize lighting accumulators
    vec3 diffuse_total = vec3(0.0);
    vec3 specular_total = vec3(0.0);

	// Get the perturbed normal from the normal map
    vec3 normal_pixel = texture(u_texture_normal, v_uv).rgb;
    vec3 N = perturbNormal(normalize(v_normal), v_world_position, v_uv, normal_pixel);
    vec3 V = normalize(u_camera_position - v_world_position);

	// Loop through all lights and calculate their contribution
    for (int i = 0; i < u_numLights; i++) {

		vec3 light_color = degamma(u_light_color[i]);

        float shadow_factor = 1.0; // Default: no shadow

		// Calculate shadow for shadow-casting lights
		if (i < u_numShadowCasters) {
            vec4 proj_pos     = u_shadow_vps[i] * vec4(v_world_position, 1.0);
            float real_depth  = (proj_pos.z - u_shadow_bias) / proj_pos.w;
            proj_pos /= proj_pos.w;
            vec2 shadow_uv    = proj_pos.xy * 0.5 + 0.5;
            float shadow_depth = texture(u_shadow_maps[i], shadow_uv).x;
            float current_depth = real_depth * 0.5 + 0.5;

			// Compare the fragment depth with the shadow depth to apply shadowing
            if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 &&
                shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0)
            {
                if (current_depth > shadow_depth)
                    shadow_factor = 0.0;
            }
        }


		// Light direction and attenuation calculation
        vec3 L;
        float attenuation = 1.0;
		
		// Point light calculation
        if (u_light_type[i] == 0) {
            L = normalize(u_light_pos[i] - v_world_position);
            float distance = length(u_light_pos[i] - v_world_position);
            attenuation = 1.0 / (distance * distance);
        }
		// Directional light calculation
        else if (u_light_type[i] == 1) { // Luz direccional
            L = normalize(u_light_direction[i]);
            attenuation = 1.0;
        }
		// Spotlight calculation
		else if (u_light_type[i] == 2) { // Spotlight
  			L = normalize(u_light_pos[i] - v_world_position);
            float distance = length(u_light_pos[i] - v_world_position);
    
			vec3 D = normalize(u_light_direction[i]);
			float cos_angle = dot(L, D); 

			float cos_alpha_min = cos(u_light_cone_info[i].x);
			float cos_alpha_max = cos(u_light_cone_info[i].y);

			float spot_factor = 0.0;
			if (cos_angle >= cos_alpha_max) {
				spot_factor = clamp(
					(cos_angle - cos_alpha_max) / (cos_alpha_min - cos_alpha_max),
					0.0, 1.0
				);
			}

			attenuation = (1.0 / (distance * distance)) * spot_factor;
		}

		// Phong shading calculations: Diffuse and specular
		float N_dot_L = clamp(dot(N, L), 0.0, 1.0);
		vec3 R = reflect(L, N); // Reflection vector
		float R_dot_V = clamp(dot(R, V), 0.0, 1.0); // View reflection term

		// Diffuse and specular lighting contributions
		vec3 light_diffuse = base_color * N_dot_L * light_color * u_light_intensity[i] * attenuation;
		vec3 light_specular = base_color * light_color * u_light_intensity[i] * attenuation * pow(R_dot_V, u_shininess);

		// Apply shadow factor to light if shadow exists
		if (i < u_numShadowCasters &&(u_light_type[i]==1 || u_light_type[i]==2) ){
			light_diffuse  *= shadow_factor;
			light_specular *= shadow_factor;
		}

        // Accumulate diffuse and specular contributions
		diffuse_total += light_diffuse;
		specular_total += light_specular;
			
    }

	// Final color calculation with ambient, diffuse, and specular components
	vec3 final_color = ambient + (diffuse_total + specular_total);
	vec3 final_color_tonemapped = tonemapACES(final_color);
    FragColor = vec4(gamma(final_color_tonemapped), alpha);
	NormalColor = vec4(v_normal * 0.5 + 0.5,1.0); // Store normal in NormalColor for debugging
}

\plain.fs
#version 330 core

// UV coordinates passed from vertex shader
in vec2 v_uv; 

// Uniforms
uniform int   u_use_mask;
uniform float u_alpha_cutoff;
uniform sampler2D u_opacity_map;

out vec4 FragColor;

void main()
{
    // If masking is enabled
    if (u_use_mask == 1) {
        float a = texture(u_opacity_map, v_uv).x; // Sample red channel as alpha
        if (a < u_alpha_cutoff) discard; // Skip this fragment if too transparent
    }

	// Output black
    FragColor = vec4(0.0);
}

\phong_sphere.fs
#version 330 core

#define MAX_LIGHTS 100
#define MAX_SHADOW_CASTERS 4


mat3 cotangentFrame(vec3 N, vec3 p, vec2 uv) {
  // get edge vectors of the pixel triangle
  vec3 dp1 = dFdx(p);
  vec3 dp2 = dFdy(p);
  vec2 duv1 = dFdx(uv);
  vec2 duv2 = dFdy(uv);

  // solve the linear system
  vec3 dp2perp = cross(dp2, N);
  vec3 dp1perp = cross(N, dp1);
  vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
  vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

  // construct a scale-invariant frame 
  float invmax = 1.0 / sqrt(max(dot(T,T), dot(B,B)));
  return mat3(normalize(T * invmax), normalize(B * invmax), N);
}

vec3 perturbNormal(vec3 N, vec3 WP, vec2 uv, vec3 normal_pixel)
{
	normal_pixel = normal_pixel * 255./127. - 128./127.;
	mat3 TBN = cotangentFrame(N, WP, uv);
	return normalize(TBN * normal_pixel);
}

// Inputs from vertex shader
in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

// Camera info
uniform vec3 u_camera_position;

// Material and textures

uniform vec4 u_color;
uniform sampler2D u_texture;
uniform sampler2D u_texture_normal;


// Light info

uniform vec3 u_light_pos; 
uniform vec3 u_light_color;	
uniform float u_light_intensity;
uniform int u_light_type; // 0 = point, 1 = directional, 2 = spotlight

// Optional ambient light
uniform float u_shininess;

// Spotlight data
uniform vec3 u_light_direction;
uniform vec2 u_light_cone_info; // x = min angle, y = max angle (in radians)

// Shadow mapping
uniform sampler2D u_shadow_maps;
uniform mat4 u_shadow_vps;
uniform float u_shadow_bias;
uniform int    u_numShadowCasters;

// Alpha discard
uniform float u_alpha_cutoff;

uniform vec2 u_inv_screen_size;
//Unifroms from gbuffer

uniform sampler2D u_gbuffer_color;
uniform sampler2D u_gbuffer_normal;
uniform sampler2D u_gbuffer_depth;


uniform samplerCube u_sky_text;

uniform mat4 u_inv_viewprojection;

layout(location = 0) out vec4 FragColor; // Final color output
   // color buffer
layout(location = 1) out vec4 NormalColor;  // normal buffer

void main() {
    //Assigment 4 getting data from gbuffer
	vec2 uv = gl_FragCoord.xy * u_inv_screen_size; //[0,1]
	float depth = texture(u_gbuffer_depth, uv).x;
	float depth_clip = depth * 2.0 - 1.0; // [0,1] -> [-1,1]

	vec2 uv_clip = uv * 2.0 - 1.0; // [0,1] -> [-1,1]
	vec4 clip_coords = vec4(uv_clip.x, uv_clip.y, depth_clip, 1.0);

	vec4 not_norm_world_pos = u_inv_viewprojection * clip_coords;

	vec3 world_pos = not_norm_world_pos.xyz / not_norm_world_pos.w;

    // Get the base color
    vec4 tex_color = texture(u_gbuffer_color, uv);
    vec4 color = tex_color;

	// Discard the fragment if its alpha is below the cutoff (transparent)
    if (color.a < u_alpha_cutoff)
        discard;

    vec3 base_color = color.rgb;

	// Store base color for gFBO

	// Initialize lighting accumulators
    vec3 diffuse_total = vec3(0.0);
    vec3 specular_total = vec3(0.0);

	// Get the perturbed normal from the normal map
	vec3 normal_fromuv = texture(u_gbuffer_normal, uv).rgb;
    vec3 normal_pixel = texture(u_texture_normal, uv).rgb;
    vec3 N = perturbNormal(normalize(normal_fromuv), world_pos, uv, normal_pixel);
    vec3 V = normalize(u_camera_position - world_pos);

	/*
	// Get the perturbed normal from the normal map
    vec3 normal_fromuv = texture(u_gbuffer_normal, uv).rgb;
	vec3 normal_pixel = texture(u_texture_normal, uv).rgb;
    vec3 N = perturbNormal(normalize(normal_fromuv), world_pos, uv, normal_pixel);
    //N = normalize(texture(u_gbuffer_normal, uv).rgb) * 2.0 -1.0;
	N = normalize(N);
    vec3 V = normalize(u_camera_position - world_pos);
	*/
	// Loop through all lights and calculate their contribution
   

        float shadow_factor = 1.0; // Default: no shadow

		// Calculate shadow for shadow-casting lights
		
            vec4 proj_pos   = u_shadow_vps * vec4(world_pos, 1.0);
            float real_depth  = (proj_pos.z - u_shadow_bias) / proj_pos.w;
            proj_pos /= proj_pos.w;
            vec2 shadow_uv    = proj_pos.xy * 0.5 + 0.5;
            float shadow_depth = texture(u_shadow_maps, shadow_uv).x;
            float current_depth = real_depth * 0.5 + 0.5;

			// Compare the fragment depth with the shadow depth to apply shadowing
            if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 &&
                shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0)
            {
                if (current_depth > shadow_depth)
                    shadow_factor = 0.0;
            }
        


		// Light direction and attenuation calculation
        vec3 L;
        float attenuation = 1.0;
		
		// Point light calculation
        if (u_light_type == 0) {
            L = normalize(u_light_pos - world_pos);
            float distance = length(u_light_pos - world_pos);
            attenuation = 1.0 / (distance * distance);
        }
		// Spotlight calculation
		else if (u_light_type == 2) { // Spotlight
  			L = normalize(u_light_pos - world_pos);
			
            float distance = length(u_light_pos - world_pos);
    
			vec3 D = normalize(u_light_direction);
			float cos_angle = dot(L, D); 

			float cos_alpha_min = cos(u_light_cone_info.x);
			float cos_alpha_max = cos(u_light_cone_info.y);

			float spot_factor = 0.0;
			if (cos_angle >= cos_alpha_max) {
				spot_factor = clamp(
					(cos_angle - cos_alpha_max) / (cos_alpha_min - cos_alpha_max),
					0.0, 1.0
				);
			}

			attenuation = (1.0 / (distance * distance)) * spot_factor;
		}
		
		// Phong shading calculations: Diffuse and specular
		float N_dot_L = clamp(dot(N, L), 0.0, 1.0);
		vec3 R = reflect(L, N); // Reflection vector
		float R_dot_V = clamp(dot(R, V), 0.0, 1.0); // View reflection term

		// Diffuse and specular lighting contributions
		vec3 light_diffuse = base_color * N_dot_L * u_light_color * u_light_intensity * attenuation;
		vec3 light_specular = base_color * u_light_color * u_light_intensity * attenuation * pow(R_dot_V, 0.1);

		// Apply shadow factor to light if shadow exists
		
		if ((u_light_type==1 || u_light_type==2) ){
			light_diffuse  *= shadow_factor;
			light_specular *= shadow_factor;
		}
		
        // Accumulate diffuse and specular contributions
		diffuse_total += light_diffuse;
		specular_total += light_specular;
			
    

	// Final color calculation with ambient, diffuse, and specular components
	vec3 final_color = (diffuse_total + specular_total);
    FragColor = vec4(light_specular + light_diffuse, color.a);
}

\ssao.fs
#version 330 core

in vec2 v_uv;
layout(location = 0) out vec4 FragColor;

// G-buffer inputs
uniform sampler2D u_depth_tex;    // depth buffer (0..1)
uniform sampler2D u_normal_tex;   // normal buffer (encoded 0..1)

// Noise texture to rotate samples per fragment
uniform sampler2D u_noise_tex;
uniform vec2     u_noise_scale;   // = screenSize / noiseSize

// Inverse resolution (1 / screenSize)
uniform vec2     u_res_inv;

// SSAO params
uniform int      u_sample_count;
uniform float    u_sample_radius;
uniform float    u_ssao_bias;
uniform bool     u_use_ssao_plus;

// Camera matrices
uniform mat4     u_p_mat;
uniform mat4     u_inv_p_mat;

// Sample points in sphere or hemisphere (radius = 1.0)
uniform vec3     u_sample_pos[64];

// Reconstruct view-space Z from depth buffer
float reconstructDepth(vec2 uv) {
    float z = texture(u_depth_tex, uv).r;
    float z_ndc = z * 2.0 - 1.0;
    vec4 clip = vec4(uv * 2.0 - 1.0, z_ndc, 1.0);
    vec4 view = u_inv_p_mat * clip;
    return view.z / view.w;
}

// Reconstruct full view-space position
vec3 reconstructViewPos(vec2 uv) {
    float z = texture(u_depth_tex, uv).r;
    float z_ndc = z * 2.0 - 1.0;
    vec4 clip = vec4(uv * 2.0 - 1.0, z_ndc, 1.0);
    vec4 view = u_inv_p_mat * clip;
    return view.xyz / view.w;
}

void main() {
    // center UV to the texel center
    vec2 uv = v_uv + 0.5 * u_res_inv;

    // view-space position and normal
    vec3 P = reconstructViewPos(uv);
    vec3 N = texture(u_normal_tex, uv).rgb * 2.0 - 1.0;

    // build TBN if using SSAO+
    mat3 TBN = mat3(1.0);
    if (u_use_ssao_plus) {
        vec3 rand = texture(u_noise_tex, uv * u_noise_scale).xyz * 2.0 - 1.0;
        vec3 tangent = normalize(rand - N * dot(rand, N));
        vec3 bitan   = cross(N, tangent);
        TBN = mat3(tangent, bitan, N);
    }

    float occlusion = 0.0;
    for (int i = 0; i < u_sample_count; ++i) {
        vec3 samp = u_sample_pos[i];
        if (u_use_ssao_plus) {
            samp = TBN * samp;
        }

        vec3 samplePos = P + samp * u_sample_radius;

        // project sample position
        vec4 proj = u_p_mat * vec4(samplePos, 1.0);
        proj.xyz /= proj.w;
        vec2 uvSample = proj.xy * 0.5 + 0.5;

        // skip samples outside the screen
        if (uvSample.x < 0.0 || uvSample.x > 1.0 ||
            uvSample.y < 0.0 || uvSample.y > 1.0)
            continue;

        float sampleDepth = reconstructDepth(uvSample);
        // accumulate occlusion
        if (sampleDepth + u_ssao_bias < samplePos.z)
            occlusion += 1.0;
    }

    // normalize and output
    occlusion /= float(u_sample_count);
    FragColor = vec4(vec3(occlusion), 1.0);
}
\ssao_blur.fs
#version 330 core
in vec2 v_uv;
layout(location=0) out vec4 FragColor;

uniform sampler2D u_ssao_tex;    // SSAO low-res
uniform vec2      u_texel_size;  // = vec2(1.0/low_w,1.0/low_h)

void main() {
    float sum = 0.0;
    // box-blur 3×3
    for(int dx=-1; dx<=1; ++dx)
    for(int dy=-1; dy<=1; ++dy) {
        sum += texture(u_ssao_tex, v_uv + vec2(dx,dy) * u_texel_size).r;
    }
    float occl = sum / 9.0;
    FragColor = vec4(occl,occl,occl,1.0);
}
