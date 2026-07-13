shader_type spatial;
render_mode cull_back, depth_draw_opaque; // 100% Opaque, normal culling

uniform bool has_nose = true;
uniform bool has_doors = true;
uniform vec3 stripe_color : source_color = vec3(0.0, 0.35, 0.75); // Shinkansen blue
uniform vec3 base_color : source_color = vec3(0.95, 0.95, 0.95); // Shinkansen white

instance uniform float door_progress_left = 0.0;
instance uniform float door_progress_right = 0.0;

instance uniform bool use_livery = false;
uniform sampler2D livery_texture : source_color, filter_linear_mipmap;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
    local_pos = VERTEX;
    local_normal = NORMAL;
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

    if (has_doors && H > 0.2 && H < 2.3) {
        float d1 = 3.75;
        float d2 = 16.25;
        
        int num_doors_to_draw = has_nose ? 1 : 2;
        for (int i=0; i<num_doors_to_draw; i++) {
            float d_center = (i == 0) ? d1 : d2;
            
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
    if (H > 0.4 && H < 0.8) {
        color = stripe_color; // Main blue stripe at the bottom
    }
    if (H > 2.4 && H < 2.5) {
        color = stripe_color; // Thin blue accent stripe at the top
    }
    
    if (is_sliding_door) {
        color = vec3(0.9); // Silver doors
        if (abs(L - door_center_for_window) < 0.4 && H > 1.5 && H < 2.1) {
            is_window = true;
        }
    } else {
        if (H > 1.4 && H < 2.3 && !is_door_hole) {
            // Passenger windows
            if (L > 5.5 && L < 14.5) {
                float dist_from_start = L - 5.5;
                float window_idx = floor(dist_from_start / 1.5);
                float window_offset = mod(dist_from_start, 1.5);
                if (window_offset > 0.2 && window_offset < 1.3) {
                    is_window = true;
                }
            }
        }
    }
    
    // --- Shinkansen Bullet Nose Front Painting ---
    if (has_nose && L >= 16.0) {
        is_window = false;
        
        // Cockpit window shape (covers across the entire width, straight back edge, rounded front edge)
        if (L >= 17.0 && H > 1.5 && L <= 18.5) {
            vec3 obj_normal = normalize(cross(dFdx(local_pos), dFdy(local_pos)));
            
            // Only draw on surfaces that point upwards (the roof/slope), not the vertical sides
            if (abs(obj_normal.y) > 0.1) {
                // Front edge is an ellipse: center at L=17.0, center_W=0.
                float norm_W = center_W / 1.5; // 0 at center, 1 at edges
                float norm_L = (L - 17.0) / 1.2; // max length 1.2 at center
                
                if (norm_W * norm_W + norm_L * norm_L <= 1.0) {
                    is_window = true;
                }
            }
        }
        
        if (!is_window) {
            // Sleek blue nose line at the bottom
            if (H > 0.3 && H < 0.6) {
                color = stripe_color;
            } else {
                color = base_color;
            }
            
            // Bullet train headlights on the nose sides
            if (L > 18.5 && L < 19.5 && H > 0.6 && H < 0.85 && center_W > 0.8 && center_W < 1.1) {
                color = vec3(1.0, 1.0, 0.8); // Glowing headlight color
            }
        }
    }
    
    // --- Apply Livery ---
    if (use_livery && center_W > 1.4 && (!has_nose || L < 16.0)) {
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
}
