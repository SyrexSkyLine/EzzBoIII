/* MakeUp - shadow_frag.glsl
Fragment shadow function with enhanced colored shadows, brighter foliage gradient effect, GI-like diffuse lighting, and SEUS-like water caustic shadows applied only to blocks under water.

Javier Garduño - GNU Lesser General Public License v3.0
*/

float get_shadow(vec3 the_shadow_pos, float dither) {
    float shadow_sample = 1.0;

    #if SHADOW_TYPE == 0  // Pixelated
        shadow_sample = shadow2D(shadowtex1, the_shadow_pos).r;
    #elif SHADOW_TYPE == 1  // Soft
        float current_radius = dither;
        dither *= 6.283185307179586;
        float dither_2 = dither + 1.5707963267948966;

        shadow_sample = 0.0;

        vec2 offset = (vec2(cos(dither), sin(dither)) * current_radius * SHADOW_BLUR) / shadowMapResolution;
        vec2 offset_2 = (vec2(cos(dither_2), sin(dither_2)) * (1.0 - current_radius) * SHADOW_BLUR) / shadowMapResolution;

        float z_bias = dither * 0.00002;

        shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
        shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
        shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset_2, the_shadow_pos.z - z_bias)).r;
        shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset_2, the_shadow_pos.z - z_bias)).r;

        shadow_sample *= 0.25;
    #endif

    return shadow_sample;
}

// Функция для вычисления нормалей волн в пространстве теней (синхронизировано с water.glsl)
vec3 normal_waves_shadow(vec2 pos) {
    float speed = frameTimeCounter * -0.025;
    vec2 wave_1 = texture2D(noisetex, (pos * 0.25) + speed).rg;
    wave_1 = wave_1 - 0.5;
    vec2 wave_2 = texture2D(noisetex, (pos * 0.0625) - speed).rg;
    wave_2 = wave_2 - 0.5;
    wave_2 *= 3.0;

    vec2 partial_wave = wave_1 + wave_2;
    vec3 final_wave = vec3(partial_wave, 1.0 - (partial_wave.x * partial_wave.x + partial_wave.y * partial_wave.y));

    #if REFLECTION_SLIDER == 0
        final_wave.z *= WATER_TURBULENCE * 0.7;
    #else
        final_wave.z *= WATER_TURBULENCE;
    #endif

    return normalize(final_wave);
}

// Функция для SEUS-подобных каустических теней
float caustic_shadow(vec2 shadow_pos, vec3 wave_normal, float dither) {
    #if SUN_REFLECTION == 1 && !defined NETHER && !defined THE_END
        vec3 astro_pos = worldTime > 12950 ? moonPosition : sunPosition;
        float wave_sun_angle = max(dot(wave_normal, normalize(astro_pos)), 0.0);

        float speed = frameTimeCounter * 0.12;
        vec2 noise_coord = shadow_pos * 0.4 + vec2(speed, -speed * 0.6);
        float noise1 = texture2D(noisetex, noise_coord).r;
        float noise2 = texture2D(noisetex, noise_coord * 0.3 + vec2(-speed * 0.4, speed * 0.25)).r;
        float noise3 = texture2D(noisetex, noise_coord * 0.15 + vec2(speed * 0.2, speed * 0.3)).r;
        float noise = (noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2) * 1.8;

        float caustic = pow(noise, 5.0) * pow(smoothstep(0.85, 1.0, wave_sun_angle), 2.0) * 10.0;
        caustic *= (1.0 - rainStrength);

        // Ослабление каустики на глубине
        float depth = texture2D(depthtex1, shadow_pos).r;
        float depth_factor = smoothstep(0.0, 10.0, (1.0 - depth) * far); // Ослабление на глубине > 10 блоков
        caustic *= (1.0 - depth_factor);

        return clamp(caustic, 0.0, 4.0);
    #else
        return 0.0;
    #endif
}

