--!strict
--[[
	The legendaries' idle sway, as data: which parts swing, about which pivot,
	on what curve.

	THE PARTS SWING RIGIDLY, NOT BY SKINNING, AND THE BLEND FILES SAY THAT IS
	EXACT. The meshes in `Config.LEGENDARIES` are skinned, but a skinned
	MeshPart made by `CreateMeshPartAsync` did not deform under Bone instances
	rebuilt at runtime -- measured, a 35-degree bone turn moved nothing, with
	the bones under a rig part and under the Body alike. It did not need to:
	every moving piece on the dragon and the tiger is weighted 100% to ONE
	bone, so rotating the whole part about that bone's head is the same
	motion. The phoenix's crest, mantle and ruff feathers are blended about
	half and half with Root; their pivots sit at the feather roots and the
	sway is 1.5 to 3 degrees, so the whole-part rotation moves a root by
	about a tenth of a stud.

	PIVOTS ARE THE BLENDER BONE HEADS (`*-complete.blend`, armature at the
	world origin) in Blender axes, mapped by `Legendary/Idle` through the same
	(x, y, z) -> (x, 6.62 + z, -y) every part offset uses.

	TRACKS ARE FITTED TO THE IMPORTED IDLE CLIPS, NOT TYPED.
	`ServerStorage.RBX_ANIMSAVES.<key>-idle` holds the three KeyframeSequences
	the importer made. Every track is a sine on the clip's 4-second loop, so
	each is stored as an axis and
	`angle(t) = a * sin(2 pi t / period) + b * cos(2 pi t / period)` radians;
	fitted against all 121 frames, the worst error is 0.17 degrees. The axis
	is in the RIG frame, which is the seat frame turned a half about Y like
	every legendary part (the importer's convention). Storing the fit also
	sidesteps the importer's Tail track, which carries a constant half turn
	and a 493-stud offset on all three clips: the sway underneath is clean,
	the constant is not motion.

	The Storm Wolf has no rig. Its motion is the lightning.
]]

export type Track = { axis: Vector3, a: number, b: number }
export type Bone = { name: string, head: Vector3, track: Track, parts: { string } }
export type Rig = { period: number, bones: { Bone } }

local X = Vector3.new(0.99504, -0.09950, 0)

local Rigs: { [string]: Rig } = {
	dragon = {
		period = 4,
		bones = {
			{ name = "Tail", head = Vector3.new(0, 4.62, 1.74),
				track = { axis = Vector3.new(0, 0, -1), a = 0.05235, b = 0 },
				parts = { "Tail", "Dragon_Tail_Ember", "Dragon_Tail_ScaleDark", "Dragon_Tail_ScaleLit", "Dragon_Tail_ScaleMid", "Dragon_Tail_WingMembrane" } },
			{ name = "Wing_L", head = Vector3.new(-4.32, 1.08, 2.10),
				track = { axis = Vector3.new(0, 0, 1), a = 0.08725, b = 0 },
				parts = { "Dragon_Wing_L_Ember", "Dragon_Wing_L_WingFrame", "Dragon_Wing_L_WingMembrane", "Dragon_Wing_L_WingShade" } },
			{ name = "Wing_R", head = Vector3.new(4.32, 1.08, 2.10),
				track = { axis = Vector3.new(0, 0, -1), a = 0.08725, b = 0 },
				parts = { "Dragon_Wing_R_Ember", "Dragon_Wing_R_WingFrame", "Dragon_Wing_R_WingMembrane", "Dragon_Wing_R_WingShade" } },
		},
	},
	rainbowtiger = {
		period = 4,
		bones = {
			{ name = "Tail", head = Vector3.new(0, 4.62, 1.74),
				track = { axis = Vector3.new(0, 0, -1), a = 0.05235, b = 0 },
				parts = { "Tail", "TailPlume" } },
			{ name = "Ruff_L", head = Vector3.new(-3.60, -3.00, 1.50),
				track = { axis = Vector3.new(0, 0, 1), a = 0.02094, b = 0 },
				parts = { "CheekFill_-1", "CheekFur_-1" } },
			{ name = "Ruff_R", head = Vector3.new(3.60, -3.00, 1.50),
				track = { axis = Vector3.new(0, 0, 1), a = 0.02094, b = 0 },
				parts = { "CheekFill_1", "CheekFur_1" } },
		},
	},
	phoenix = {
		period = 4,
		bones = {
			{ name = "Tail", head = Vector3.new(0, 4.62, 1.74),
				track = { axis = Vector3.new(0, 0, 1), a = -0.04862, b = -0.01941 },
				parts = { "Tail", "Phoenix_Tail_Feathers" } },
			{ name = "Mantle_L", head = Vector3.new(-3.60, 1.20, 1.80),
				track = { axis = -X, a = 0.01897, b = 0.01804 },
				parts = { "Phoenix_Mantle_L_Feathers" } },
			{ name = "Mantle_R", head = Vector3.new(3.60, 1.20, 1.80),
				track = { axis = -X, a = 0.01092, b = 0.02379 },
				parts = { "Phoenix_Mantle_R_Feathers" } },
			{ name = "Ruff_L", head = Vector3.new(-3.48, -3.66, 0.96),
				track = { axis = -X, a = 0.00266, b = 0.05229 },
				parts = { "Phoenix_Ruff_L_Feathers" } },
			{ name = "Ruff_R", head = Vector3.new(3.48, -3.66, 0.96),
				track = { axis = X, a = 0.01692, b = -0.04955 },
				parts = { "Phoenix_Ruff_R_Feathers" } },
			{ name = "Crest_0", head = Vector3.new(0, -2.82, 5.40),
				track = { axis = X, a = 0.03409, b = -0.03973 },
				parts = { "Phoenix_Crest_0_Feathers" } },
			{ name = "Crest_1", head = Vector3.new(-1.62, -3.06, 5.04),
				track = { axis = X, a = 0.04640, b = -0.02424 },
				parts = { "Phoenix_Crest_1_Feathers" } },
			{ name = "Crest_2", head = Vector3.new(1.62, -3.06, 5.04),
				track = { axis = X, a = 0.05208, b = -0.00531 },
				parts = { "Phoenix_Crest_2_Feathers" } },
		},
	},
}

return Rigs
