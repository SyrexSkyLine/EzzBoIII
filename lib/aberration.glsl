/* MakeUp - aberration.glsl
Эффект цветовой аберрации с fisheye/bodycam дисторсией, краевым искажением, эффектами бодикама, экспозицией, виньеткой, дрожанием камеры, черными полосами, сканлайнами, шумом, настройками цвета, закругленным искажениями, круговой маской, черным закруглением по FOV, эффектом линзы, motion blur, отображением PNG-изображения, эффектом качания руки и эффектом бликов (lens flare).
*/

// Настраиваемые параметры
#define DISTORTION_STRENGTH -0.4 // Fisheye distortion strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define HORIZONTAL_EDGE_STRENGTH 0.3 // Horizontal edge distortion strength [0.0 0.3 0.6 0.9 1.2 1.5]
#define VERTICAL_EDGE_STRENGTH 1.6 // Vertical edge distortion strength [0.0 0.4 0.8 1.2 1.6]
#define CORNER_DISTORT_STRENGTH 0.5 // Corner distortion strength [0.0 0.3 0.6 0.9 1.2 1.5]
#define CIRCULAR_DISTORT_STRENGTH 1.0 // Circular distortion strength [0.0 0.3 0.6 0.9 1.2 1.5]
#define ZOOM 1.0 // Image zoom level [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define CHROMA_ABER_STRENGTH 0.0011 // Chromatic aberration strength [0.0 0.0005 0.001 0.0015 0.002 0.0025 0.003 0.0035 0.004 0.0045 0.005 0.01 0.015 0.02 0.025 0.03 0.035 0.04 0.045 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05]
#define NOISE_STRENGTH 0.00 // Noise strength for bodycam effect [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
#define FLICKER_STRENGTH 0.02 // Brightness flicker strength [0.0 0.01 0.02 0.03 0.04 0.05]
#define SCANLINE_STRENGTH 0.00 // Scanline effect strength [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
#define SCANLINE_WIDTH 800.0 // Scanline density [500.0 600.0 700.0 800.0 900.0 1000.0 1100.0 1200.0 1300.0 1400.0 1500.0]
#define EXPOSURE 0.2 // Exposure level (-ve for darker, +ve for brighter) [-2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0]
#define VIGNETTE_STRENGTH 0.78 // Main vignette strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define VIGNETTE_RADIUS 0.001 // Main vignette radius [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define CORNER_VIGNETTE_STRENGTH 0.4 // Corner vignette strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define INTENSITY_CAM_SHAKE 0.01 // Camera shake intensity [0.0 0.002 0.004 0.006 0.008 0.01]
#define BLACK_STRIPES_WIDTH 0.05 // Black stripes width [0.0 0.02 0.04 0.06 0.08 0.1]
#define BLACK_STRIPES_SOFT 0.05 // Black stripes edge softness [0.0 0.01 0.02 0.03 0.04 0.05]
#define SATURATION 1.0 // Color saturation [0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define BRIGHTNESS 0.0 // Brightness adjustment [-0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5]
#define CONTRAST 1.0 // Contrast adjustment [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define IMAGE_ROUNDING_RADIUS 5.0 // Image rounding distortion radius [0.1 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.3]
#define IMAGE_VERTICAL_STRENGTH 0.2 // Vertical image rounding strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define IMAGE_HORIZONTAL_STRENGTH 0.2 // Horizontal image rounding strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define IMAGE_ROUND_STRENGTH 0.8 // Circular image mask strength [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define BLACK_FOV 70.0 // Black FOV rounding field of view [1.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0]
#define LENS_STRENGTH -0.05 // Lens effect strength [-0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define MOTION_BLUR_RADIUS 0.25 // Motion blur (Shake) radius [0.02 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define MOTION_BLUR_STRENGTH 0.0011 // Motion blur (Shake) strength [0.0011 0.005 0.01 0.015 0.02 0.025 0.03 0.035 0.04 0.045 0.05]
#define MOTION_BLUR_MOUSE_STRENGTH 1.02 // Motion blur (Mouse) strength [1.0 1.01 1.02 1.03 1.04 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0]
#define IMAGE_POSITION 0 // AXON.png image position (0 = right, 1 = left) [0 1]
#define GLITCH_STRENGTH 0.000 // Glitch distortion strength [0.0 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.01]
#define ENABLE_HORIZONTAL_GLITCH 0 // Enable horizontal glitch effect [0 1]
#define HAND_SWAY_STRENGTH 0.002 // Hand sway strength [0.0 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.01]
#define LENS_FLARE_STRENGTH 0.5 // Lens flare intensity [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define LENS_FLARE_SCALE 1.3 // Lens flare size [0.1 0.2 0.3 0.4 0.5]
#define LENS_FLARE_STREAKS 5 // Number of flare streaks [2 3 4 5 6]

