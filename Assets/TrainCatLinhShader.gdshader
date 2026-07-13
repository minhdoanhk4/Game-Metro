shader_type spatial;
render_mode cull_back, depth_draw_opaque; // 100% Opaque, normal culling

uniform bool has_nose = true;
uniform vec3 stripe_color : source_color = vec3(0.0, 0.55, 0.85);
uniform vec3 base_color : source_color = vec3(0.85, 0.85, 0.85);

instance uniform float door_progress_left = 0.0;
instance uniform float door_progress_right = 0.0;

instance uniform bool use_livery = false;
uniform sampler2D livery_texture : source_color, filter_linear_mipmap;

varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    vec3 color = base_color; // Base Body Color
    
    float L = local_pos.x;
    float H = local_pos.y;
    float W = abs(local_pos.z);
    float center_W = abs(W - 1.5); 
    
    bool is_window = false;
    
    // --- Door Sliding Logic ---
    bool is_door_hole = false;
    bool is_sliding_door = false;
    float door_center_for_window = 0.0;
    
    float max_slide = 0.75;
    float current_slide = (local_pos.z > -1.5) ? (door_progress_right * max_slide) : (door_progress_left * max_slide);

    if (H > 0.2 && H < 2.5) {
        float d1 = 3.5;
        float d2 = 7.8;
        float d3 = 12.2;
        float d4 = 16.5;
        
        for (int i=0; i<4; i++) {
            float d_center = (i == 0) ? d1 : ((i == 1) ? d2 : ((i == 2) ? d3 : d4));
            
            if (abs(L - d_center) < 0.75) {
                is_door_hole = true;
            }
            
            if (L > d_center - 0.75 - current_slide && L < d_center - current_slide) {
                is_sliding_door = true;
                door_center_for_window = d_center - current_slide;
            }
            if (L > d_center + current_slide && L < d_center + 0.75 + current_slide) {
                is_sliding_door = true;
                door_center_for_window = d_center + current_slide;
            }
        }
    }
    
    if (is_door_hole && !is_sliding_door) {
        discard;
    }

    // --- Side Painting ---
    if (is_sliding_door) {
        color = vec3(0.75); // Silver doors
        if (abs(L - door_center_for_window) < 0.4 && H > 1.5 && H < 2.3) {
            is_window = true;
        }
    } else {
        if (H > 0.4 && H < 0.9) {
            color = stripe_color;
        }
        if (H > 1.4 && H < 2.5 && !is_door_hole) {
            if (mod(L, 3.0) < 0.2) {
                color = vec3(0.85); 
            } else {
                is_window = true;
            }
        }
    }
    
    // --- Front Painting ---
    if (has_nose && L >= 18.5) {
        float f = (L - 18.5) / 1.5; 
        float windshield_width = 1.3 - f * 0.2; 
        
        if (H > 1.5) {
            if (center_W < windshield_width) {
                is_window = true;
            } else {
                color = stripe_color;
                is_window = false;
            }
        } 
        else if (H > 0.5 && H <= 1.5) {
            is_window = false;
            if (center_W < 1.4) {
                color = vec3(0.95);
            } else {
                color = stripe_color; 
            }
            
            if (H > 0.8 && H < 1.1 && center_W > 0.9 && center_W < 1.2) {
                color = vec3(0.1); 
                if (abs(H - 0.95) < 0.08 && abs(center_W - 1.05) < 0.08) {
                    color = vec3(1.0, 1.0, 0.8);
                }
            }
            if (H > 0.6 && H < 0.9 && center_W < 0.3) {
                if (abs(center_W - 0.15) < 0.05) color = vec3(0.0, 0.8, 0.4); 
                else if (center_W < 0.1) color = vec3(1.0, 0.8, 0.0); 
            }
        }
        else {
            color = stripe_color; 
            is_window = false;
        }
    }
    
    // --- Apply Livery ---
    if (use_livery && center_W > 1.4 && (!has_nose || L < 18.5)) {
        float livery_L = L;
        if (is_sliding_door) {
             if (L < door_center_for_window) livery_L = L + current_slide;
             else livery_L = L - current_slide;
        }
        vec2 uv = vec2(livery_L / 20.0, 1.0 - (H / 3.5));
        vec4 liv_col = texture(livery_texture, uv);
        color = mix(color, liv_col.rgb, liv_col.a);
    }
    
    if (is_window) {
        color = vec3(0.02, 0.02, 0.04); // Opaque black glass
        ROUGHNESS = 0.05;
        METALLIC = 0.9;
    } else {
        ROUGHNESS = 0.4;
        METALLIC = 0.2;
    }

    ALBEDO = color;
    // 100% Opaque!
}
