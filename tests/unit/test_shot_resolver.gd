extends GutTest
## M2: ShotResolver implements spec §7.6 exactly (>= 25 cases).

const C: float = 0.82


func _w(ctx: ShotContext) -> ShotWindows:
	return ShotResolver.compute_windows(ctx)


func _base() -> ShotContext:
	return ShotContext.make(10, 5.0, 0.0)  # mid zone, J10, open


# --- base widths & boundaries --------------------------------------------

func test_base_widths_at_jumper_10_mid() -> void:
	var w: ShotWindows = _w(_base())
	assert_eq(w.zone, "mid")
	assert_almost_eq(w.center, C, 0.0001)
	assert_almost_eq(w.perfect, 0.05, 0.0001)
	assert_almost_eq(w.good, 0.12, 0.0001)
	assert_almost_eq(w.near, 0.22, 0.0001)


func test_perfect_at_center() -> void:
	assert_eq(ShotResolver.grade(C, _w(_base()), 0.0), "PERFECT")


func test_perfect_inner_boundary() -> void:
	assert_eq(ShotResolver.grade(C + 0.0249, _w(_base()), 0.0), "PERFECT")
	assert_eq(ShotResolver.grade(C - 0.0249, _w(_base()), 0.0), "PERFECT")


func test_good_just_outside_perfect() -> void:
	assert_eq(ShotResolver.grade(C + 0.0251, _w(_base()), 0.0), "GOOD")
	assert_eq(ShotResolver.grade(C - 0.0251, _w(_base()), 0.0), "GOOD")


func test_good_outer_boundary() -> void:
	assert_eq(ShotResolver.grade(C + 0.0599, _w(_base()), 0.0), "GOOD")
	assert_eq(ShotResolver.grade(C - 0.0599, _w(_base()), 0.0), "GOOD")


func test_near_miss_band() -> void:
	assert_eq(ShotResolver.grade(C + 0.0601, _w(_base()), 0.0), "NEAR_MISS")
	assert_eq(ShotResolver.grade(C - 0.1099, _w(_base()), 0.0), "NEAR_MISS")


func test_brick_outside_near() -> void:
	assert_eq(ShotResolver.grade(C - 0.1101, _w(_base()), 0.0), "BRICK")
	assert_eq(ShotResolver.grade(0.0, _w(_base()), 0.0), "BRICK")


func test_holding_past_full_is_brick() -> void:
	var ctx: ShotContext = _base()
	ctx.wind_drift = 0.15   # push the window toward the top
	assert_eq(ShotResolver.grade(1.0, _w(ctx), 0.0), "BRICK")
	assert_eq(ShotResolver.grade(1.2, _w(_base()), 0.0), "BRICK")


# --- jumper scaling --------------------------------------------------------

func test_jumper_scaling_to_40() -> void:
	var ctx: ShotContext = _base()
	ctx.jumper = 40
	var w: ShotWindows = _w(ctx)
	assert_almost_eq(w.perfect, 0.05 + 30 * 0.0015, 0.0001)
	var k: float = w.perfect / 0.05
	assert_almost_eq(w.good, 0.12 * k, 0.0001, "good scales proportionally")
	assert_almost_eq(w.near, 0.22 * k, 0.0001, "near scales proportionally")


func test_jumper_scaling_40_to_60() -> void:
	var ctx: ShotContext = _base()
	ctx.jumper = 60
	assert_almost_eq(_w(ctx).perfect, 0.05 + 30 * 0.0015 + 20 * 0.0005, 0.0001)


func test_jumper_no_gain_past_60() -> void:
	var a: ShotContext = _base()
	a.jumper = 60
	var b: ShotContext = _base()
	b.jumper = 75
	assert_almost_eq(_w(a).perfect, _w(b).perfect, 0.00001)


func test_jumper_below_10_shrinks() -> void:
	var ctx: ShotContext = _base()
	ctx.jumper = 9
	assert_almost_eq(_w(ctx).perfect, 0.05 - 0.0015, 0.0001)


# --- zones -----------------------------------------------------------------

func test_zone_boundaries() -> void:
	assert_eq(ShotResolver.zone_for(2.99), "close")
	assert_eq(ShotResolver.zone_for(3.0), "mid")
	assert_eq(ShotResolver.zone_for(6.74), "mid")
	assert_eq(ShotResolver.zone_for(6.75), "three")
	assert_eq(ShotResolver.zone_for(8.74), "three")
	assert_eq(ShotResolver.zone_for(8.75), "deep")


func test_zone_multipliers() -> void:
	var close: ShotContext = ShotContext.make(10, 2.0)
	var three: ShotContext = ShotContext.make(10, 7.5)
	var deep: ShotContext = ShotContext.make(10, 10.0)
	assert_almost_eq(_w(close).perfect, 0.05 * 1.5, 0.0001)
	assert_almost_eq(_w(three).perfect, 0.05 * 0.85, 0.0001)
	assert_almost_eq(_w(deep).perfect, 0.05 * 0.6, 0.0001)
	assert_almost_eq(_w(deep).near, 0.22 * 0.6, 0.0001)


# --- contest ---------------------------------------------------------------

