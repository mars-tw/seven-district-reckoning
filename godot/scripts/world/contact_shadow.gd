extends MeshInstance3D
## A small shared contact cue for the shadow-free browser preset.
static var _material: StandardMaterial3D

func _ready() -> void:
	if not _material:
		var image_value := Image.create(32,32,false,Image.FORMAT_RGBA8)
		for y: int in 32:
			for x: int in 32:
				var radius: float = Vector2((float(x)-15.5)/15.5,(float(y)-15.5)/15.5).length()
				image_value.set_pixel(x,y,Color(0.02,0.03,0.035,pow(maxf(0,1-radius),1.4)*0.26))
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_texture = ImageTexture.create_from_image(image_value)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0,0.75)
	mesh = plane
	material_override = _material
	position.y = 0.08
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
