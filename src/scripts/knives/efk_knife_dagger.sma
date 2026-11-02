#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <efk_core>
#include <efk_utils>

new const PLUGIN[] = "EFK: Dagger Knife"

/*
 * Dagger Knife (753BC + razi)
 *
 * MOUSE2  - Boomerang Dagger: the dagger flies in a straight line, pierces enemies
 *           (damage decreases with every next hit) and returns to the owner.
 *           LMB/RMB are blocked while the dagger is in flight. Life Leech is applied
 *           after the dagger returns (only if it hit someone).
 * E       - Sacrificial Blood: -20 HP, +15 damage for 8 sec. Life Leech does not work
 *           while it is active. Can't be used below 35 HP.
 * Passive - Bloodthirst: damage dealt in one life (HE and gas are not counted)
 *           unlocks stages 100 / 150 / 250 / 400 / 525.
 * Passive - Hunter's Mark: enemies with low HP are marked (20% -> 45% of max HP).
 * Passive - Life Leech: knife damage restores HP gradually.
 */

#define KNIFE_CLASSNAME		"weapon_next21_dagger"
#define KNIFE_MENUDESC		"KNIFE_DAGGER_DESC"
#define KNIFE_CHATDESC		"KNIFE_DAGGER_CHAT"

#define HP					105.0
#define GRAVITY				1.0
#define SPEED				250.0
#define MINDAMAGE			0.0
#define MAXDAMAGE			0.0

#define KNIFE_LEVEL			2

// MOUSE2 - Boomerang Dagger
#define ABIL1_NAME			"Dagger"
#define ABIL1_CHARGE		8.334		// 12 sec
#define ABIL1_TYPE			ABIL_NORMAL

// E - Sacrificial Blood
#define ABIL2_NAME			"Sacrificial Blood"
#define ABIL2_CHARGE		6.667		// 15 sec

// Melee damage (body hit, headshot x4 and backstab x3 are kept)
#define LMB_DAMAGE			10.0
#define RMB_DAMAGE			55.0

// Sacrificial Blood
#define SB_HEALTH_COST		20.0
#define SB_DAMAGE_BONUS		15.0
#define SB_DURATION			8.0
#define SB_MIN_HEALTH		35
#define SB_GLOW_R			150
#define SB_GLOW_G			0
#define SB_GLOW_B			0

// Bloodthirst. Index = stage (0 - no stage, 5 - last stage)
#define BT_MAX_STAGE			5
#define BT_INSTANT_LEECH_STAGE	4	// Instant Leech appears
#define BT_UNCAPPED_STAGE		5	// max HP limit is removed, shop regeneration is disabled

new const Float:BT_THRESHOLDS[BT_MAX_STAGE]				= { 100.0, 150.0, 250.0, 400.0, 525.0 }
new const Float:BT_LMB_BONUS[BT_MAX_STAGE + 1]			= { 0.0, 1.0, 2.0, 3.0, 4.0, 5.0 }
new const Float:BT_RMB_BONUS[BT_MAX_STAGE + 1]			= { 0.0, 3.0, 6.0, 9.0, 12.0, 15.0 }
new const Float:MARK_THRESHOLD[BT_MAX_STAGE + 1]		= { 0.20, 0.25, 0.30, 0.35, 0.40, 0.45 }
new const Float:LEECH_RATIO[BT_MAX_STAGE + 1]			= { 0.20, 0.25, 0.30, 0.35, 0.40, 0.50 }
new const DAGGER_MAX_TARGETS[BT_MAX_STAGE + 1]			= { 2, 3, 4, 5, 6, 7 }
new const Float:DAGGER_DAMAGE[BT_MAX_STAGE + 1]			= { 30.0, 34.0, 38.0, 42.0, 46.0, 50.0 }
new const BT_STAGE_NAMES[BT_MAX_STAGE + 1][]			= { "0", "I", "II", "III", "IV", "V" }

// Hunter's Mark
#define MARK_MODE_SLOW			(1<<0)	// marked enemies are slowed when the owner damages them
#define MARK_MODE_SPEED			(1<<1)	// the owner gets a speed bonus near marked enemies
#define MARK_SLOW_POWER			0.75
#define MARK_SLOW_TIME			1.5
#define MARK_SPEED_BONUS		30.0
#define MARK_SPEED_RADIUS		450.0
#define LOW_HP_THRESHOLD		25.0
#define LOW_HP_SPEED_PENALTY	35.0
#define MARK_GLOW_AMOUNT		12

// Life Leech
#define LEECH_DURATION			2.0		// pending heal is spread over this time
#define LEECH_INTERRUPT_WINDOW	1.0		// damage taken within this time after the start cancels the heal
#define LEECH_INSTANT_PART		0.4		// Instant Leech: part of the heal applied immediately

// Boomerang Dagger
#define DAGGER_SPEED			1100.0
#define DAGGER_RETURN_SPEED		1400.0
#define DAGGER_MAX_DISTANCE		900.0
#define DAGGER_RETURN_TIMEOUT	3.0
#define DAGGER_CATCH_RADIUS		40.0
#define DAGGER_HIT_RADIUS		8.0
#define DAGGER_THINK_INTERVAL	0.02
#define DAGGER_DAMAGE_FALLOFF	0.75	// each next hit deals x0.75 of the previous one
#define DAGGER_BLOCK_ATTACK		5.0
#define DAGGER_SPIN_SPEED		1080.0
#define MAX_DAGGER_NPC_HITS		8
#define MAX_DAGGER_CANDIDATES	48

// Water Knife sphere interaction
new const WATER_SPHERE_TNAME[]	= "next21_watersphere"
#define WATER_SPHERE_RADIUS		256.0
#define var_dagger_crimson		var_iuser4
#define DAGGER_CRIMSON_MARK		753

#define TICK_INTERVAL			0.1
#define TASK_TICK				7530

// Placeholder resources: replace v/p models with the dagger models when they are ready
new const MODEL_V_KNIFE[]		= "models/next21_efk/v_swap_knife_b03.mdl"
new const MODEL_P_KNIFE[]		= "models/next21_efk/p_swap_knife_r2.mdl"
new const MODEL_DAGGER[]		= "models/next21_efk/tknife_a01.mdl"

new const SPRITE_TRAIL[]		= "sprites/laserbeam.spr"
new const SPRITE_BLOOD[]		= "sprites/blood.spr"
new const SPRITE_BLOODSPRAY[]	= "sprites/bloodspray.spr"

new const SOUND_DAGGER_THROW[]	= "next21_efk/tknife_shoot1.wav"
new const SOUND_DAGGER_HIT[]	= "next21_efk/tknife_hit.wav"
new const SOUND_DAGGER_WALL[]	= "next21_efk/tknife_wall.wav"
new const SOUND_DAGGER_CATCH[]	= "weapons/knife_deploy1.wav"
new const SOUND_SACRIFICE[]		= "common/bodysplat.wav"
new const SOUND_STAGE_UP[]		= "next21_efk/soul_pulse.wav"
new const SOUND_FAIL_ABILITY[]	= "next21_efk/fail_ability.wav"

