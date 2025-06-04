/* MakeUp - volumetric_clouds.glsl
Fast volumetric clouds - MakeUp implementation with three cloud layers
*/

// Constants for the second cloud layer
#define CLOUD_PLANE_2 (CLOUD_PLANE + 400.0)  // Base height for second cloud layer
#define CLOUD_PLANE_SUP_2 (CLOUD_PLANE_SUP + 400.0)  // Upper bound for second cloud layer
#define CLOUD_PLANE_CENTER_2 (CLOUD_PLANE_CENTER + 180.0)  // Center of second cloud layer
#define CLOUD_X_OFFSET 800.0  // Shift second layer 800 blocks to the right

// Constants for the third cloud layer
#define CLOUD_PLANE_3 (CLOUD_PLANE_2 + 240.0)  // Base height for third cloud layer (240 blocks above second)
#define CLOUD_PLANE_SUP_3 (CLOUD_PLANE_SUP_2 + 240.0)  // Upper bound for third cloud layer
#define CLOUD_PLANE_CENTER_3 (CLOUD_PLANE_CENTER_2 + 240.0)  // Center of third cloud layer
#define CLOUD_X_OFFSET_3 1600.0  // Shift third layer 1600 blocks to the right
#define ENABLE_THIRD_CLOUD_LAYER 1  // Toggle for third cloud layer (1 = enabled, 0 = disabled)

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

    // Third layer variables
    float cloud_value_3;
    float density_3;
    vec3 intersection_pos_3;
    vec3 intersection_pos_sup_3;
    float dif_inf_3;
    float dif_sup_3;
    float opacity_dist_3;
    vec3 increment_3;
    float increment_dist_3;
    bool first_contact_3 = true;

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

            // Ajuste por umbral
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

        // Second cloud layer
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

            // Ajuste por umbral
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

        // Third cloud layer (only if enabled)
        #if ENABLE_THIRD_CLOUD_LAYER == 1
            plane_distance = (CLOUD_PLANE_3 - base_pos.y) * view_y_inv;
            intersection_pos_3 = (view_vector * plane_distance) + base_pos;

            plane_distance = (CLOUD_PLANE_SUP_3 - base_pos.y) * view_y_inv;
            intersection_pos_sup_3 = (view_vector * plane_distance) + base_pos;

            dif_sup_3 = CLOUD_PLANE_SUP_3 - CLOUD_PLANE_CENTER_3;
            dif_inf_3 = CLOUD_PLANE_CENTER_3 - CLOUD_PLANE_3;
            dist_aux_coeff = (CLOUD_PLANE_SUP_3 - CLOUD_PLANE_3) * 0.075;
            dist_aux_coeff_blur = dist_aux_coeff * 0.3;

            opacity_dist_3 = dist_aux_coeff * 2.0 * view_y_inv;

            increment_3 = (intersection_pos_sup_3 - intersection_pos_3) / samples;
            increment_dist_3 = length(increment_3);

            cloud_value_3 = 0.0;

            intersection_pos_3 += (increment_3 * dither);

            for (int i = 0; i < samples; i++) {
                current_value =
                    texture2D(
                        gaux2,
                        ((intersection_pos_3.xz + vec2(CLOUD_X_OFFSET_3, 0.0)) * 0.0002777777777777778) + (frameTimeCounter * CLOUD_HI_FACTOR)
                    ).r;

                #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                    current_value +=
                        texture2D(
                            gaux2,
                            ((intersection_pos_3.zx + vec2(0.0, CLOUD_X_OFFSET_3)) * 0.0002777777777777778) + (frameTimeCounter * CLOUD_LOW_FACTOR)
                        ).r;

                    current_value *= 0.5;
                    current_value = smoothstep(0.05, 0.95, current_value);
                #endif

                // Ajuste por umbral
                current_value = (current_value - umbral) / (1.0 - umbral);

                // Superficies inferior y superior de nubes
                surface_inf = CLOUD_PLANE_CENTER_3 - (current_value * dif_inf_3);
                surface_sup = CLOUD_PLANE_CENTER_3 + (current_value * dif_sup_3);

                if (intersection_pos_3.y > surface_inf && intersection_pos_3.y < surface_sup) {
                    cloud_value_3 += min(increment_dist_3, surface_sup - surface_inf);

                    if (first_contact_3) {
                        first_contact_3 = false;
                        density_3 = (surface_sup - intersection_pos_3.y) / (CLOUD_PLANE_SUP_3 - CLOUD_PLANE_3);
                    }
                }
                else if (surface_inf < surface_sup && i > 0) {
                    distance_aux = min(
                        abs(intersection_pos_3.y - surface_inf),
                        abs(intersection_pos_3.y - surface_sup)
                    );

                    if (distance_aux < dist_aux_coeff_blur) {
                        cloud_value_3 += min(
                            (clamp(dist_aux_coeff_blur - distance_aux, 0.0, dist_aux_coeff_blur) / dist_aux_coeff_blur) * increment_dist_3,
                            surface_sup - surface_inf
                        );

                        if (first_contact_3) {
                            first_contact_3 = false;
                            density_3 = (surface_sup - intersection_pos_3.y) / (CLOUD_PLANE_SUP_3 - CLOUD_PLANE_3);
                        }
                    }
                }

                intersection_pos_3 += increment_3;
            }

            cloud_value_3 = clamp(cloud_value_3 / opacity_dist_3, 0.0, 1.0);
            density_3 = clamp(density_3, 0.0001, 1.0);

            vec3 cloud_color_3 = mix(cloud_color * att_factor, dark_cloud_color * att_factor, pow(density_3, CLOUD_VOL_STYLE == 1 ? 0.3 : 0.4) * (CLOUD_VOL_STYLE == 1 ? 0.85 : 1.0));

            // Blend third layer only through transparent parts of first and second layers
            float third_layer_opacity = cloud_value_3 * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0) * (1.0 - cloud_value) * (1.0 - cloud_value_2);
            block_color = mix(
                block_color,
                cloud_color_3,
                third_layer_opacity
            );
        #endif
    }

    return block_color;
}