/* MakeUp - textured.fsh
Fragment shader for translucent terrain rendering with enhanced gloss effect and customizable ground fog/smoke effect.
*/

#include "/lib/config.glsl"

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#endif

/* Force enable shadow casting for testing */
#define SHADOW_CASTING

/* Uniforms */
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform sampler2D tex;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float light_mix;
uniform float pixel_size_x;
uniform float pixel_size_y;
uniform sampler2D gaux4;
uniform sampler2D depthtex1;
uniform float near;
uniform float far;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;

uniform sampler2DShadow shadowtex1;
uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowcolor0;

#if defined DISTANT_HORIZONS
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    uniform sampler2D dhDepthTex1;
#endif

#if defined GBUFFER_ENTITIES
    uniform int entityId;
    uniform vec4 entityColor;
#endif

#ifdef NETHER
    uniform vec3 fogColor;
#endif

#if defined SHADOW_CASTING
    #if defined COLORED_SHADOW
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    #if defined THE_END
        uniform mat4 gbufferModelView;
    #endif
#endif

/* Smoke control uniforms */
uniform float smoke_mode = 2.0;       // 0.0 = выключен, 1.0 = локальный дым, 2.0 = полноэкранный дым
uniform float smoke_fov_factor = 1.0; // Контроль области покрытия (0.0 - 1.0, где 1.0 = весь экран)

/* Ins / Outs */
varying vec2 texcoord;
varying vec4 tint_color;
varying float frog_adjust;
varying vec3 direct_light_color;
varying vec3 candle_color;
varying float direct_light_strength;
varying vec3 omni_light;

#if defined GBUFFER_TERRAIN || defined GBUFFER_HAND
    varying float emmisive_type;
#endif

#ifdef FOLIAGE_V
    varying float is_foliage;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    varying vec3 shadow_pos;
    varying float shadow_diffuse;
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    varying vec3 flat_normal;
    varying vec3 sub_position3;
    varying vec2 lmcoord_alt;
    varying float gloss_factor;
    varying float gloss_power;
    varying float luma_factor;
    varying float luma_power;
#endif

/* Constants */
#define WATER_TURBULENCE 1.0
#define SUN_REFLECTION 1
#define SHADOW_TYPE 1
#define SHADOW_BLUR 2.0
#define COLORED_SHADOW
#define REFLECTION_SLIDER 0

/* Smoke effect parameters */
#define SMOKE_DENSITY 0.3  // Плотность дыма (0.0 - 1.0)
#define SMOKE_HEIGHT 0.5   // Максимальная высота дыма над землей (для локального режима)
#define SMOKE_SPEED 0.1    // Скорость движения дыма
#define SMOKE_SCALE 0.05   // Масштаб текстуры шума для дыма

/* Utility functions */
#if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
    #include "/lib/dither.glsl"
#endif

#if defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_frag.glsl"
#endif

#include "/lib/luma.glsl"

#if defined MATERIAL_GLOSS && !defined NETHER
    #include "/lib/material_gloss_fragment.glsl"
#endif

/* Smoke effect function */
float calculate_smoke(vec3 fragpos, vec2 texcoord, float dither) {
    if (smoke_mode < 0.5) return 0.0; // Эффект выключен

    // Используем текстуру шума для создания органического эффекта
    vec2 smoke_uv = texcoord + vec2(frameTimeCounter * SMOKE_SPEED, 0.0);
    float noise = texture2D(noisetex, smoke_uv * SMOKE_SCALE).r;

    // Контроль области покрытия (FoV)
    vec2 centered_coord = texcoord * 2.0 - 1.0; // Нормализуем координаты от -1 до 1
    float distance_from_center = length(centered_coord);
    float fov_mask = smoothstep(smoke_fov_factor, smoke_fov_factor + 0.2, distance_from_center);
    float fov_factor = 1.0 - fov_mask;

    // Ограничиваем дым по высоте (только для локального режима)
    float height_factor = 1.0;
    if (smoke_mode < 1.5) { // Локальный режим
        height_factor = clamp(1.0 - (fragpos.y / SMOKE_HEIGHT), 0.0, 1.0);
    }

    // Модулируем плотность дыма с учетом шума, высоты и FoV
    float smoke_alpha = noise * height_factor * SMOKE_DENSITY * fov_factor;

    // Добавляем случайность с помощью дитеринга
    smoke_alpha *= (1.0 - dither * 0.2);

    return clamp(smoke_alpha, 0.0, 1.0);
}