func test_contest_shrinks_windows() -> void:
	var ctx: ShotContext = _base()
	ctx.contest = 0.5
	assert_almost_eq(_w(ctx).perfect, 0.05 * (1.0 - 0.6 * 0.5), 0.0001)
	ctx.contest = 1.0
	assert_almost_eq(_w(ctx).good, 0.12 * 0.4, 0.0001)


func test_contest_from_geometry() -> void:
	var shooter: Vector3 = Vector3.ZERO
	assert_eq(ShotResolver.contest_of(shooter, Vector3(0, 0, -5), Vector3(0, 0, 1), 3.0), 0.0, "out of radius")
	var near_facing: float = ShotResolver.contest_of(shooter, Vector3(0, 0, -0.5), Vector3(0, 0, 1), 3.0)
	assert_gte(near_facing, 0.85, "smothered when right on top and facing")
	var turned: float = ShotResolver.contest_of(shooter, Vector3(0, 0, -0.5), Vector3(0, 0, -1), 3.0)
	assert_eq(turned, 0.0, "facing away does not contest")


# --- modifiers -------------------------------------------------------------

func test_stepback_modifier() -> void:
	var ctx: ShotContext = _base()
	ctx.stepback = true
	assert_almost_eq(_w(ctx).perfect, 0.05 * 1.4, 0.0001)


func test_wide_open_modifier() -> void:
	var ctx: ShotContext = _base()
	ctx.wide_open = true
	assert_almost_eq(_w(ctx).perfect, 0.10, 0.0001)


func test_takeover_modifier() -> void:
	var ctx: ShotContext = _base()
	ctx.takeover = true
	assert_almost_eq(_w(ctx).perfect, 0.05 * 1.6, 0.0001)


func test_low_wind_modifier() -> void:
	var ctx: ShotContext = _base()
	ctx.wind_ratio = 0.2
	assert_almost_eq(_w(ctx).perfect, 0.05 * 0.8, 0.0001)
	ctx.wind_ratio = 0.25
	assert_almost_eq(_w(ctx).perfect, 0.05, 0.0001, "exactly 25% is not low")


func test_gear_multiplier_and_flat_bonus() -> void:
	var ctx: ShotContext = _base()
	ctx.window_mult = 1.2
	assert_almost_eq(_w(ctx).perfect, 0.06, 0.0001)
	var ctx2: ShotContext = _base()
	ctx2.perfect_bonus = 0.01
	assert_almost_eq(_w(ctx2).perfect, 0.06, 0.0001)


func test_rookie_mode() -> void:
	var ctx: ShotContext = _base()
	ctx.rookie = true
	assert_almost_eq(_w(ctx).perfect, 0.05 * 1.25, 0.0001)


func test_modifiers_stack_multiplicatively() -> void:
	var ctx: ShotContext = ShotContext.make(10, 7.5, 0.0)
	ctx.stepback = true
	ctx.takeover = true
	assert_almost_eq(_w(ctx).perfect, 0.05 * 0.85 * 1.4 * 1.6, 0.0001)


# --- caps & nesting ----------------------------------------------------------

func test_perfect_cap() -> void:
	var ctx: ShotContext = ShotContext.make(60, 1.0)
	ctx.wide_open = true
	ctx.takeover = true
	ctx.stepback = true
	var w: ShotWindows = _w(ctx)
	assert_almost_eq(w.perfect, 0.25, 0.0001, "capped at 0.25")
	assert_gte(w.good, w.perfect)
	assert_gte(w.near, w.good)


func test_windows_always_nested() -> void:
	for j: int in [1, 9, 10, 25, 40, 60]:
		for d: float in [1.0, 5.0, 7.0, 12.0]:
			var w: ShotWindows = _w(ShotContext.make(j, d, 0.9))
			assert_lte(w.perfect, w.good)
			assert_lte(w.good, w.near)


func test_wind_drift_moves_center() -> void:
	var ctx: ShotContext = _base()
	ctx.wind_drift = -0.1
	var w: ShotWindows = _w(ctx)
	assert_almost_eq(w.center, 0.72, 0.0001)
	assert_eq(ShotResolver.grade(0.72, w, 0.0), "PERFECT")
	assert_eq(ShotResolver.grade(0.82, w, 0.0), "NEAR_MISS")


# --- rejection -------------------------------------------------------------

func test_smothered_near_miss_is_rejected() -> void:
	var w: ShotWindows = _w(_base())
	assert_eq(ShotResolver.grade(C + 0.07, w, 0.85), "REJECTED")


func test_smothered_brick_is_rejected() -> void:
	assert_eq(ShotResolver.grade(0.1, _w(_base()), 0.9), "REJECTED")


func test_smothered_good_still_counts() -> void:
	var ctx: ShotContext = _base()
	ctx.contest = 0.9
	var w: ShotWindows = _w(ctx)
	assert_eq(ShotResolver.grade(w.center, w, 0.9), "PERFECT")


func test_contest_below_smother_not_rejected() -> void:
	assert_eq(ShotResolver.grade(0.1, _w(_base()), 0.84), "BRICK")


func test_is_make() -> void:
	assert_true(ShotResolver.is_make("PERFECT"))
	assert_true(ShotResolver.is_make("GOOD"))
	assert_false(ShotResolver.is_make("NEAR_MISS"))
	assert_false(ShotResolver.is_make("REJECTED"))
