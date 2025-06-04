/* MakeUp - volumetric_clouds.glsl
Fast volumetric clouds and volumetric light - MakeUp implementation with second cloud layer
*/

// Constants for the second cloud layer
#define CLOUD_PLANE_2 (CLOUD_PLANE + 400.0)  // Base height for second cloud layer
#define CLOUD_PLANE_SUP_2 (CLOUD_PLANE_SUP + 400.0)  // Upper bound for second cloud layer
#define CLOUD_PLANE_CENTER_2 (CLOUD_PLANE_CENTER + 180.0)  // Center of second cloud layer
#define CLOUD_X_OFFSET 800.0  // Shift second layer 800 blocks to the right

#if VOL_LIGHT == 2

    #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

    vec3 get_volumetric_pos(vec3 shadow_pos) {
        shadow_pos = mat3(shadowModelView) * shadow_pos + shadowModelView[3].xyz;
        shadow_pos = diagonal3(shadowProjection) * shadow_pos + shadowProjection[3].xyz;
        float distb = length(shadow_pos.xy);
        float distortion = distb * SHADOW_DIST + (1.0 - SHADOW_DIST);

        shadow_pos.xy /= distortion;
        shadow_pos.z *= 0.2;
        
        return shadow_pos * 0.5 + 0.5;
    }

    float get_volumetric_light(float dither, float view_distance, mat4 modeli_times_projectioni) {
        float light = 0.0;
        float current_depth;
        vec3 view_pos;
        vec4 pos;
        vec3 shadow_pos;
        float scene_depth;

        vec2 offset[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
        float pixel_size = 1.0 / 512.0; // Подстрой под разрешение теневой карты
        bool has_neighbor_block = false;

        for (int i = 0; i < GODRAY_STEPS; i++) {
            current_depth = exp2(i + dither) - 0.6;
            if (current_depth > view_distance) {
                break;
            }

            current_depth = (far * (current_depth - near)) / (current_depth * (far - near));
            view_pos = vec3(texcoord, current_depth);
            pos = modeli_times_projectioni * (vec4(view_pos, 1.0) * 2.0 - 1.0);
            view_pos = (pos.xyz /= pos.w).xyz;
            shadow_pos = get_volumetric_pos(view_pos);

            scene_depth = texture2D(depthtex0, texcoord).r;
            if (current_depth > scene_depth) {
                continue;
            }

            has_neighbor_block = false;
            for (int j = 0; j < 4; j++) {
                vec2 neighbor_pos = shadow_pos.xy + offset[j] * pixel_size;
                float neighbor_shadow = shadow2D(shadowtex0, vec3(neighbor_pos, shadow_pos.z - 0.001)).r;
                if (neighbor_shadow < 1.0) {
                    has_neighbor_block = true;
                    break;
                }
            }

            if (!has_neighbor_block) {
                continue;
            }

            light += shadow2D(shadowtex1, shadow_pos).r * 1.5; // Усиление яркости на 50%
        }

        light /= GODRAY_STEPS;

        return smoothstep(0.0, 0.7, light) * 1.2; // Усиление контраста и общей яркости
    }

    #if defined COLORED_SHADOW

        vec3 get_volumetric_color_light(float dither, float view_distance, mat4 modeli_times_projectioni) {
            float light = 0.0;
            float current_depth;
            vec3 view_pos;
            vec4 pos;
            vec3 shadow_pos;
            float shadow_detector = 1.0;
            float shadow_black = 1.0;
            vec4 shadow_color = vec4(1.0);
            vec3 light_color = vec3(0.0);
            float alpha_complement;
            float scene_depth;

            vec2 offset[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
            float pixel_size = 1.0 / 512.0;
            bool has_neighbor_block = false;

            for (int i = 0; i < GODRAY_STEPS; i++) {
                current_depth = exp2(i + dither) - 0.96;
                if (current_depth > view_distance) {
                    break;
                }

                current_depth = (far * (current_depth - near)) / (current_depth * (far - near));
                view_pos = vec3(texcoord, current_depth);
                pos = modeli_times_projectioni * (vec4(view_pos, 1.0) * 2.0 - 1.0);
                view_pos = (pos.xyz /= pos.w).xyz;
                shadow_pos = get_volumetric_pos(view_pos);

                scene_depth = texture2D(depthtex0, texcoord).r;
                if (current_depth > scene_depth) {
                    continue;
                }

                has_neighbor_block = false;
                for (int j = 0; j < 4; j++) {
                    vec2 neighbor_pos = shadow_pos.xy + offset[j] * pixel_size;
                    float neighbor_shadow = shadow2D(shadowtex0, vec3(neighbor_pos, shadow_pos.z - 0.001)).r;
                    if (neighbor_shadow < 1.0) {
                        has_neighbor_block = true;
                        break;
                    }
                }

                if (!has_neighbor_block) {
                    continue;
                }

                shadow_detector = shadow2D(shadowtex0, vec3(shadow_pos.xy, shadow_pos.z - 0.001)).r;
                if (shadow_detector < 1.0) {
                    shadow_black = shadow2D(shadowtex1, vec3(shadow_pos.xy, shadow_pos.z - 0.001)).r;
                    if (shadow_black != shadow_detector) {
                        shadow_color = texture2D(shadowcolor0, shadow_pos.xy);
                        alpha_complement = 1.0 - shadow_color.a;
                        shadow_color.rgb *= alpha_complement * 1.2; // Усиление насыщенности цвета
                        shadow_color.rgb = mix(shadow_color.rgb, vec3(1.0), alpha_complement * 1.8); // Легкое осветление
                    }
                }
                
                shadow_color *= shadow_black;
                light_color += clamp(shadow_color.rgb * (1.0 - shadow_detector) + shadow_detector, vec3(0.0), vec3(1.0)) * 1.3; // Усиление яркости цвета
            }

            light_color /= GODRAY_STEPS;

            return light_color * 1.1; // Дополнительное усиление итогового цвета
        }
        
    #endif

#elif VOL_LIGHT == 1

    float ss_godrays(float dither) {
        float light = 0.0;
        float comp = 1.0 - (near / (far * far));

        vec2 ray_step = vec2(lightpos - texcoord) * 0.2;
        vec2 dither2d = texcoord + (ray_step * dither);

        float depth;

        for (int i = 0; i < CHEAP_GODRAY_SAMPLES; i++) {
            depth = texture2D(depthtex1, dither2d).x;
            dither2d += ray_step;
            light += step(comp, depth) * 1.0; // Усиление яркости лучей
        }

        return light / CHEAP_GODRAY_SAMPLES * 1.0; // Усиление итоговой яркости
    }

#endif

vec3 get_cloud(vec3 view_vector, vec3 block_color, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloud_color, vec3 dark_cloud_color) {
    float plane_distance;
    float cloud_value;
    float density;
    vec3 intersection_pos;
    vec3 intersection_pos_sup;
    float dif_inf;
    float dif_sup;
    float dist_aux_coeff;
    float current_value;
    float surface_inf;
    float surface_sup;
    bool first_contact = true;
    float opacity_dist;
    vec3 increment;
    float increment_dist;
    float view_y_inv = 1.0 / view_vector.y;
    float distance_aux;
    float dist_aux_coeff_blur;

    // Second layer variables
    float cloud_value_2;
    float density_2;
    vec3 intersection_pos_2;
    vec3 intersection_pos_sup_2;
    float dif_inf_2;
    float dif_sup_2;
    float opacity_dist_2;
    vec3 increment_2;
    float increment_dist_2;
    bool first_contact_2 = true;

    #if VOL_LIGHT == 0
        block_color.rgb *=
            clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;
    #endif

    #if defined DISTANT_HORIZONS && defined DEFERRED_SHADER
        float d_dh = texture2D(dhDepthTex0, vec2(gl_FragCoord.x / viewWidth, gl_FragCoord.y / viewHeight)).r;
        float linear_d_dh = ld_dh(d_dh);
        if (linear_d_dh < 0.9999) {
            return block_color;
        }
    #endif

    if (view_vector.y > 0.0) {  // Over horizon
        // First cloud layer
        plane_distance = (CLOUD_PLANE - base_pos.y) * view_y_inv;
        intersection_pos = (view_vector * plane_distance) + base_pos;

        plane_distance = (CLOUD_PLANE_SUP - base_pos.y) * view_y_inv;
        intersection_pos_sup = (view_vector * plane_distance) + base_pos;

        dif_sup = CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER;
        dif_inf = CLOUD_PLANE_CENTER - CLOUD_PLANE;
        dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075;
        dist_aux_coeff_blur = dist_aux_coeff * 0.3;

        opacity_dist = dist_aux_coeff * 2.0 * view_y_inv;

        increment = (intersection_pos_sup - intersection_pos) / samples;
        increment_dist = length(increment);

        cloud_value = 0.0;

        intersection_pos += (increment * dither);

        for (int i = 0; i < samples; i++) {
            current_value =
                texture2D(
                    gaux2,
                    (intersection_pos.xz * 0.0002777777777777778) + (frameTimeCounter * CLOUD_HI_FACTOR)
                ).r;

            #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                current_value +=
                    texture2D(
                        gaux2,
                        (intersection_pos.zx * 0.0002777777777777778) + (frameTimeCounter * CLOUD_LOW_FACTOR)
                    ).r;

                current_value *= 0.5;
                current_value = smoothstep(0.05, 0.95, current_value);
            #endif

            // Аjuste por umbral
            current_value = (current_value - umbral) / (1.0 - umbral);

            // Superficies inferior y superior de nubes
            surface_inf = CLOUD_PLANE_CENTER - (current_value * dif_inf);
            surface_sup = CLOUD_PLANE_CENTER + (current_value * dif_sup);

            if (intersection_pos.y > surface_inf && intersection_pos.y < surface_sup) {
                cloud_value += min(increment_dist, surface_sup - surface_inf);

                if (first_contact) {
                    first_contact = false;
                    density = (surface_sup - intersection_pos.y) / (CLOUD_PLANE_SUP - CLOUD_PLANE);
                }
            }
            else if (surface_inf < surface_sup && i > 0) {
                distance_aux = min(
                    abs(intersection_pos.y - surface_inf),
                    abs(intersection_pos.y - surface_sup)
                );

                if (distance_aux < dist_aux_coeff_blur) {
                    cloud_value += min(
                        (clamp(dist_aux_coeff_blur - distance_aux, 0.0, dist_aux_coeff_blur) / dist_aux_coeff_blur) * increment_dist,
                        surface_sup - surface_inf
                    );

                    if (first_contact) {
                        first_contact = false;
                        density = (surface_sup - intersection_pos.y) / (CLOUD_PLANE_SUP - CLOUD_PLANE);
                    }
                }
            }

            intersection_pos += increment;
        }

        cloud_value = clamp(cloud_value / opacity_dist, 0.0, 1.0);
        density = clamp(density, 0.0001, 1.0);

        float att_factor = mix(1.0, 0.75, bright * (1.0 - rainStrength));

        #if CLOUD_VOL_STYLE == 1
            cloud_color = mix(cloud_color * att_factor, dark_cloud_color * att_factor, pow(density, 0.3) * 0.85);
        #else
            cloud_color = mix(cloud_color * att_factor, dark_cloud_color * att_factor, pow(density, 0.4));
        #endif

        block_color = mix(
            block_color,
            cloud_color,
            cloud_value * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0)
        );

        // Second cloud layer (identical to first, shifted 800 blocks right and higher)
        plane_distance = (CLOUD_PLANE_2 - base_pos.y) * view_y_inv;
        intersection_pos_2 = (view_vector * plane_distance) + base_pos;

        plane_distance = (CLOUD_PLANE_SUP_2 - base_pos.y) * view_y_inv;
        intersection_pos_sup_2 = (view_vector * plane_distance) + base_pos;

        dif_sup_2 = CLOUD_PLANE_SUP_2 - CLOUD_PLANE_CENTER_2;
        dif_inf_2 = CLOUD_PLANE_CENTER_2 - CLOUD_PLANE_2;
        dist_aux_coeff = (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_2) * 0.075;
        dist_aux_coeff_blur = dist_aux_coeff * 0.3;

        opacity_dist_2 = dist_aux_coeff * 2.0 * view_y_inv;

        increment_2 = (intersection_pos_sup_2 - intersection_pos_2) / samples;
        increment_dist_2 = length(increment_2);

        cloud_value_2 = 0.0;

        intersection_pos_2 += (increment_2 * dither);

        for (int i = 0; i < samples; i++) {
            current_value =
                texture2D(
                    gaux2,
                    ((intersection_pos_2.xz + vec2(CLOUD_X_OFFSET, 0.0)) * 0.0002777777777777778) + (frameTimeCounter * CLOUD_HI_FACTOR)
                ).r;

            #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                current_value +=
                    texture2D(
                        gaux2,
                        ((intersection_pos_2.zx + vec2(0.0, CLOUD_X_OFFSET)) * 0.0002777777777777778) + (frameTimeCounter * CLOUD_LOW_FACTOR)
                    ).r;

                current_value *= 0.5;
                current_value = smoothstep(0.05, 0.95, current_value);
            #endif

            // Аjuste por umbral (same as first layer)
            current_value = (current_value - umbral) / (1.0 - umbral);

            // Superficies inferior y superior de nubes
            surface_inf = CLOUD_PLANE_CENTER_2 - (current_value * dif_inf_2);
            surface_sup = CLOUD_PLANE_CENTER_2 + (current_value * dif_sup_2);

            if (intersection_pos_2.y > surface_inf && intersection_pos_2.y < surface_sup) {
                cloud_value_2 += min(increment_dist_2, surface_sup - surface_inf);

                if (first_contact_2) {
                    first_contact_2 = false;
                    density_2 = (surface_sup - intersection_pos_2.y) / (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_2);
                }
            }
            else if (surface_inf < surface_sup && i > 0) {
                distance_aux = min(
                    abs(intersection_pos_2.y - surface_inf),
                    abs(intersection_pos_2.y - surface_sup)
                );

                if (distance_aux < dist_aux_coeff_blur) {
                    cloud_value_2 += min(
                        (clamp(dist_aux_coeff_blur - distance_aux, 0.0, dist_aux_coeff_blur) / dist_aux_coeff_blur) * increment_dist_2,
                        surface_sup - surface_inf
                    );

                    if (first_contact_2) {
                        first_contact_2 = false;
                        density_2 = (surface_sup - intersection_pos_2.y) / (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_2);
                    }
                }
            }

            intersection_pos_2 += increment_2;
        }

        cloud_value_2 = clamp(cloud_value_2 / opacity_dist_2, 0.0, 1.0);
        density_2 = clamp(density_2, 0.0001, 1.0);

        vec3 cloud_color_2 = mix(cloud_color * att_factor, dark_cloud_color * att_factor, pow(density_2, CLOUD_VOL_STYLE == 1 ? 0.3 : 0.4) * (CLOUD_VOL_STYLE == 1 ? 0.85 : 1.0));

        float second_layer_opacity = cloud_value_2 * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0) * (1.0 - cloud_value);
        block_color = mix(
            block_color,
            cloud_color_2,
            second_layer_opacity
        );
    }

    return block_color;
}