new const CLASSNAME_DAGGER[]	= "next21_dagger"
new const SZ_INFO_TARGET[]		= "info_target"
new const WEAPON_KNIFE_STR[]	= "weapon_knife"

#define VIEW_SEQ_DRAW			3

#define bit(%1)					(1 << ((%1) & 31))

enum
{
	ATTACK_NONE,
	ATTACK_SLASH,
	ATTACK_STAB
}

enum
{
	DAGGER_NONE,
	DAGGER_FLY,
	DAGGER_RETURN
}

new g_iKnifeId = -1, g_pKnifePMdl
new g_pTrailSpr, g_pBloodSpr, g_pBloodSpraySpr
new g_iVampItemId = -1, g_iRegenItemId = -1, bool:g_bNoFindItem, bool:g_bNoViewAction
new g_iMarkMode

new g_iPlrKnife[MAX_PLAYERS + 1] = { -1, ... }
new g_iAttackType[MAX_PLAYERS + 1]
new Float:g_fPreHealth[MAX_PLAYERS + 1]

// Bloodthirst
new Float:g_fBtDamage[MAX_PLAYERS + 1], g_iBtStage[MAX_PLAYERS + 1]

// Sacrificial Blood
new Float:g_fSBEndTime[MAX_PLAYERS + 1]

// Life Leech
new Float:g_fLeechPool[MAX_PLAYERS + 1], Float:g_fLeechStart[MAX_PLAYERS + 1], Float:g_fLeechEnd[MAX_PLAYERS + 1]

// Hunter's Mark
new g_iMarkMask[MAX_PLAYERS + 1], Float:g_fAppliedSpeed[MAX_PLAYERS + 1]

// Items suppressed by the knife
new bool:g_bVampSuppressed[MAX_PLAYERS + 1], bool:g_bRegenSuppressed[MAX_PLAYERS + 1]

// Boomerang Dagger (one dagger per owner)
new g_iDagger[MAX_PLAYERS + 1], g_iDaggerState[MAX_PLAYERS + 1]
new g_iDaggerHits[MAX_PLAYERS + 1], g_iDaggerHitMask[MAX_PLAYERS + 1]
new g_iDaggerNpcHits[MAX_PLAYERS + 1][MAX_DAGGER_NPC_HITS], g_iDaggerNpcHitsNum[MAX_PLAYERS + 1]
new Float:g_fDaggerDamage[MAX_PLAYERS + 1], Float:g_fDaggerDistance[MAX_PLAYERS + 1]
new Float:g_fDaggerReturnStart[MAX_PLAYERS + 1], Float:g_vDaggerLast[MAX_PLAYERS + 1][3]

public plugin_natives()
{
	set_native_filter("native_filter")
}

// Allows the plugin to load on a core without the new natives (item restrictions are disabled then)
public native_filter(const szNative[], iIndex, iTrap)
{
	if (equal(szNative, "kc_find_item") || equal(szNative, "kc_player_get_view_action"))
	{
		if (!iTrap)
		{
			if (equal(szNative, "kc_find_item"))
				g_bNoFindItem = true
			else
				g_bNoViewAction = true
		}

		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

public plugin_precache()
{
	precache_model(MODEL_V_KNIFE)
	g_pKnifePMdl = precache_model(MODEL_P_KNIFE)
	precache_model(MODEL_DAGGER)

	g_pTrailSpr = precache_model(SPRITE_TRAIL)
	g_pBloodSpr = precache_model(SPRITE_BLOOD)
	g_pBloodSpraySpr = precache_model(SPRITE_BLOODSPRAY)

	precache_sound(SOUND_DAGGER_THROW)
	precache_sound(SOUND_DAGGER_HIT)
	precache_sound(SOUND_DAGGER_WALL)
	precache_sound(SOUND_DAGGER_CATCH)
	precache_sound(SOUND_SACRIFICE)
	precache_sound(SOUND_STAGE_UP)
	precache_sound(SOUND_FAIL_ABILITY)

	precache_generic(fmt("sprites/%s.txt", KNIFE_CLASSNAME))
}

public plugin_init()
{
	register_plugin(PLUGIN, EFK_VERSION, "753BC + razi")

	g_iKnifeId = kc_register_knife(KNIFE_CLASSNAME, KNIFE_MENUDESC, KNIFE_CHATDESC,
		engfunc(EngFunc_AllocString, MODEL_V_KNIFE), engfunc(EngFunc_AllocString, MODEL_P_KNIFE),
		g_pKnifePMdl, HP, GRAVITY, SPEED, MINDAMAGE, MAXDAMAGE)

	if (g_iKnifeId < 0)
		set_fail_state("[%s] error registration", PLUGIN)

	kc_register_ability1(g_iKnifeId, ABIL1_NAME, ABIL1_CHARGE, ABIL1_TYPE)
	kc_register_ability2(g_iKnifeId, ABIL2_NAME, ABIL2_CHARGE)
	kc_knife_set_flags(g_iKnifeId, KNFF_ABIL1_TOGGLEABLE)
	kc_knife_set_level(g_iKnifeId, KNIFE_LEVEL)
	kc_knife_set_anim_ext(g_iKnifeId, ANIM_EXT_DUAL_KNIVES)

	bind_pcvar_num(create_cvar("efk_dagger_mark_mode", "1", FCVAR_NONE,
		"Hunter's Mark interaction: 1 - marked enemies are slowed when hit, 2 - speed bonus near marked enemies, 3 - both",
		true, 1.0, true, 3.0), g_iMarkMode)

	register_logevent("fw_RoundStart", 2, "1=Round_Start")

	RegisterHookChain(RG_CBasePlayer_Spawn, "fw_PlayerSpawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "fw_PlayerKilled_Post", true)

	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage_Pre", false)
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage_Post", true)
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_KNIFE_STR, "fw_KnifePrimaryAttack_Pre", false)
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_KNIFE_STR, "fw_KnifeAttack_Post", true)
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_KNIFE_STR, "fw_KnifeSecondaryAttack_Pre", false)
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_KNIFE_STR, "fw_KnifeAttack_Post", true)
	RegisterHam(Ham_Item_Deploy, WEAPON_KNIFE_STR, "fw_KnifeDeploy_Post", true)

	register_forward(FM_AddToFullPack, "fw_AddToFullPack_Post", true)

	set_task(TICK_INTERVAL, "task_tick", TASK_TICK, _, _, "b")
}

public plugin_cfg()
{
	if (g_bNoFindItem)
	{
		log_amx("[%s] kc_find_item is not available, vampirism/regeneration restrictions are disabled", PLUGIN)
		return
	}

	g_iVampItemId = kc_find_item("ITEM_VAMPIRISM")
	g_iRegenItemId = kc_find_item("ITEM_REGENERATION")
}

public client_putinserver(iPlayer)
{
	g_iPlrKnife[iPlayer] = -1
	g_bVampSuppressed[iPlayer] = false
	g_bRegenSuppressed[iPlayer] = false
	reset_life(iPlayer)
}

