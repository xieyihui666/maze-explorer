extends Node2D

var fog_mat: ShaderMaterial

func _ready():
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 player_pos;
void fragment() {
	float dist = distance(FRAGCOORD.xy, player_pos);
	float alpha = 1.0 - smoothstep(170.0, 220.0, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha * 0.92);
}
"""
	fog_mat = ShaderMaterial.new()
	fog_mat.shader = shader
	$FogRect.material = fog_mat
	$FogRect.size = Vector2(10000, 10000)
	$FogRect.position = Vector2(-4000, -4000)

func _process(_delta):
	var pp = get_parent().player_pos
	var cam = get_parent().get_node("Camera2D")
	var sp = get_viewport().get_visible_rect().size / 2 + (pp - cam.global_position) * cam.zoom
	fog_mat.set_shader_parameter("player_pos", sp)
