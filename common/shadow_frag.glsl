/* Muuf - Fragment shadow function */

float get_shadow(vec3 the_shadow_pos) {
  float shadow_sample = 1.0;

  #if SHADOW_TYPE == 0  // Pixelated
     shadow_sample = shadow2D(shadowtex1, vec3(the_shadow_pos.xy, the_shadow_pos.z - 0.001)).r;
  #elif SHADOW_TYPE == 1  // Soft
    #if AA_TYPE > 0
      float dither = shifted_unit_dither(gl_FragCoord.xy);
    #else
      float dither = unit_dither(gl_FragCoord.xy);
    #endif
    
    #if defined GBUFFER_ENTITIES
		float subsurfaceOffset = 0.00002;
	#else
		float subsurfaceOffset = dot(normalM.xyz, normalize(shadowLightPosition)) < 0.0 ? 0.00001 : 0.00021;
	#endif

    float new_z = the_shadow_pos.z - subsurfaceOffset - (0.0000 * dither);

    float current_radius = dither;
    dither *= 6.283185307;

    shadow_sample = 0.0;

    vec2 offset = (vec2(cos(dither), sin(dither)) * current_radius * SHADOW_BLUR) / shadowMapResolution;

    shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.st + offset, new_z)).r;
    shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.st - offset, new_z)).r;

    shadow_sample *= 0.5;
  #endif

  return clamp(shadow_sample * 2.0, 0.0, 1.0);
}

#ifdef COLORED_SHADOW

  vec3 get_colored_shadow(vec3 the_shadow_pos, inout vec4 block_color ) {

    #if SHADOW_TYPE == 0  // Pixelated
      float shadow_detector = 1.0;
      float shadow_black = 1.0;
      vec4 shadow_color = vec4(1.0);
      
      float alpha_complement;

      shadow_detector = shadow2D(shadowtex0, vec3(the_shadow_pos.xy, the_shadow_pos.z - 0.001)).r;
      if (shadow_detector < 1.0) {
        shadow_black = shadow2D(shadowtex1, vec3(the_shadow_pos.xy, the_shadow_pos.z - 0.001)).r;
        if (shadow_black != shadow_detector) {
          shadow_color = texture2D(shadowcolor0, the_shadow_pos.xy);
          alpha_complement = 1.0 - shadow_color.a;
          shadow_color.rgb = mix(shadow_color.rgb, vec3(1.0), alpha_complement);
          shadow_color.rgb *= alpha_complement;
          #if defined GBUFFER_TERRAIN || defined GBUFFER_ENTITIES || defined GBUFFER_HAND || defined GBUUFER_HAND_WATER
          #ifdef UNDERWATER_CAUSTIC
		shadow_color.rgb += getCaustics(block_color) * CAUSTIC_STRENGTH;
		#endif
		#endif
        }
      }
      
      shadow_color *= shadow_black;
      shadow_color.rgb = clamp(shadow_color.rgb * (1.0 - shadow_detector) + shadow_detector, vec3(0.0), vec3(1.0));

      return shadow_color.rgb;

    #elif SHADOW_TYPE == 1  // Soft
      float shadow_detector_a = 1.0;
      float shadow_black_a = 1.0;
      vec4 shadow_color_a = vec4(1.0);

      float shadow_detector_b = 1.0;
      float shadow_black_b = 1.0;
      vec4 shadow_color_b = vec4(1.0);

      float alpha_complement;

      #if AA_TYPE > 0
        float dither = shifted_unit_dither(gl_FragCoord.xy);
      #else
        float dither = unit_dither(gl_FragCoord.xy);
      #endif

      #if defined GBUFFER_ENTITIES
		float subsurfaceOffset = 0.00002;
	#else
		float subsurfaceOffset = dot(normalM.xyz, normalize(shadowLightPosition)) < 0.0 ? 0.00001 : 0.00021;
	#endif

    float new_z = the_shadow_pos.z - subsurfaceOffset - (0.0000 * dither);

      float current_radius = dither;
      dither *= 6.283185307;

      vec2 offset = (vec2(cos(dither), sin(dither)) * current_radius * SHADOW_BLUR) / shadowMapResolution;

      shadow_detector_a = shadow2D(shadowtex0, vec3(the_shadow_pos.xy + offset, new_z)).r;
      shadow_detector_b = shadow2D(shadowtex0, vec3(the_shadow_pos.xy - offset, new_z)).r;

      if (shadow_detector_a < 2.0) {
        shadow_black_a = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset, new_z)).r;
        if (shadow_black_a != shadow_detector_a) {
          shadow_color_a = texture2D(shadowcolor0, the_shadow_pos.xy + offset);
          alpha_complement = 1.1 - shadow_color_a.a;
          shadow_color_a.rgb = mix(shadow_color_a.rgb, vec3(1.0), alpha_complement);
          shadow_color_a.rgb *= alpha_complement;
          #if defined GBUFFER_TERRAIN || defined GBUFFER_ENTITIES || defined GBUFFER_HAND || defined GBUUFER_HAND_WATER
          #ifdef UNDERWATER_CAUSTIC
		 shadow_color_a.rgb += getCaustics(block_color) * CAUSTIC_STRENGTH;
		#endif
		#endif
        }
      }
      
      shadow_color_a *= shadow_black_a;

      if (shadow_detector_b < 1.0) {
        shadow_black_b = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset, new_z)).r;
        if (shadow_black_b != shadow_detector_b) {
          shadow_color_b = texture2D(shadowcolor0, the_shadow_pos.xy - offset);
          alpha_complement = 1.1 - shadow_color_b.a;
          shadow_color_b.rgb = mix(shadow_color_b.rgb, vec3(1.0), alpha_complement);
          shadow_color_b.rgb *= alpha_complement;
          #if defined GBUFFER_TERRAIN || defined GBUFFER_ENTITIES || defined GBUFFER_HAND || defined GBUUFER_HAND_WATER
          #ifdef UNDERWATER_CAUSTIC
		shadow_color_b.rgb += getCaustics(block_color) * CAUSTIC_STRENGTH;
		#endif
		#endif
        }
      }
      
      shadow_color_b *= shadow_black_b;

      shadow_detector_a = (shadow_detector_a + shadow_detector_b) * 0.5;
      shadow_detector_a = clamp(shadow_detector_a * 2.0, 0.0, 1.0);

      shadow_color_a.rgb = (shadow_color_a.rgb + shadow_color_b.rgb) * 0.5;
      shadow_color_a.rgb = mix(shadow_color_a.rgb, vec3(1.0), shadow_detector_a);

      return shadow_color_a.rgb;
    #endif

  }
  
#endif