public client_disconnected(iPlayer)
{
	dagger_remove(iPlayer)
	reset_life(iPlayer)

	g_iPlrKnife[iPlayer] = -1
	g_bVampSuppressed[iPlayer] = false
	g_bRegenSuppressed[iPlayer] = false
}

/* ---------------------------------------------------------------------------------- */
/* Core callbacks                                                                      */
/* ---------------------------------------------------------------------------------- */

public efk_change_knife_core_post(iPlayer, iKnifeId)
{
	new iOldKnifeId = g_iPlrKnife[iPlayer]
	g_iPlrKnife[iPlayer] = iKnifeId

	if (iOldKnifeId == iKnifeId)
		return

	if (iOldKnifeId == g_iKnifeId)
	{
		dagger_remove(iPlayer)
		reset_life(iPlayer)
		restore_regen(iPlayer)
		restore_vamp(iPlayer)
	}
	else if (iKnifeId == g_iKnifeId)
	{
		reset_life(iPlayer)
	}
}

// MOUSE2 - Boomerang Dagger
public efk_ability(iPlayer, iTarget)
{
	if (g_iDagger[iPlayer])
		return PLUGIN_HANDLED

	if (dagger_create(iPlayer) == NULLENT)
		return PLUGIN_HANDLED

	return PLUGIN_CONTINUE
}

// E - Sacrificial Blood
public efk_ability2(iPlayer)
{
	new Float:fHealth = Float:get_entvar(iPlayer, var_health)

	if (fHealth < SB_MIN_HEALTH)
	{
		client_cmd(iPlayer, "spk %s", SOUND_FAIL_ABILITY)
		client_print(iPlayer, print_center, "%L", iPlayer, "DAGGER_SB_LOW_HEALTH", SB_MIN_HEALTH)
		return PLUGIN_HANDLED
	}

	// Direct health change: it is not damage, so it does not interrupt anything and is not counted anywhere
	set_entvar(iPlayer, var_health, fHealth - SB_HEALTH_COST)

	// Life Leech does not work while Sacrificial Blood is active
	g_fLeechPool[iPlayer] = 0.0
	g_fSBEndTime[iPlayer] = get_gametime() + SB_DURATION

	kc_player_add_glow(iPlayer, SB_DURATION, SB_GLOW_R, SB_GLOW_G, SB_GLOW_B)

	new Float:vOrigin[3]
	get_entvar(iPlayer, var_origin, vOrigin)
	vOrigin[2] += 16.0
	send_msg_TE_BLOODSPRITE(vOrigin, g_pBloodSpraySpr, g_pBloodSpr, 247, 12)
	send_msg_TE_DLIGHT(vOrigin, 14, {180, 0, 0}, 8, 30)

	if (kc_player_get_vision(iPlayer) != VISION_BLIND)
		send_msg_ScreenFade((1<<10), (1<<9), 0, {150, 0, 0}, 90, MSG_ONE, _, iPlayer)

	engfunc(EngFunc_EmitSound, iPlayer, CHAN_STATIC, SOUND_SACRIFICE, 1.0, ATTN_NORM, 0, PITCH_LOW)

	return PLUGIN_CONTINUE
}

public efk_apply_damage(iVictim, iAttacker, &Float:fBaseDamage, &Float:fPowerDamage, &Float:fAddDamage)
{
	if (!is_entity_player(iAttacker) || g_iPlrKnife[iAttacker] != g_iKnifeId)
		return

	new iStage = g_iBtStage[iAttacker]
	new Float:fHeadMul = (get_member(iVictim, m_LastHitGroup) == _:HITGROUP_HEAD) ? 4.0 : 1.0

	switch (g_iAttackType[iAttacker])
	{
		case ATTACK_SLASH:
		{
			fBaseDamage = (LMB_DAMAGE + BT_LMB_BONUS[iStage]) * fHeadMul
		}
		case ATTACK_STAB:
		{
			// 65 - stab, 195 - backstab
			new Float:fBackMul = (fBaseDamage / fHeadMul > 100.0) ? 3.0 : 1.0
			fBaseDamage = (RMB_DAMAGE + BT_RMB_BONUS[iStage]) * fHeadMul * fBackMul
		}
	}

	if (sb_is_active(iAttacker))
		fAddDamage += SB_DAMAGE_BONUS
}

public efk_status_draw(iPlayer, iSubject, iKnifeId)
{
	if (iKnifeId != g_iKnifeId)
		return PLUGIN_CONTINUE

	static szText[192]
	new iLen, iStage = g_iBtStage[iSubject]

	if (iStage < BT_MAX_STAGE)
	{
		iLen = formatex(szText, charsmax(szText), "Bloodthirst %s [%d / %d]",
			BT_STAGE_NAMES[iStage], floatround(g_fBtDamage[iSubject], floatround_floor),
			floatround(BT_THRESHOLDS[iStage]))
	}
	else
	{
		iLen = formatex(szText, charsmax(szText), "Bloodthirst %s [MAX]", BT_STAGE_NAMES[iStage])
	}

	iLen += formatex(szText[iLen], charsmax(szText) - iLen, "^nHunter's Mark: %d%% HP",
		floatround(MARK_THRESHOLD[iStage] * 100.0))

	if (sb_is_active(iSubject))
	{
		iLen += formatex(szText[iLen], charsmax(szText) - iLen, "^nSacrificial Blood: %.1fs (+%d dmg)",
			g_fSBEndTime[iSubject] - get_gametime(), floatround(SB_DAMAGE_BONUS))
	}

	if (g_fLeechPool[iSubject] >= 1.0)
	{
		iLen += formatex(szText[iLen], charsmax(szText) - iLen, "^nLife Leech: +%d HP",
			floatround(g_fLeechPool[iSubject], floatround_floor))
	}

	if (g_iDagger[iSubject])
		formatex(szText[iLen], charsmax(szText) - iLen, "^nDagger in flight")

	set_hudmessage(220, 40, 40, 0.01, 0.27, 0, 0.0, 0.2, 0.2, 0.0, HUDCHANNEL_STATUS)
	show_hudmessage(iPlayer, "%s", szText)

	return PLUGIN_CONTINUE
}

/* ---------------------------------------------------------------------------------- */
/* Game hooks                                                                          */
/* ---------------------------------------------------------------------------------- */