void main() {
    #if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
        #if AA_TYPE > 0 
            float dither = shifted_dither13(gl_FragCoord.xy);
        #else
            float dither = r_dither(gl_FragCoord.xy);
        #endif
    #endif

    // Avoid render in DH transition
    #ifdef DISTANT_HORIZONS
        float t = far - dhNearPlane;
        float sup = t * TRANSITION_DH_SUP;
        float inf = t * TRANSITION_DH_INF;
        float umbral = (gl_FogFragCoord - (dhNearPlane + inf)) / (far - sup - inf - dhNearPlane);
        if (umbral > dither) {
            discard;
            return;
        }
    #endif

    // Проверяем, является ли текущий фрагмент водой
    #ifdef GBUFFER_WATER
        vec3 fragpos = sub_position3;
        vec3 normal = flat_normal;
        vec3 color = texture2D(tex, texcoord).rgb * tint_color.rgb;
        vec3 sky_reflect = vec3(0.0);
        vec3 reflected = reflect(normalize(fragpos), normal);
        float fresnel = clamp(dot(normal, normalize(-fragpos)), 0.0, 1.0);
        float visible_sky = 1.0 - rainStrength;
        vec3 light_color = direct_light_color;

        vec3 block_color = water_shader(
            fragpos,
            normal,
            color,
            sky_reflect,
            reflected,
            fresnel,
            visible_sky,
            dither,
            light_color
        );
        vec4 final_color = vec4(block_color, tint_color.a * 0.8);
    #else
        // Обработка для непрозрачных объектов
        #if defined GBUFFER_ENTITIES
            #if BLACK_ENTITY_FIX == 1
                vec4 block_color = texture2D(tex, texcoord);
                if (block_color.a < 0.1 && entityId != 10101) {
                    discard;
                }
                block_color *= tint_color;
            #else
                vec4 block_color = texture2D(tex, texcoord) * tint_color;
            #endif
        #else
            vec4 block_color = texture2D(tex, texcoord) * tint_color;
        #endif

        float block_luma = luma(block_color.rgb);

        vec3 final_candle_color = candle_color;
        #if defined GBUFFER_TERRAIN || defined GBUFFER_HAND
            if (emmisive_type > 0.5) {
                final_candle_color *= block_luma * 1.5;
            }
        #endif

        #ifdef GBUFFER_WEATHER
            block_color.a *= .5;
        #endif

        #if defined GBUFFER_ENTITIES
            if (entityId == 10101) {
                block_color.a = 1.0;
            }
        #endif

        // Определяем shadow_c как vec3 для поддержки цветных теней
        vec3 shadow_c;
        #if defined SHADOW_CASTING && !defined NETHER
            #if defined COLORED_SHADOW
                shadow_c = get_colored_shadow(shadow_pos, dither); // vec3 для цветных теней
                shadow_c = mix(shadow_c, vec3(1.0), shadow_diffuse);
            #else
                float shadow_scalar = get_shadow(shadow_pos, dither); // float для обычных теней
                shadow_c = vec3(mix(shadow_scalar, 1.0, shadow_diffuse)); // Преобразуем в vec3
            #endif
        #else
            float shadow_scalar = abs((light_mix * 2.0) - 1.0);
            shadow_c = vec3(shadow_scalar); // vec3 для консистентности
        #endif

        // Добавляем эффект дыма
        float smoke_alpha = calculate_smoke(sub_position3, texcoord, dither);
        vec3 smoke_color = vec3(0.7, 0.7, 0.8); // Цвет дыма (серо-голубой)
        smoke_color *= shadow_c * (1.0 - rainStrength * 0.5); // Учитываем тени и дождь
        block_color.rgb = mix(block_color.rgb, smoke_color, smoke_alpha);
        block_color.a = max(block_color.a, smoke_alpha * 0.5); // Прозрачность дыма

        #if defined MATERIAL_GLOSS && !defined NETHER
            float final_gloss_power = gloss_power * 1.5; // Увеличиваем силу глянца на 50%
            block_luma *= luma_factor;

            if (luma_power < 0.0) {
                final_gloss_power -= (block_luma * 73.334);
            } else {
                block_luma = pow(block_luma, luma_power);
            }

            float material_gloss_factor = material_gloss(reflect(normalize(sub_position3), flat_normal), lmcoord_alt, final_gloss_power, flat_normal) * gloss_factor * 1.2; // Усиливаем фактор глянца

            float material = material_gloss_factor * block_luma * 1.3; // Увеличиваем вклад материала
            vec3 real_light = omni_light +
                (shadow_c * ((direct_light_color * direct_light_strength * 1.2) + (direct_light_color * material))) * (1.0 - (rainStrength * 0.75)) +
                final_candle_color;
        #else
            vec3 real_light = omni_light +
                (shadow_c * direct_light_color * direct_light_strength) * (1.0 - (rainStrength * 0.75)) +
                final_candle_color;
        #endif

        block_color.rgb *= mix(real_light, vec3(1.0), nightVision * 0.125);
        block_color.rgb *= mix(vec3(1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

        #if defined GBUFFER_ENTITIES
            if (entityId == 10101) {
                block_color = vec4(1.0, 1.0, 1.0, 0.5);
            } else {
                float entity_poderation = luma(real_light);
                block_color.rgb = mix(block_color.rgb, entityColor.rgb, entityColor.a * entity_poderation * 3.0);
            }
        #endif

        #if MC_VERSION < 11300 && defined GBUFFER_TEXTURED
            block_color.rgb *= 1.5;
        #endif

        vec4 final_color = clamp(block_color, vec4(0.0), vec4(50.0));
    #endif

    #include "/src/finalcolor.glsl"
    #include "/src/writebuffers.glsl"
}