// Uniform-переменные
uniform float frameTimeCounter;
uniform vec3 viewDir;
uniform vec2 mouseDelta;
uniform vec3 sunPosition; // Позиция солнца в пространстве
#ifdef USE_PNG_TEXTURE
uniform sampler2D texture; // Текстура для AXON.png
#endif

// Простая функция шума
float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Функция дрожания камеры
vec2 cameraShake(float frameTimeCounter, float intensity) {
    return vec2(
        intensity * sin(frameTimeCounter * 1.5),
        intensity * cos(frameTimeCounter * 1.85)
    );
}

// Функция качания руки
vec2 handSway(float frameTimeCounter, float intensity) {
    return vec2(
        intensity * sin(frameTimeCounter * 2.0),
        intensity * cos(frameTimeCounter * 2.5)
    );
}

// Функция черного закругления на основе FOV
float blackFOVMask(vec2 coord) {
    vec2 centered = abs(coord - 0.5);
    float fovScale = 1.0 / (0.01 + 0.99 * (BLACK_FOV / 100.0));
    float r = length(centered * fovScale);
    return 1.0 - smoothstep(0.7, 1.0, r);
}

// Функция эффекта линзы
vec2 lensDistortion(vec2 coord) {
    vec2 centered = coord - 0.5;
    float r = length(centered);
    float lens_effect = LENS_STRENGTH * (1.0 - r * r);
    float scale = 1.0 + lens_effect;
    return centered * scale + 0.5;
}

// Функция искажения "рыбий глаз"
vec2 DistortPosition(vec2 coord) {
    vec2 centered = coord - 0.5;
    float distortionFactor = length(centered) + 0.1;
    distortionFactor = 1.0 + DISTORTION_STRENGTH * (distortionFactor - 1.0);
    centered /= distortionFactor;
    return centered + 0.5;
}

// Функция закругленного искажения изображения
vec2 imageRoundedDistortion(vec2 coord) {
    vec2 centered = coord - 0.5;
    vec2 scaled = centered / vec2(1.0 - IMAGE_HORIZONTAL_STRENGTH, 1.0 - IMAGE_VERTICAL_STRENGTH);
    float r = length(scaled / IMAGE_ROUNDING_RADIUS);
    vec2 glitch_offset = GLITCH_STRENGTH * vec2(
        ENABLE_HORIZONTAL_GLITCH * random(coord + vec2(frameTimeCounter, 0.0)),
        random(coord + vec2(frameTimeCounter, 1.0))
    );
    float mask = smoothstep(1.0, 1.0 - BLACK_STRIPES_SOFT, r);
    return mix(coord + glitch_offset, vec2(0.5), 1.0 - mask);
}

// Функция круговой маски изображения
float ImageRound(vec2 coord) {
    vec2 centered = abs(coord - 0.5);
    float r = length(centered / IMAGE_ROUND_STRENGTH);
    float glitch = GLITCH_STRENGTH * 10.0 * random(coord + vec2(frameTimeCounter));
    return 1.0 - clamp(smoothstep(0.7, 0.7 + glitch, r), 0.0, 1.0);
}

// Функция motion blur (Shake)
vec3 motionBlurTest(vec2 coord, vec3 color) {
    vec2 centered = coord - 0.5;
    float r = length(centered);
    float blur_mask = 1.0 - smoothstep(MOTION_BLUR_RADIUS * 0.8, MOTION_BLUR_RADIUS, r);
    if (blur_mask <= 0.0) return color;

    vec2 blur_dir = vec2(cos(frameTimeCounter * 2.0), sin(frameTimeCounter * 2.0)) * MOTION_BLUR_STRENGTH;
    vec3 blurred_color = vec3(0.0);
    const int samples = 5;
    for (int i = -samples / 2; i <= samples / 2; i++) {
        vec2 offset = blur_dir * float(i) / float(samples / 2);
        blurred_color += texture2D(colortex1, coord + offset).rgb;
    }
    blurred_color /= float(samples);
    return mix(color, blurred_color, blur_mask);
}