public fw_RoundStart()
{
	for (new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		dagger_remove(iPlayer)
}

public fw_PlayerSpawn_Post(iPlayer)
{
	if (!is_user_alive(iPlayer))
		return HC_CONTINUE

	dagger_remove(iPlayer)
	reset_life(iPlayer)
	restore_regen(iPlayer)

	g_iPlrKnife[iPlayer] = kc_player_get_knife(iPlayer)
	if (g_iPlrKnife[iPlayer] != g_iKnifeId)
		restore_vamp(iPlayer)

	return HC_CONTINUE
}

public fw_PlayerKilled_Post(iVictim, iAttacker, iGib)
{
	// Bloodthirst progress is fully reset after death.
	// The vampirism mask stays disabled: it is restored when the knife is changed
	dagger_remove(iVictim)
	reset_life(iVictim)
	restore_regen(iVictim)

	return HC_CONTINUE
}

public fw_PlayerTakeDamage_Pre(iVictim, iInflictor, iAttacker, Float:fDamage, iFlags)
{
	g_fPreHealth[iVictim] = Float:get_entvar(iVictim, var_health)

	// The vampirism mask must neither work nor be consumed: disable it before its own TakeDamage hook runs
	if (is_entity_player(iAttacker) && iAttacker != iVictim && g_iPlrKnife[iAttacker] == g_iKnifeId)
		suppress_vamp(iAttacker)

	return HAM_IGNORED
}

public fw_PlayerTakeDamage_Post(iVictim, iInflictor, iAttacker, Float:fDamage, iFlags)
{
	new Float:fDealt = g_fPreHealth[iVictim] - floatmax(Float:get_entvar(iVictim, var_health), 0.0)
	if (fDealt <= 0.0)
		return HAM_IGNORED

	// Taking damage shortly after Life Leech has started interrupts it
	if (g_iPlrKnife[iVictim] == g_iKnifeId && iAttacker != iVictim)
		leech_interrupt(iVictim)

	if (!is_entity_player(iAttacker) || iAttacker == iVictim || g_iPlrKnife[iAttacker] != g_iKnifeId)
		return HAM_IGNORED

	if (get_member(iAttacker, m_iTeam) == get_member(iVictim, m_iTeam))
		return HAM_IGNORED

	if (is_excluded_damage(iInflictor, iFlags))
		return HAM_IGNORED

	bloodthirst_add(iAttacker, fDealt)

	new bool:bDagger = (iInflictor > 0 && iInflictor == g_iDagger[iAttacker])
	new bool:bMelee = (iInflictor == iAttacker && (iFlags & DMG_BULLET) && get_user_weapon(iAttacker) == CSW_KNIFE)

	if (!bDagger && !bMelee)
		return HAM_IGNORED

	if (bDagger)
		g_fDaggerDamage[iAttacker] += fDealt
	else
		leech_trigger(iAttacker, fDealt)

	if ((g_iMarkMode & MARK_MODE_SLOW) && (g_iMarkMask[iAttacker] & bit(iVictim)) && is_user_alive(iVictim))
		kc_player_slow(iVictim, MARK_SLOW_POWER, MARK_SLOW_TIME)

	water_sphere_check(iAttacker, iVictim)

	return HAM_IGNORED
}

public fw_KnifePrimaryAttack_Pre(iItem)
{
	return knife_attack_pre(iItem, ATTACK_SLASH)
}

public fw_KnifeSecondaryAttack_Pre(iItem)
{
	return knife_attack_pre(iItem, ATTACK_STAB)
}

public fw_KnifeAttack_Post(iItem)
{
	new iPlayer = get_member(iItem, m_pPlayer)
	if (is_entity_player(iPlayer))
		g_iAttackType[iPlayer] = ATTACK_NONE

	return HAM_IGNORED
}

public fw_KnifeDeploy_Post(iItem)
{
	new iPlayer = get_member(iItem, m_pPlayer)
	if (!is_entity_player(iPlayer) || !g_iDagger[iPlayer])
		return HAM_IGNORED

	// The dagger is still in flight - the hands stay empty
	hide_knife_models(iPlayer)
	block_item_attacks(iItem, DAGGER_BLOCK_ATTACK)

	return HAM_IGNORED
}

public fw_AddToFullPack_Post(es, e, iEnt, iHost, iHostFlags, iPlayer)
{
	if (!iPlayer || !(g_iMarkMask[iHost] & bit(iEnt)))
		return FMRES_IGNORED

	if (g_iPlrKnife[iHost] != g_iKnifeId || !is_user_alive(iHost))
		return FMRES_IGNORED

	if (get_es(es, ES_RenderFx) != kRenderFxNone
		|| get_es(es, ES_RenderMode) != kRenderNormal
		|| (get_es(es, ES_Effects) & EF_NODRAW))
	{
		return FMRES_IGNORED
	}

	// Never reveal invisible / disguised enemies
	new VisibilityType:iVisibility = kc_player_get_visibility(iEnt)
	if (iVisibility != VIS_NORMAL && iVisibility != VIS_GLOW)
		return FMRES_IGNORED

	if (kc_player_in_darkness(iHost))
		return FMRES_IGNORED

	set_es(es, ES_RenderFx, kRenderFxGlowShell)
	set_es(es, ES_RenderColor, {170, 0, 0})
	set_es(es, ES_RenderAmt, MARK_GLOW_AMOUNT)

	return FMRES_IGNORED
}

public task_tick()
{
	new Float:fGameTime = get_gametime()

	for (new iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (g_iPlrKnife[iPlayer] != g_iKnifeId || !is_user_alive(iPlayer))
		{
			g_iMarkMask[iPlayer] = 0
			continue
		}

		if (g_fSBEndTime[iPlayer] > 0.0 && fGameTime >= g_fSBEndTime[iPlayer])
			sb_end(iPlayer)

		leech_process(iPlayer, fGameTime)
		update_marks(iPlayer)
		update_speed(iPlayer)

		suppress_vamp(iPlayer)
		if (g_iBtStage[iPlayer] >= BT_UNCAPPED_STAGE)
			suppress_regen(iPlayer)
	}
}

/* ---------------------------------------------------------------------------------- */
/* Boomerang Dagger                                                                    */
/* ---------------------------------------------------------------------------------- */

dagger_create(iPlayer)
{
	new iEnt = rg_create_entity(SZ_INFO_TARGET)
	if (is_nullent(iEnt))
		return NULLENT

	new Float:vOrigin[3], Float:vViewOfs[3]
	get_entvar(iPlayer, var_origin, vOrigin)
	get_entvar(iPlayer, var_view_ofs, vViewOfs)
	xs_vec_add(vOrigin, vViewOfs, vOrigin)

	new Float:vAngles[3], Float:vForward[3]
	get_entvar(iPlayer, var_v_angle, vAngles)
	angle_vector(vAngles, ANGLEVECTOR_FORWARD, vForward)

	new Float:vVelocity[3], Float:vOffset[3]
	xs_vec_mul_scalar(vForward, 16.0, vOffset)
	xs_vec_add(vOrigin, vOffset, vOrigin)
	xs_vec_mul_scalar(vForward, DAGGER_SPEED, vVelocity)
	vector_to_angle(vForward, vAngles)

	engfunc(EngFunc_SetModel, iEnt, MODEL_DAGGER)
	engfunc(EngFunc_SetOrigin, iEnt, vOrigin)
	engfunc(EngFunc_SetSize, iEnt, Float:{-2.0, -2.0, -2.0}, Float:{2.0, 2.0, 2.0})

	set_entvar(iEnt, var_origin, vOrigin)
	set_entvar(iEnt, var_angles, vAngles)
	set_entvar(iEnt, var_velocity, vVelocity)
	set_entvar(iEnt, var_avelocity, Float:{0.0, DAGGER_SPIN_SPEED, 0.0})

	set_entvar(iEnt, var_solid, SOLID_TRIGGER)
	set_entvar(iEnt, var_movetype, MOVETYPE_FLY)
	set_entvar(iEnt, var_classname, CLASSNAME_DAGGER)
	set_entvar(iEnt, var_owner, iPlayer)
	set_entvar(iEnt, var_nextthink, get_gametime() + DAGGER_THINK_INTERVAL)

	SetThink(iEnt, "dagger_think")
	SetTouch(iEnt, "dagger_touch")

	send_msg_TE_BEAMFOLLOW(iEnt, g_pTrailSpr, 3, 2, {160, 0, 0}, 160)
	engfunc(EngFunc_EmitSound, iPlayer, CHAN_WEAPON, SOUND_DAGGER_THROW, 1.0, ATTN_NORM, 0, PITCH_NORM)

	g_iDagger[iPlayer] = iEnt
	g_iDaggerState[iPlayer] = DAGGER_FLY
	g_iDaggerHits[iPlayer] = 0
	g_iDaggerHitMask[iPlayer] = 0
	g_iDaggerNpcHitsNum[iPlayer] = 0
	g_fDaggerDamage[iPlayer] = 0.0
	g_fDaggerDistance[iPlayer] = 0.0
	g_fDaggerReturnStart[iPlayer] = 0.0
	xs_vec_copy(vOrigin, g_vDaggerLast[iPlayer])

	hide_knife_models(iPlayer)

	new iItem = get_member(iPlayer, m_pActiveItem)
	if (!is_nullent(iItem) && get_member(iItem, m_iId) == CSW_KNIFE)
		block_item_attacks(iItem, DAGGER_BLOCK_ATTACK)

	return iEnt
}

public dagger_think(iEnt)
{
	new iOwner = get_entvar(iEnt, var_owner)

	if (!is_entity_player(iOwner) || g_iDagger[iOwner] != iEnt)
	{
		set_entvar(iEnt, var_flags, FL_KILLME)
		return HC_CONTINUE
	}

	if (!is_user_alive(iOwner) || g_iPlrKnife[iOwner] != g_iKnifeId)
	{
		dagger_remove(iOwner)
		return HC_CONTINUE
	}

	new Float:fGameTime = get_gametime()
	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)

	if (g_iDaggerState[iOwner] == DAGGER_FLY)
	{
		dagger_sweep(iOwner, iEnt, g_vDaggerLast[iOwner], vOrigin)

		if (g_iDaggerState[iOwner] == DAGGER_FLY)
		{
			g_fDaggerDistance[iOwner] += get_distance_f(g_vDaggerLast[iOwner], vOrigin)
			if (g_fDaggerDistance[iOwner] >= DAGGER_MAX_DISTANCE)
				dagger_start_return(iOwner, iEnt)
		}
	}

	if (g_iDaggerState[iOwner] == DAGGER_RETURN)
	{
		new Float:vTarget[3], Float:vViewOfs[3], Float:vDir[3]
		get_entvar(iOwner, var_origin, vTarget)
		get_entvar(iOwner, var_view_ofs, vViewOfs)
		xs_vec_mul_scalar(vViewOfs, 0.5, vViewOfs)
		xs_vec_add(vTarget, vViewOfs, vTarget)

		xs_vec_sub(vTarget, vOrigin, vDir)
		new Float:fDistance = xs_vec_len(vDir)

		if (fDistance <= DAGGER_CATCH_RADIUS || fGameTime - g_fDaggerReturnStart[iOwner] >= DAGGER_RETURN_TIMEOUT)
		{
			dagger_catch(iOwner)
			return HC_CONTINUE
		}

		xs_vec_mul_scalar(vDir, DAGGER_RETURN_SPEED / fDistance, vDir)
		set_entvar(iEnt, var_velocity, vDir)
	}

	xs_vec_copy(vOrigin, g_vDaggerLast[iOwner])
	set_entvar(iEnt, var_nextthink, fGameTime + DAGGER_THINK_INTERVAL)

	return HC_CONTINUE
}