#if defined COLORED_SHADOW

    vec3 get_colored_shadow(vec3 the_shadow_pos, float dither) {
        #if SHADOW_TYPE == 0  // Pixelated
            float shadow_detector = 1.0;
            float shadow_black = 1.0;
            vec4 shadow_color = vec4(1.0);
            vec3 gi_lighting = vec3(0.0);
            float caustic_intensity = 0.0;

            shadow_detector = shadow2D(shadowtex0, vec3(the_shadow_pos.xy, the_shadow_pos.z)).r;
            if (shadow_detector < 1.0) {
                shadow_black = shadow2D(shadowtex1, vec3(the_shadow_pos.xy, the_shadow_pos.z)).r;
                if (shadow_black != shadow_detector) {
                    shadow_color = texture2D(shadowcolor0, the_shadow_pos.xy);
                    float alpha_complement = 1.0 - shadow_color.a;

                    // Усиленное условие для воды
                    if (shadow_color.a < 0.9 && shadow_color.b > shadow_color.r * 1.2 && shadow_color.b > shadow_color.g * 1.2 && isEyeInWater == 1) {
                        vec3 wave_normal = normal_waves_shadow(the_shadow_pos.xy);
                        caustic_intensity = caustic_shadow(the_shadow_pos.xy, wave_normal, dither);
                        shadow_color.rgb = mix(shadow_color.rgb, vec3(1.0, 1.05, 1.1), caustic_intensity * 0.7);
                    } else {
                        shadow_color.rgb = mix(shadow_color.rgb * 1.4, vec3(1.0), alpha_complement * 0.3);
                        shadow_color.rgb *= (1.0 - alpha_complement * 0.2);
                        if (shadow_color.g > shadow_color.r * 1.2 && shadow_color.g > shadow_color.b * 1.2) {
                            shadow_color.rgb = mix(shadow_color.rgb * 1.6, vec3(0.15, 0.9, 0.25), 0.6);
                        }
                        gi_lighting = texture2D(shadowcolor0, the_shadow_pos.xy).rgb * 0.4;
                        gi_lighting = mix(gi_lighting, vec3(0.2), 0.6);
                        gi_lighting *= (1.0 - shadow_detector) * 0.6;
                        shadow_color.rgb += gi_lighting;
                    }
                }
            }
            
            shadow_color *= shadow_black;
            shadow_color.rgb = clamp(shadow_color.rgb * (1.0 - shadow_detector) + shadow_detector, vec3(0.0), vec3(1.0));
            return shadow_color.rgb;

        #elif SHADOW_TYPE == 1  // Soft
            float shadow_detector_a = 1.0;
            float shadow_black_a = 1.0;
            vec4 shadow_color_a = vec4(1.0);
            vec3 gi_lighting_a = vec3(0.0);
            float caustic_intensity_a = 0.0;

            float shadow_detector_b = 1.0;
            float shadow_black_b = 1.0;
            vec4 shadow_color_b = vec4(1.0);
            vec3 gi_lighting_b = vec3(0.0);
            float caustic_intensity_b = 0.0;

            float shadow_detector_c = 1.0;
            float shadow_black_c = 1.0;
            vec4 shadow_color_c = vec4(1.0);
            vec3 gi_lighting_c = vec3(0.0);
            float caustic_intensity_c = 0.0;

            float shadow_detector_d = 1.0;
            float shadow_black_d = 1.0;
            vec4 shadow_color_d = vec4(1.0);
            vec3 gi_lighting_d = vec3(0.0);
            float caustic_intensity_d = 0.0;

            float current_radius = dither;
            dither *= 6.283185307179586;
            float dither_2 = dither + 1.5707963267948966;

            vec2 offset = (vec2(cos(dither), sin(dither)) * current_radius * SHADOW_BLUR) / shadowMapResolution;
            vec2 offset_2 = (vec2(cos(dither_2), sin(dither_2)) * (1.0 - current_radius) * SHADOW_BLUR) / shadowMapResolution;

            float z_bias = dither * 0.00002;

            shadow_detector_a = shadow2D(shadowtex0, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
            shadow_detector_b = shadow2D(shadowtex0, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
            shadow_detector_c = shadow2D(shadowtex0, vec3(the_shadow_pos.xy + offset_2, the_shadow_pos.z - z_bias)).r;
            shadow_detector_d = shadow2D(shadowtex0, vec3(the_shadow_pos.xy - offset_2, the_shadow_pos.z - z_bias)).r;

            vec3 wave_normal = normal_waves_shadow(the_shadow_pos.xy);

            if (shadow_detector_a < 1.0) {
                shadow_black_a = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
                if (shadow_black_a != shadow_detector_a) {
                    shadow_color_a = texture2D(shadowcolor0, the_shadow_pos.xy + offset);
                    float alpha_complement = 1.0 - shadow_color_a.a;
                    if (shadow_color_a.a < 0.9 && shadow_color_a.b > shadow_color_a.r * 1.2 && shadow_color_a.b > shadow_color_a.g * 1.2 && isEyeInWater == 1) {
                        caustic_intensity_a = caustic_shadow(the_shadow_pos.xy + offset, wave_normal, dither);
                        shadow_color_a.rgb = mix(shadow_color_a.rgb, vec3(1.0, 1.05, 1.1), caustic_intensity_a * 0.7);
                    } else {
                        shadow_color_a.rgb = mix(shadow_color_a.rgb * 1.4, vec3(1.0), alpha_complement * 0.3);
                        shadow_color_a.rgb *= (1.0 - alpha_complement * 0.2);
                        if (shadow_color_a.g > shadow_color_a.r * 1.2 && shadow_color_a.g > shadow_color_a.b * 1.2) {
                            shadow_color_a.rgb = mix(shadow_color_a.rgb * 1.6, vec3(0.15, 0.9, 0.25), 0.6);
                        }
                        gi_lighting_a = texture2D(shadowcolor0, the_shadow_pos.xy + offset).rgb * 0.4;
                        gi_lighting_a = mix(gi_lighting_a, vec3(0.2), 0.6);
                        gi_lighting_a *= (1.0 - shadow_detector_a) * 0.6;
                        shadow_color_a.rgb += gi_lighting_a;
                    }
                }
            }
            shadow_color_a *= shadow_black_a;

            if (shadow_detector_b < 1.0) {
                shadow_black_b = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
                if (shadow_black_b != shadow_detector_b) {
                    shadow_color_b = texture2D(shadowcolor0, the_shadow_pos.xy - offset);
                    float alpha_complement = 1.0 - shadow_color_b.a;
                    if (shadow_color_b.a < 0.9 && shadow_color_b.b > shadow_color_b.r * 1.2 && shadow_color_b.b > shadow_color_b.g * 1.2 && isEyeInWater == 1) {
                        caustic_intensity_b = caustic_shadow(the_shadow_pos.xy - offset, wave_normal, dither);
                        shadow_color_b.rgb = mix(shadow_color_b.rgb, vec3(1.0, 1.05, 1.1), caustic_intensity_b * 0.7);
                    } else {
                        shadow_color_b.rgb = mix(shadow_color_b.rgb * 1.4, vec3(1.0), alpha_complement * 0.3);
                        shadow_color_b.rgb *= (1.0 - alpha_complement * 0.2);
                        if (shadow_color_b.g > shadow_color_b.r * 1.2 && shadow_color_b.g > shadow_color_b.b * 1.2) {
                            shadow_color_b.rgb = mix(shadow_color_b.rgb * 1.6, vec3(0.15, 0.9, 0.25), 0.6);
                        }
                        gi_lighting_b = texture2D(shadowcolor0, the_shadow_pos.xy - offset).rgb * 0.4;
                        gi_lighting_b = mix(gi_lighting_b, vec3(0.2), 0.6);
                        gi_lighting_b *= (1.0 - shadow_detector_b) * 0.6;
                        shadow_color_b.rgb += gi_lighting_b;
                    }
                }
            }
            shadow_color_b *= shadow_black_b;

            if (shadow_detector_c < 1.0) {
                shadow_black_c = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset_2, the_shadow_pos.z - z_bias)).r;
                if (shadow_black_c != shadow_detector_c) {
                    shadow_color_c = texture2D(shadowcolor0, the_shadow_pos.xy + offset_2);
                    float alpha_complement = 1.0 - shadow_color_c.a;
                    if (shadow_color_c.a < 0.9 && shadow_color_c.b > shadow_color_c.r * 1.2 && shadow_color_c.b > shadow_color_c.g * 1.2 && isEyeInWater == 1) {
                        caustic_intensity_c = caustic_shadow(the_shadow_pos.xy + offset_2, wave_normal, dither);
                        shadow_color_c.rgb = mix(shadow_color_c.rgb, vec3(1.0, 1.05, 1.1), caustic_intensity_c * 0.7);
                    } else {
                        shadow_color_c.rgb = mix(shadow_color_c.rgb * 1.4, vec3(1.0), alpha_complement * 0.3);
                        shadow_color_c.rgb *= (1.0 - alpha_complement * 0.2);
                        if (shadow_color_c.g > shadow_color_c.r * 1.2 && shadow_color_c.g > shadow_color_c.b * 1.2) {
                            shadow_color_c.rgb = mix(shadow_color_c.rgb * 1.6, vec3(0.15, 0.9, 0.25), 0.6);
                        }
                        gi_lighting_c = texture2D(shadowcolor0, the_shadow_pos.xy + offset_2).rgb * 0.4;
                        gi_lighting_c = mix(gi_lighting_c, vec3(0.2), 0.6);
                        gi_lighting_c *= (1.0 - shadow_detector_c) * 0.6;
                        shadow_color_c.rgb += gi_lighting_c;
                    }
                }
            }
            shadow_color_c *= shadow_black_c;

            if (shadow_detector_d < 1.0) {
                shadow_black_d = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset_2, the_shadow_pos.z - z_bias)).r;
                if (shadow_black_d != shadow_detector_d) {
                    shadow_color_d = texture2D(shadowcolor0, the_shadow_pos.xy - offset_2);
                    float alpha_complement = 1.0 - shadow_color_d.a;
                    if (shadow_color_d.a < 0.9 && shadow_color_d.b > shadow_color_d.r * 1.2 && shadow_color_d.b > shadow_color_d.g * 1.2 && isEyeInWater == 1) {
                        caustic_intensity_d = caustic_shadow(the_shadow_pos.xy - offset_2, wave_normal, dither);
                        shadow_color_d.rgb = mix(shadow_color_d.rgb, vec3(1.0, 1.05, 1.1), caustic_intensity_d * 0.7);
                    } else {
                        shadow_color_d.rgb = mix(shadow_color_d.rgb * 1.8, vec3(1.0), alpha_complement * 0.3);
                        shadow_color_d.rgb *= (1.0 - alpha_complement * 0.2);
                        if (shadow_color_d.g > shadow_color_d.r * 1.2 && shadow_color_d.g > shadow_color_d.b * 1.2) {
                            shadow_color_d.rgb = mix(shadow_color_d.rgb * 1.6, vec3(0.15, 0.9, 0.25), 0.6);
                        }
                        gi_lighting_d = texture2D(shadowcolor0, the_shadow_pos.xy - offset_2).rgb * 0.4;
                        gi_lighting_d = mix(gi_lighting_d, vec3(0.2), 0.6);
                        gi_lighting_d *= (1.0 - shadow_detector_d) * 0.6;
                        shadow_color_d.rgb += gi_lighting_d;
                    }
                }
            }
            shadow_color_d *= shadow_black_d;

            shadow_detector_a = (shadow_detector_a + shadow_detector_b + shadow_detector_c + shadow_detector_d);
            shadow_detector_a *= 0.25;

            shadow_color_a.rgb = (shadow_color_a.rgb + shadow_color_b.rgb + shadow_color_c.rgb + shadow_color_d.rgb) * 0.25;
            shadow_color_a.rgb = mix(shadow_color_a.rgb, vec3(1.0), shadow_detector_a * 0.3);

            return shadow_color_a.rgb;
        #endif
    }

#endif