// Функция motion blur при движении мыши
vec3 motionBlurMouse(vec2 coord, vec3 color) {
    #ifdef USE_MOUSE_DELTA
    vec2 motion = mouseDelta;
    #else
    vec2 motion = vec2(viewDir.x, viewDir.y) * sin(frameTimeCounter * 0.5) * 0.01;
    #endif
    float motion_magnitude = length(motion);
    if (motion_magnitude < 0.0001) return color;

    vec2 blur_dir = normalize(motion) * MOTION_BLUR_MOUSE_STRENGTH * motion_magnitude;
    vec3 blurred_color = vec3(0.0);
    const int samples = 7;
    for (int i = -samples / 2; i <= samples / 2; i++) {
        vec2 offset = blur_dir * float(i) / float(samples / 2);
        blurred_color += texture2D(colortex1, coord + offset).rgb;
    }
    blurred_color /= float(samples);
    return mix(color, blurred_color, clamp(motion_magnitude * 10.0, 0.0, 1.0));
}

// Функция для отображения AXON.png
vec3 drawImage(vec2 coord, vec3 base_color) {
    #ifdef USE_PNG_TEXTURE
    vec2 image_size = vec2(0.2, 0.2 * (textureSize(texture, 0).y / textureSize(texture, 0).x));
    vec2 image_pos;
    if (IMAGE_POSITION == 0) {
        image_pos = vec2(1.0 - image_size.x - 0.02, 0.02); // Справа
    } else {
        image_pos = vec2(0.02, 0.02); // Слева
    }
    if (coord.x >= image_pos.x && coord.x <= image_pos.x + image_size.x &&
        coord.y >= image_pos.y && coord.y <= image_pos.y + image_size.y) {
        vec2 tex_coord = (coord - image_pos) / image_size;
        tex_coord = lensDistortion(tex_coord); // Применяем линзовое искажение
        vec4 image_color = texture2D(texture, tex_coord);
        float flicker = (random(tex_coord + vec2(frameTimeCounter)) * 2.0 - 1.0) * FLICKER_STRENGTH;
        image_color.rgb *= (1.0 + flicker);
        return mix(base_color, image_color.rgb, image_color.a);
    }
    #endif
    return base_color;
}

// Функция эффекта бликов (lens flare)
vec3 lensFlare(vec2 coord, vec3 base_color) {
    // Вычисляем угол между направлением взгляда и позицией солнца
    float sunDot = dot(normalize(viewDir), normalize(sunPosition));
    float flareIntensity = smoothstep(0.8, 1.0, sunDot) * LENS_FLARE_STRENGTH;

    if (flareIntensity <= 0.0) return base_color;

    vec2 centered = coord - 0.5;
    vec3 flareColor = vec3(1.0, 0.9, 0.7); // Теплый цвет бликов
    vec3 flareResult = vec3(0.0);

    // Основной блик (яркое пятно)
    float r = length(centered);
    float glow = exp(-r * r / (LENS_FLARE_SCALE * LENS_FLARE_SCALE)) * flareIntensity;
    flareResult += flareColor * glow;

    // Стрелы бликов
    for (int i = 0; i < LENS_FLARE_STREAKS; i++) {
        float angle = float(i) * 3.14159 / float(LENS_FLARE_STREAKS);
        vec2 streakDir = vec2(cos(angle), sin(angle));
        float streak = dot(centered, streakDir);
        streak = exp(-streak * streak / (LENS_FLARE_SCALE * 0.5)) * flareIntensity * 0.5;
        flareResult += flareColor * streak;
    }

    return base_color + flareResult;
}