public dagger_touch(iEnt, iOther)
{
	new iOwner = get_entvar(iEnt, var_owner)
	if (!is_entity_player(iOwner) || g_iDagger[iOwner] != iEnt || g_iDaggerState[iOwner] != DAGGER_FLY)
		return HC_CONTINUE

	// Players and NPCs are handled by the sweep in dagger_think
	if (is_entity_player(iOther))
		return HC_CONTINUE

	if (!iOther)
	{
		dagger_hit_wall(iOwner, iEnt)
		return HC_CONTINUE
	}

	if (get_entvar(iOther, var_solid) <= SOLID_TRIGGER)
		return HC_CONTINUE

	if (FClassnameIs(iOther, "func_breakable") && get_entvar(iOther, var_rendermode) != kRenderNormal)
	{
		// Glass: break it and fly further
		ExecuteHamB(Ham_TakeDamage, iOther, iEnt, iOwner, 8000.0, DMG_GENERIC)
		return HC_CONTINUE
	}

	new szModel[2]
	get_entvar(iOther, var_model, szModel, charsmax(szModel))
	if (szModel[0] == '*')
		dagger_hit_wall(iOwner, iEnt)

	return HC_CONTINUE
}

// Finds everything the dagger passed through since the previous think and hits it in flight order
dagger_sweep(iOwner, iEnt, const Float:vFrom[3], const Float:vTo[3])
{
	new Float:vStart[3], Float:vEnd[3]
	xs_vec_copy(vFrom, vStart)
	xs_vec_copy(vTo, vEnd)

	new Float:fSegment = get_distance_f(vStart, vEnd)
	if (fSegment < 0.1)
		return

	new iCandidates[MAX_DAGGER_CANDIDATES], Float:fCandidateDist[MAX_DAGGER_CANDIDATES], iNum
	new Float:vMins[3], Float:vMaxs[3], Float:fDist
	new iOwnerTeam = get_member(iOwner, m_iTeam)

	for (new i = 1; i <= MaxClients && iNum < MAX_DAGGER_CANDIDATES; i++)
	{
		if (i == iOwner || !is_user_alive(i))
			continue

		if (get_member(i, m_iTeam) == iOwnerTeam || (g_iDaggerHitMask[iOwner] & bit(i)))
			continue

		if (kc_player_in_protection(i) || kc_player_get_visibility(i) == VIS_SHADOW)
			continue

		get_entvar(i, var_absmin, vMins)
		get_entvar(i, var_absmax, vMaxs)
		expand_box(vMins, vMaxs, DAGGER_HIT_RADIUS)

		if (line_intersects_box(vStart, vEnd, vMins, vMaxs, fDist))
		{
			iCandidates[iNum] = i
			fCandidateDist[iNum++] = fDist
		}
	}

	// Necro zombies and Ninja illusions
	new Float:vMiddle[3]
	xs_vec_add(vStart, vEnd, vMiddle)
	xs_vec_mul_scalar(vMiddle, 0.5, vMiddle)

	new iNpc = 0
	while ((iNpc = engfunc(EngFunc_FindEntityInSphere, iNpc, vMiddle, fSegment * 0.5 + 64.0)) > 0
		&& iNum < MAX_DAGGER_CANDIDATES)
	{
		if (iNpc <= MaxClients || !dagger_is_enemy_npc(iOwner, iNpc) || dagger_npc_was_hit(iOwner, iNpc))
			continue

		get_entvar(iNpc, var_absmin, vMins)
		get_entvar(iNpc, var_absmax, vMaxs)
		expand_box(vMins, vMaxs, DAGGER_HIT_RADIUS)

		if (line_intersects_box(vStart, vEnd, vMins, vMaxs, fDist))
		{
			iCandidates[iNum] = iNpc
			fCandidateDist[iNum++] = fDist
		}
	}

	// Sort by distance along the path, so "each next hit" really means the next enemy in the line
	for (new i = 1, j, iTmp, Float:fTmp; i < iNum; i++)
	{
		iTmp = iCandidates[i]
		fTmp = fCandidateDist[i]

		for (j = i - 1; j >= 0 && fCandidateDist[j] > fTmp; j--)
		{
			iCandidates[j + 1] = iCandidates[j]
			fCandidateDist[j + 1] = fCandidateDist[j]
		}

		iCandidates[j + 1] = iTmp
		fCandidateDist[j + 1] = fTmp
	}

	for (new i; i < iNum; i++)
	{
		if (g_iDagger[iOwner] != iEnt || g_iDaggerState[iOwner] != DAGGER_FLY)
			break

		dagger_hit(iOwner, iEnt, iCandidates[i])
	}
}

dagger_hit(iOwner, iEnt, iTarget)
{
	new bool:bPlayer = bool:is_entity_player(iTarget)

	if (bPlayer && !is_user_alive(iTarget))
		return

	if (bPlayer && kc_player_apply_concentblock(iTarget, iEnt, ATTACK_HEAVINESS_NORM, 150.0, true))
	{
		new Float:vOrigin[3]
		get_entvar(iEnt, var_origin, vOrigin)
		send_msg_TE_SPARKS(vOrigin)
		engfunc(EngFunc_EmitSound, iEnt, CHAN_AUTO, SOUND_DAGGER_WALL, 1.0, ATTN_NORM, 0, PITCH_NORM)

		dagger_start_return(iOwner, iEnt)
		return
	}

	new Float:fDamage = dagger_get_damage(iOwner)

	if (bPlayer)
	{
		g_iDaggerHitMask[iOwner] |= bit(iTarget)
		kc_player_set_death_reason(iTarget, "DEATH_REASON_DAGGER")
		set_member(iTarget, m_LastHitGroup, HIT_GENERIC)
	}
	else if (g_iDaggerNpcHitsNum[iOwner] < MAX_DAGGER_NPC_HITS)
	{
		g_iDaggerNpcHits[iOwner][g_iDaggerNpcHitsNum[iOwner]++] = iTarget
	}

	g_iDaggerHits[iOwner]++

	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)
	send_msg_TE_BLOODSPRITE(vOrigin, g_pBloodSpraySpr, g_pBloodSpr, 247, random_num(4, 8))
	engfunc(EngFunc_EmitSound, iTarget, CHAN_AUTO, SOUND_DAGGER_HIT, 1.0, ATTN_NORM, 0, PITCH_NORM)

	ExecuteHamB(Ham_TakeDamage, iTarget, iEnt, iOwner, fDamage, DMG_GENERIC)

	if (g_iDagger[iOwner] == iEnt && g_iDaggerState[iOwner] == DAGGER_FLY
		&& g_iDaggerHits[iOwner] >= DAGGER_MAX_TARGETS[g_iBtStage[iOwner]])
	{
		dagger_start_return(iOwner, iEnt)
	}
}

dagger_hit_wall(iOwner, iEnt)
{
	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)

	// Enemies between the last think position and the wall still get hit
	dagger_sweep(iOwner, iEnt, g_vDaggerLast[iOwner], vOrigin)
	xs_vec_copy(vOrigin, g_vDaggerLast[iOwner])

	if (g_iDagger[iOwner] != iEnt || g_iDaggerState[iOwner] != DAGGER_FLY)
		return

	send_msg_TE_SPARKS(vOrigin)
	engfunc(EngFunc_EmitSound, iEnt, CHAN_AUTO, SOUND_DAGGER_WALL, 1.0, ATTN_NORM, 0, PITCH_NORM)

	dagger_start_return(iOwner, iEnt)
}

dagger_start_return(iOwner, iEnt)
{
	g_iDaggerState[iOwner] = DAGGER_RETURN
	g_fDaggerReturnStart[iOwner] = get_gametime()

	// Comes back through anything and does not hit on the way back
	set_entvar(iEnt, var_solid, SOLID_NOT)
	set_entvar(iEnt, var_movetype, MOVETYPE_NOCLIP)
	set_entvar(iEnt, var_velocity, NULL_VECTOR)
	set_entvar(iEnt, var_nextthink, get_gametime())
}

dagger_catch(iOwner)
{
	new iEnt = g_iDagger[iOwner]
	new iHits = g_iDaggerHits[iOwner]
	new Float:fDamage = g_fDaggerDamage[iOwner]

	dagger_reset(iOwner)

	if (!is_nullent(iEnt))
		set_entvar(iEnt, var_flags, FL_KILLME)

	engfunc(EngFunc_EmitSound, iOwner, CHAN_ITEM, SOUND_DAGGER_CATCH, 1.0, ATTN_NORM, 0, PITCH_NORM)

	if (get_user_weapon(iOwner) == CSW_KNIFE)
	{
		new iItem = get_member(iOwner, m_pActiveItem)
		if (!is_nullent(iItem))
			block_item_attacks(iItem, 0.3, true)

		// Do not break item view actions (stimpak, mask...) - they redeploy the knife themselves
		if (g_bNoViewAction || kc_player_get_view_action(iOwner) == -1)
		{
			set_entvar(iOwner, var_viewmodel, MODEL_V_KNIFE)
			set_entvar(iOwner, var_weaponmodel, MODEL_P_KNIFE)
			kc_player_set_view_anim(iOwner, VIEW_SEQ_DRAW)
		}
	}

	// Life Leech after the return, only if the dagger hit someone
	if (iHits > 0 && fDamage > 0.0)
		leech_trigger(iOwner, fDamage)
}

// Silent removal (death, knife change, round start, disconnect)
dagger_remove(iOwner)
{
	new iEnt = g_iDagger[iOwner]
	if (!iEnt)
		return

	dagger_reset(iOwner)

	if (!is_nullent(iEnt))
		set_entvar(iEnt, var_flags, FL_KILLME)
}

dagger_reset(iOwner)
{
	g_iDagger[iOwner] = 0
	g_iDaggerState[iOwner] = DAGGER_NONE
	g_iDaggerHits[iOwner] = 0
	g_iDaggerHitMask[iOwner] = 0
	g_iDaggerNpcHitsNum[iOwner] = 0
	g_fDaggerDamage[iOwner] = 0.0
	g_fDaggerDistance[iOwner] = 0.0
}