// Основная функция обработки
vec3 color_aberration() {
    vec2 centered = (texcoord - 0.5) * ZOOM + 0.5;
    vec2 lens_texcoord = lensDistortion(centered);
    vec2 rounded_texcoord = imageRoundedDistortion(lens_texcoord);
    float x_dist = abs(rounded_texcoord.x - 0.5);
    float y_dist = abs(rounded_texcoord.y - 0.5);
    float r = length(rounded_texcoord - 0.5);
    vec2 shake = cameraShake(frameTimeCounter, INTENSITY_CAM_SHAKE) + handSway(frameTimeCounter, HAND_SWAY_STRENGTH);
    vec2 glitch_offset = GLITCH_STRENGTH * vec2(
        ENABLE_HORIZONTAL_GLITCH * random(rounded_texcoord + vec2(frameTimeCounter)),
        random(rounded_texcoord + vec2(frameTimeCounter, 1.0))
    );
    vec2 fish_texcoord = DistortPosition(rounded_texcoord + shake + glitch_offset);
    float edge_factor = smoothstep(0.3, 0.7, r);
    vec2 edge_distortion = vec2(
        1.0 + HORIZONTAL_EDGE_STRENGTH * (x_dist * x_dist),
        1.0 + VERTICAL_EDGE_STRENGTH * (y_dist * y_dist)
    );
    vec2 edge_distort = (rounded_texcoord + shake - 0.5) * edge_distortion + 0.5;
    float corner_factor = x_dist * y_dist;
    vec2 corner_distortion = vec2(
        1.0 + CORNER_DISTORT_STRENGTH * corner_factor,
        1.0 + CORNER_DISTORT_STRENGTH * corner_factor
    );
    vec2 corner_distort = (rounded_texcoord + shake - 0.5) * corner_distortion + 0.5;
    float circular_factor = smoothstep(0.4, 0.8, r);
    vec2 circular_distortion = vec2(
        1.0 + CIRCULAR_DISTORT_STRENGTH * (r * r),
        1.0 + CIRCULAR_DISTORT_STRENGTH * (r * r)
    );
    vec2 circular_distort = (rounded_texcoord + shake - 0.5) * circular_distortion + 0.5;
    vec2 final_texcoord = mix(fish_texcoord, edge_distort, edge_factor);
    final_texcoord = mix(final_texcoord, corner_distort, corner_factor * CORNER_DISTORT_STRENGTH);
    final_texcoord = mix(final_texcoord, circular_distort, circular_factor);
    vec2 offset = (final_texcoord - 0.5) * CHROMA_ABER_STRENGTH * (1.0 + r);
    vec3 aberrated_color = vec3(0.0);
    aberrated_color.r = texture2D(colortex1, final_texcoord + offset).r;
    aberrated_color.g = texture2D(colortex1, final_texcoord).g;
    aberrated_color.b = texture2D(colortex1, final_texcoord - offset).b;
    aberrated_color = motionBlurTest(final_texcoord, aberrated_color);
    aberrated_color = motionBlurMouse(final_texcoord, aberrated_color);
    aberrated_color = lensFlare(texcoord, aberrated_color); // Добавляем эффект бликов
    float round_mask = ImageRound(texcoord);
    aberrated_color = mix(aberrated_color, vec3(0.0), 1.0 - round_mask);
    float noise = (random(texcoord + vec2(frameTimeCounter)) - 0.5) * NOISE_STRENGTH;
    aberrated_color += noise;
    float flicker = (random(texcoord + vec2(0.1, 0.2)) * 2.0 - 1.0) * FLICKER_STRENGTH;
    aberrated_color *= (1.0 + flicker);
    float scanline = sin(final_texcoord.y * SCANLINE_WIDTH) * SCANLINE_STRENGTH;
    aberrated_color += scanline;
    aberrated_color *= pow(2.0, EXPOSURE);
    float vignette = smoothstep(VIGNETTE_RADIUS, VIGNETTE_RADIUS + VIGNETTE_STRENGTH, r);
    aberrated_color = mix(aberrated_color, vec3(0.0), vignette);
    float corner_vignette = corner_factor * CORNER_VIGNETTE_STRENGTH;
    aberrated_color = mix(aberrated_color, vec3(0.0), corner_vignette);
    float leftStripe = smoothstep(BLACK_STRIPES_WIDTH, BLACK_STRIPES_WIDTH - BLACK_STRIPES_SOFT, texcoord.x);
    float rightStripe = smoothstep(1.0 - BLACK_STRIPES_WIDTH, 1.0 - (BLACK_STRIPES_WIDTH - BLACK_STRIPES_SOFT), texcoord.x);
    float stripeEffect = max(leftStripe, rightStripe);
    aberrated_color = mix(aberrated_color, vec3(0.0), stripeEffect);
    float fov_mask = blackFOVMask(texcoord);
    aberrated_color = mix(aberrated_color, vec3(0.0), 1.0 - fov_mask);
    float average = (aberrated_color.r + aberrated_color.g + aberrated_color.b) / 3.0;
    aberrated_color = mix(vec3(average), aberrated_color, SATURATION);
    aberrated_color += BRIGHTNESS;
    aberrated_color = ((aberrated_color - 0.5) * CONTRAST) + 0.5;
    aberrated_color = drawImage(texcoord, aberrated_color);
    return aberrated_color;
}