Float:dagger_get_damage(iOwner)
{
	new Float:fDamage = DAGGER_DAMAGE[g_iBtStage[iOwner]]

	if (sb_is_active(iOwner))
		fDamage += SB_DAMAGE_BONUS

	return fDamage * floatpower(DAGGER_DAMAGE_FALLOFF, float(g_iDaggerHits[iOwner]))
}

bool:dagger_is_enemy_npc(iOwner, iEnt)
{
	new iTeam = get_member(iOwner, m_iTeam)

	switch (get_entvar(iEnt, var_impulse))
	{
		case IMPULSE_MINION: return get_entvar(iEnt, var_skin) + 1 != iTeam && !(get_entvar(iEnt, var_flags) & FL_KILLME)
		case IMPULSE_FAKEPLAYER: return get_entvar(iEnt, var_team) != iTeam
	}

	return false
}

bool:dagger_npc_was_hit(iOwner, iEnt)
{
	for (new i; i < g_iDaggerNpcHitsNum[iOwner]; i++)
	{
		if (g_iDaggerNpcHits[iOwner][i] == iEnt)
			return true
	}

	return false
}

knife_attack_pre(iItem, iAttackType)
{
	new iPlayer = get_member(iItem, m_pPlayer)
	if (!is_entity_player(iPlayer) || g_iPlrKnife[iPlayer] != g_iKnifeId)
		return HAM_IGNORED

	// No LMB/RMB while the dagger is in flight
	if (g_iDagger[iPlayer])
	{
		block_item_attacks(iItem, 0.2)
		return HAM_SUPERCEDE
	}

	g_iAttackType[iPlayer] = iAttackType
	return HAM_IGNORED
}

block_item_attacks(iItem, Float:fTime, bool:bForce = false)
{
	if (bForce || Float:get_member(iItem, m_Weapon_flNextPrimaryAttack) < fTime)
		set_member(iItem, m_Weapon_flNextPrimaryAttack, fTime)

	if (bForce || Float:get_member(iItem, m_Weapon_flNextSecondaryAttack) < fTime)
		set_member(iItem, m_Weapon_flNextSecondaryAttack, fTime)
}

hide_knife_models(iPlayer)
{
	if (get_user_weapon(iPlayer) != CSW_KNIFE || (!g_bNoViewAction && kc_player_get_view_action(iPlayer) != -1))
		return

	set_entvar(iPlayer, var_viewmodel, "")
	set_entvar(iPlayer, var_weaponmodel, "")
}

/* ---------------------------------------------------------------------------------- */
/* Bloodthirst                                                                         */
/* ---------------------------------------------------------------------------------- */

bloodthirst_add(iPlayer, Float:fDamage)
{
	g_fBtDamage[iPlayer] += fDamage

	new iStage = g_iBtStage[iPlayer]
	while (iStage < BT_MAX_STAGE && g_fBtDamage[iPlayer] >= BT_THRESHOLDS[iStage])
		iStage++

	if (iStage == g_iBtStage[iPlayer])
		return

	g_iBtStage[iPlayer] = iStage

	client_print(iPlayer, print_center, "%L", iPlayer, "DAGGER_BLOODTHIRST_STAGE", BT_STAGE_NAMES[iStage])
	client_cmd(iPlayer, "spk %s", SOUND_STAGE_UP)

	if (kc_player_get_vision(iPlayer) != VISION_BLIND)
		send_msg_ScreenFade((1<<10), (1<<8), 0, {200, 0, 0}, 60, MSG_ONE, _, iPlayer)

	if (iStage >= BT_UNCAPPED_STAGE)
		suppress_regen(iPlayer)
}

bool:is_excluded_damage(iInflictor, iFlags)
{
	// HE grenades and gas are not counted by Bloodthirst
	if (iFlags & DMG_GRENADE)
		return true

	if (iInflictor > MaxClients && !is_nullent(iInflictor))
	{
		if (FClassnameIs(iInflictor, "grenade") || FClassnameIs(iInflictor, "efk_gas"))
			return true
	}

	return false
}

/* ---------------------------------------------------------------------------------- */
/* Sacrificial Blood                                                                   */
/* ---------------------------------------------------------------------------------- */

bool:sb_is_active(iPlayer)
{
	return g_fSBEndTime[iPlayer] > get_gametime()
}

sb_end(iPlayer)
{
	if (g_fSBEndTime[iPlayer] == 0.0)
		return

	g_fSBEndTime[iPlayer] = 0.0

	if (is_user_connected(iPlayer))
		kc_player_sub_glow(iPlayer, SB_GLOW_R, SB_GLOW_G, SB_GLOW_B)
}

/* ---------------------------------------------------------------------------------- */
/* Life Leech                                                                          */
/* ---------------------------------------------------------------------------------- */

leech_trigger(iPlayer, Float:fDamage)
{
	// Does not work while Sacrificial Blood is active
	if (sb_is_active(iPlayer))
		return

	new iStage = g_iBtStage[iPlayer]
	new Float:fAmount = fDamage * LEECH_RATIO[iStage]
	if (fAmount <= 0.0)
		return

	if (iStage >= BT_INSTANT_LEECH_STAGE)
	{
		new Float:fInstant = fAmount * LEECH_INSTANT_PART
		leech_heal(iPlayer, fInstant)
		fAmount -= fInstant
	}

	new Float:fGameTime = get_gametime()
	g_fLeechPool[iPlayer] += fAmount
	g_fLeechStart[iPlayer] = fGameTime
	g_fLeechEnd[iPlayer] = fGameTime + LEECH_DURATION
}

leech_process(iPlayer, Float:fGameTime)
{
	if (g_fLeechPool[iPlayer] <= 0.0)
		return

	new Float:fRemain = g_fLeechEnd[iPlayer] - fGameTime
	new Float:fHeal = (fRemain <= TICK_INTERVAL)
		? g_fLeechPool[iPlayer]
		: g_fLeechPool[iPlayer] * (TICK_INTERVAL / fRemain)

	g_fLeechPool[iPlayer] = floatmax(0.0, g_fLeechPool[iPlayer] - fHeal)
	leech_heal(iPlayer, fHeal)
}

leech_interrupt(iPlayer)
{
	if (g_fLeechPool[iPlayer] > 0.0 && get_gametime() - g_fLeechStart[iPlayer] <= LEECH_INTERRUPT_WINDOW)
		g_fLeechPool[iPlayer] = 0.0
}

leech_heal(iPlayer, Float:fValue)
{
	if (fValue <= 0.0 || !is_user_alive(iPlayer))
		return

	// Not above the base max HP, except the last Bloodthirst stage
	new Float:fMaxHealth = (g_iBtStage[iPlayer] >= BT_UNCAPPED_STAGE)
		? MAX_PLAYER_HEALTH
		: Float:get_entvar(iPlayer, var_max_health)

	new Float:fHealth = Float:get_entvar(iPlayer, var_health)
	if (fHealth >= fMaxHealth)
		return

	set_entvar(iPlayer, var_health, floatmin(fHealth + fValue, fMaxHealth))
}

/* ---------------------------------------------------------------------------------- */
/* Hunter's Mark                                                                       */
/* ---------------------------------------------------------------------------------- */

update_marks(iPlayer)
{
	new iTeam = get_member(iPlayer, m_iTeam)
	new Float:fRatio = MARK_THRESHOLD[g_iBtStage[iPlayer]]
	new iMask

	for (new i = 1, Float:fMaxHealth; i <= MaxClients; i++)
	{
		if (i == iPlayer || !is_user_alive(i) || get_member(i, m_iTeam) == iTeam)
			continue

		fMaxHealth = kc_player_get_maxhealth(i)
		if (fMaxHealth <= 0.0)
			fMaxHealth = Float:get_entvar(i, var_max_health)

		if (Float:get_entvar(i, var_health) <= fMaxHealth * fRatio)
			iMask |= bit(i)
	}

	g_iMarkMask[iPlayer] = iMask
}

update_speed(iPlayer)
{
	new Float:fSpeed = SPEED

	if ((g_iMarkMode & MARK_MODE_SPEED) && g_iMarkMask[iPlayer] && is_marked_enemy_near(iPlayer))
		fSpeed += MARK_SPEED_BONUS

	if (Float:get_entvar(iPlayer, var_health) <= LOW_HP_THRESHOLD)
		fSpeed -= LOW_HP_SPEED_PENALTY

	if (fSpeed != g_fAppliedSpeed[iPlayer])
	{
		g_fAppliedSpeed[iPlayer] = fSpeed
		kc_player_set_def_maxspeed(iPlayer, fSpeed)
	}
}

bool:is_marked_enemy_near(iPlayer)
{
	new Float:vOrigin[3], Float:vTargetOrigin[3]
	get_entvar(iPlayer, var_origin, vOrigin)

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!(g_iMarkMask[iPlayer] & bit(i)) || !is_user_alive(i))
			continue

		get_entvar(i, var_origin, vTargetOrigin)
		if (get_distance_f(vOrigin, vTargetOrigin) <= MARK_SPEED_RADIUS)
			return true
	}

	return false
}

/* ---------------------------------------------------------------------------------- */
/* Water Knife sphere                                                                  */
/* ---------------------------------------------------------------------------------- */

water_sphere_check(iAttacker, iVictim)
{
	new Float:vOrigin[3], Float:vSphereOrigin[3]
	get_entvar(iVictim, var_origin, vOrigin)

	new iTeam = get_member(iAttacker, m_iTeam)
	new iEnt = 0, iShell

	while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "targetname", WATER_SPHERE_TNAME)) > 0)
	{
		iShell = get_entvar(iEnt, var_aiment)
		if (is_nullent(iShell))
			continue

		get_entvar(iShell, var_origin, vSphereOrigin)
		if (get_distance_f(vOrigin, vSphereOrigin) > WATER_SPHERE_RADIUS)
			continue

		// The water turns crimson
		if (get_entvar(iShell, var_dagger_crimson) != DAGGER_CRIMSON_MARK)
		{
			set_entvar(iShell, var_dagger_crimson, DAGGER_CRIMSON_MARK)
			set_entvar(iShell, var_renderfx, kRenderFxGlowShell)
			set_entvar(iShell, var_rendercolor, Float:{160.0, 0.0, 0.0})

			send_msg_TE_DLIGHT(vSphereOrigin, 40, {160, 0, 0}, 10, 20)
		}

		send_msg_TE_BLOODSPRITE(vOrigin, g_pBloodSpraySpr, g_pBloodSpr, 247, 10)

		// An enemy sphere stops healing: Water Knife heals only players of var_team
		new iSphereTeam = get_entvar(iShell, var_team)
		if (iSphereTeam != 0 && iSphereTeam != iTeam)
			set_entvar(iShell, var_team, 0)
	}
}

/* ---------------------------------------------------------------------------------- */
/* Items                                                                               */
/* ---------------------------------------------------------------------------------- */

suppress_vamp(iPlayer)
{
	if (g_iVampItemId < 0 || kc_player_get_item_value(iPlayer, g_iVampItemId) <= 0)
		return

	if (!kc_player_item_get_enabled(iPlayer, g_iVampItemId))
		return

	kc_player_item_set_enabled(iPlayer, g_iVampItemId, false)
	g_bVampSuppressed[iPlayer] = true

	client_print(iPlayer, print_center, "%L", iPlayer, "DAGGER_VAMPIRISM_BLOCKED")
}

restore_vamp(iPlayer)
{
	if (!g_bVampSuppressed[iPlayer])
		return

	g_bVampSuppressed[iPlayer] = false

	if (g_iVampItemId < 0 || !is_user_connected(iPlayer))
		return

	if (kc_player_get_item_value(iPlayer, g_iVampItemId) > 0 && !kc_player_item_get_enabled(iPlayer, g_iVampItemId))
		kc_player_item_set_enabled(iPlayer, g_iVampItemId, true)
}

suppress_regen(iPlayer)
{
	if (g_iRegenItemId < 0 || kc_player_get_item_value(iPlayer, g_iRegenItemId) <= 0)
		return

	if (!kc_player_item_get_enabled(iPlayer, g_iRegenItemId))
		return

	kc_player_item_set_enabled(iPlayer, g_iRegenItemId, false)
	g_bRegenSuppressed[iPlayer] = true

	client_print(iPlayer, print_center, "%L", iPlayer, "DAGGER_REGENERATION_BLOCKED")
}

restore_regen(iPlayer)
{
	if (!g_bRegenSuppressed[iPlayer])
		return

	g_bRegenSuppressed[iPlayer] = false

	if (g_iRegenItemId < 0 || !is_user_connected(iPlayer))
		return

	if (kc_player_get_item_value(iPlayer, g_iRegenItemId) > 0 && !kc_player_item_get_enabled(iPlayer, g_iRegenItemId))
		kc_player_item_set_enabled(iPlayer, g_iRegenItemId, true)
}

/* ---------------------------------------------------------------------------------- */
/* Misc                                                                                */
/* ---------------------------------------------------------------------------------- */

reset_life(iPlayer)
{
	sb_end(iPlayer)

	g_fBtDamage[iPlayer] = 0.0
	g_iBtStage[iPlayer] = 0
	g_fLeechPool[iPlayer] = 0.0
	g_fLeechStart[iPlayer] = 0.0
	g_fLeechEnd[iPlayer] = 0.0
	g_iMarkMask[iPlayer] = 0
	g_fAppliedSpeed[iPlayer] = SPEED
	g_iAttackType[iPlayer] = ATTACK_NONE
}

expand_box(Float:vMins[3], Float:vMaxs[3], Float:fValue)
{
	for (new i; i < 3; i++)
	{
		vMins[i] -= fValue
		vMaxs[i] += fValue
	}
}
