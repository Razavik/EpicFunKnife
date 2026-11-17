#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>
#include <efk_core>
#include <efk_utils>

new const PLUGIN[] = "EFK: Fire Knife"
#define KNIFE_CLASSNAME "weapon_next21_fire_r02"
#define SPEED 275.0
#define COVER_SPEED 250.0
#define COVER_DURATION 5.0
#define COVER_RAISE 0.25
#define COVER_REGEN_DELAY 1.5
#define COVER_LOCK 15.0
#define COVER_RADIUS 200.0
#define OVERHEAT_CD 17.0
#define WAVE_CD 18.0
#define FEAST_CD 20.0
#define RUSH_CD 17.0
#define ZONE_CD 20.0
#define WAVE_SPEED 800.0
#define WAVE_RANGE 400.0
#define WAVE_WIDTH 100.0
#define WAVE_HEIGHT 32.0
#define RUSH_SPEED 750.0
#define RUSH_TIME 0.4
#define TRAIL_TIME 5.0
#define ZONE_TIME 6.0
#define ZONE_RADIUS 200.0
#define FEAST_RADIUS 250.0
#define CLASSNAME_EFFECT "next21_fire_effect"
#define CLASSNAME_SHIELD "next21_fire_shield"
#define EFFECT_WAVE 1
#define EFFECT_TRAIL 2
#define Player[%1][%2] g_ePlayerData[%1 - 1][%2]

new const MODEL_V_KNIFE[] = "models/next21_efk/v_fire_knife_b03.mdl"
new const MODEL_P_KNIFE[] = "models/next21_efk/p_fire_knife.mdl"
new const MODEL_V_SHIELD[] = "models/shield/v_shield_knife.mdl"
new const MODEL_P_SHIELD[] = "models/shield/p_shield_knife.mdl"
new const MODEL_SHIELD[] = "models/w_shield.mdl"
new const SOUND_FIRE[] = "next21_efk/fire_activation.wav"
new const SOUND_HIT[] = "next21_efk/fire_laser_hit.wav"
new const OVERHEAT_NAMES[][] = { "Heat", "Burn", "Heal" }

enum _:PlayerData
{
	Knife,
	bool:ShieldMode,
	OverheatMode,
	bool:OverheatEnabled,
	Float:OverheatReady,
	Float:WaveReady,
	Float:FeastReady,
	Float:RushReady,
	Float:ZoneReady,
	Float:NextSwitch,
	Float:CoverCharge,
	Float:CoverRaised,
	Float:CoverRegen,
	Float:CoverLocked,
	Float:ShieldLocked,
	Float:CoverBaseSpeed,
	Zone,
	Float:RushUntil,
	Float:RushLast,
	Float:RushDirection[3],
	Float:RushTrailNext,
	bool:RushFull,
	RushMoveType,
	RushHits,
	bool:InMelee,
	Float:MeleeDefaults[5],
	Float:TickTime,
	Float:NextVisual
}

new g_iKnifeId, g_ePlayerData[MAX_PLAYERS][PlayerData]
new Float:g_fHeat[MAX_PLAYERS + 1], Float:g_fLastHeat[MAX_PLAYERS + 1]
new Float:g_fBurnRemainder[MAX_PLAYERS + 1]
new Float:g_fMeleeHeat[MAX_PLAYERS + 1], Float:g_fMeleeHealth[MAX_PLAYERS + 1]
new g_iMeleeTarget[MAX_PLAYERS + 1]
new Float:g_fTrailApplied[MAX_PLAYERS + 1][MAX_PLAYERS + 1]
new g_pKnifeModel, g_pFlameSpr, g_pRingSpr
new g_pKnifeVStr, g_pKnifePStr, g_pShieldVStr, g_pShieldPStr

public plugin_precache()
{
	g_pKnifeVStr = engfunc(EngFunc_AllocString, MODEL_V_KNIFE)
	g_pKnifePStr = engfunc(EngFunc_AllocString, MODEL_P_KNIFE)
	g_pShieldVStr = engfunc(EngFunc_AllocString, MODEL_V_SHIELD)
	g_pShieldPStr = engfunc(EngFunc_AllocString, MODEL_P_SHIELD)
	precache_model(MODEL_V_KNIFE)
	g_pKnifeModel = precache_model(MODEL_P_KNIFE)
	precache_model(MODEL_V_SHIELD)
	precache_model(MODEL_P_SHIELD)
	precache_model(MODEL_SHIELD)
	g_pFlameSpr = precache_model("sprites/next21_efk/fire_eff.spr")
	g_pRingSpr = precache_model("sprites/shockwave.spr")
	precache_sound(SOUND_FIRE)
	precache_sound(SOUND_HIT)
	precache_generic(fmt("sprites/%s.txt", KNIFE_CLASSNAME))
}

public plugin_init()
{
	register_plugin(PLUGIN, EFK_VERSION, "Next21 Team")
	g_iKnifeId = kc_register_knife(KNIFE_CLASSNAME, "KNIFE_FIRE_DESC", "KNIFE_FIRE_CHAT",
		g_pKnifeVStr, g_pKnifePStr, g_pKnifeModel, 100.0, 1.0, SPEED, 0.0, 0.0)
	if (g_iKnifeId < 0)
		set_fail_state("Fire Knife registration failed")

	// Core slots route controls; timestamps below own the independent cooldowns.
	kc_register_ability1(g_iKnifeId, "Inferno Wave / Cover", 1000.0)
	kc_register_ability2(g_iKnifeId, "Overheat Mode / Burner Rush", 1000.0)
	kc_register_ability3(g_iKnifeId, "Ember Feast / Inferno Zone", 1000.0)
	kc_register_ability4(g_iKnifeId, "Blade / Shield", 1000.0)
	kc_knife_set_flags(g_iKnifeId, KNFF_ABIL1_TOGGLEABLE)
	kc_knife_set_anim_ext(g_iKnifeId, ANIM_EXT_KNIFE2)
	kc_knife_set_level(g_iKnifeId, 1)

	RegisterHam(Ham_Spawn, "player", "fw_Spawn_Post", true)
	RegisterHam(Ham_Killed, "player", "fw_Killed")
	RegisterHam(Ham_Player_PreThink, "player", "fw_PreThink_Post", true)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_Melee")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_Primary_Post", true)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_Melee")
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_Secondary_Post", true)
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Deploy_Post", true)
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_knife", "fw_Idle")
	RegisterHam(Ham_TakeDamage, "player", "fw_Damage_Post", true)
	RegisterHam(Ham_TakeDamage, "env_explosion", "fw_Shield_Damage")
	RegisterHam(Ham_Touch, "grenade", "fw_Grenade_Touch")
	register_forward(FM_CmdStart, "fw_CmdStart")
	RegisterHookChain(RG_CSGameRules_CleanUpMap, "fw_CleanUp_Post", true)
}

public client_putinserver(iPlayer)
{
	arrayset(g_ePlayerData[iPlayer - 1], 0, PlayerData)
	Player[iPlayer][Knife] = -1
	g_fHeat[iPlayer] = 0.0
	g_fBurnRemainder[iPlayer] = 0.0
}

public client_disconnected(iPlayer)
{
	clear_player(iPlayer)
	Player[iPlayer][Knife] = -1
}

public fw_Spawn_Post(iPlayer)
{
	if (!is_user_alive(iPlayer))
		return
	clear_player(iPlayer)
	Player[iPlayer][ShieldMode] = false
	Player[iPlayer][OverheatMode] = 0
	Player[iPlayer][OverheatEnabled] = true
	Player[iPlayer][CoverCharge] = COVER_DURATION
	Player[iPlayer][CoverLocked] = 0.0
	Player[iPlayer][ShieldLocked] = 0.0
	new Float:fNow = get_gametime()
	Player[iPlayer][OverheatReady] = fNow
	Player[iPlayer][WaveReady] = fNow + RESET_ABIL_AFTER_SPAWN
	Player[iPlayer][FeastReady] = fNow
	Player[iPlayer][RushReady] = fNow + RESET_ABIL_AFTER_SPAWN
	Player[iPlayer][ZoneReady] = fNow
	Player[iPlayer][TickTime] = fNow
}

public fw_Killed(iPlayer)
{
	clear_player(iPlayer)
}

public fw_CleanUp_Post()
{
	for (new i = 1; i <= MaxClients; i++)
		clear_player(i)
	new iEnt
	while ((iEnt = rg_find_ent_by_class(0, CLASSNAME_EFFECT)))
		rg_remove_entity(iEnt)
	while ((iEnt = rg_find_ent_by_class(0, CLASSNAME_SHIELD)))
		rg_remove_entity(iEnt)
}

clear_player(iPlayer)
{
	end_cover(iPlayer)
	stop_rush(iPlayer)
	remove_zone(iPlayer, false)
	remove_owned_effects(iPlayer)
	Player[iPlayer][InMelee] = false
	g_fHeat[iPlayer] = 0.0
	g_fLastHeat[iPlayer] = 0.0
	g_fBurnRemainder[iPlayer] = 0.0
}

public efk_player_change_team(iPlayer, iTeam)
{
	clear_player(iPlayer)
}

public efk_change_knife_core_post(iPlayer, iKnifeId)
{
	if (Player[iPlayer][Knife] == g_iKnifeId && iKnifeId != g_iKnifeId)
	{
		end_cover(iPlayer)
		stop_rush(iPlayer)
		remove_zone(iPlayer, false)
		remove_owned_effects(iPlayer)
	}
	Player[iPlayer][Knife] = iKnifeId
	if (iKnifeId == g_iKnifeId)
	{
		Player[iPlayer][TickTime] = get_gametime()
		update_models(iPlayer)
	}
}

public fw_PreThink_Post(iPlayer)
{
	if (!is_user_alive(iPlayer))
		return HAM_IGNORED

	new Float:fNow = get_gametime()
	new Float:fLast = Player[iPlayer][TickTime]
	new Float:fDelta = floatclamp(fNow - fLast, 0.0, 0.1)
	Player[iPlayer][TickTime] = fNow
	if (get_entvar(iPlayer, var_waterlevel) > 0)
	{
		g_fHeat[iPlayer] = 0.0
		g_fBurnRemainder[iPlayer] = 0.0
		if (kc_player_in_burn(iPlayer))
			kc_player_unburn(iPlayer)
	}
	else if (g_fHeat[iPlayer] > 0.0 && fNow > g_fLastHeat[iPlayer] + 3.0)
	{
		new Float:fDecayTime = floatmin(fDelta, fNow - g_fLastHeat[iPlayer] - 3.0)
		g_fHeat[iPlayer] = floatmax(0.0, g_fHeat[iPlayer] - 10.0 * fDecayTime)
	}

	if (Player[iPlayer][Knife] != g_iKnifeId)
		return HAM_IGNORED
	if (Player[iPlayer][RushUntil] > 0.0)
		update_rush(iPlayer, fNow)

	if (Player[iPlayer][CoverLocked] > 0.0 && fNow >= Player[iPlayer][CoverLocked])
	{
		Player[iPlayer][CoverLocked] = 0.0
		Player[iPlayer][CoverCharge] = COVER_DURATION
	}
	if (Player[iPlayer][CoverRaised] > 0.0)
	{
		if (!(get_entvar(iPlayer, var_button) & IN_ATTACK2) || !can_act(iPlayer)
			|| get_user_weapon(iPlayer) != CSW_KNIFE || !Player[iPlayer][ShieldMode])
			end_cover(iPlayer)
		else if (fNow >= Player[iPlayer][CoverRaised])
		{
			new Float:fActiveDelta = floatmin(Player[iPlayer][CoverCharge], floatmin(fDelta, fNow - Player[iPlayer][CoverRaised]))
			cover_heat(iPlayer, 20.0 * fActiveDelta)
			Player[iPlayer][CoverCharge] = floatmax(0.0, Player[iPlayer][CoverCharge] - fActiveDelta)
			if (Player[iPlayer][CoverCharge] <= 0.0)
			{
				end_cover(iPlayer)
				Player[iPlayer][CoverLocked] = fNow + COVER_LOCK
			}
		}
	}
	else if (Player[iPlayer][CoverLocked] == 0.0 && Player[iPlayer][RushUntil] == 0.0
		&& !Player[iPlayer][Zone] && fNow >= Player[iPlayer][CoverRegen])
	{
		Player[iPlayer][CoverCharge] = floatmin(COVER_DURATION,
			Player[iPlayer][CoverCharge] + floatmin(fDelta, fNow - Player[iPlayer][CoverRegen]) / 3.0)
	}
	if (Player[iPlayer][CoverRaised] > 0.0 && Player[iPlayer][NextVisual] <= fNow)
	{
		Player[iPlayer][NextVisual] = fNow + 0.2
		new Float:vOrigin[3], Float:vForward[3]
		get_entvar(iPlayer, var_origin, vOrigin)
		forward_flat(iPlayer, vForward)
		for (new i = 0; i < 3; i++)
		{
			new Float:vPoint[3]
			xs_vec_mul_scalar(vForward, 35.0 + 60.0 * i, vPoint)
			xs_vec_add(vOrigin, vPoint, vPoint)
			vPoint[2] -= 15.0
			flame(vPoint, 3)
		}
	}
	return HAM_IGNORED
}

bool:can_act(iPlayer)
{
	return is_user_alive(iPlayer) && !kc_player_in_silence(iPlayer)
		&& kc_player_get_capture(iPlayer) == CAPTURE_NONE && !kc_player_in_freeze(iPlayer)
		&& !kc_player_check_game_flag(iPlayer, PLGF_IN_UNABILITY)
		&& kc_player_can_ability(iPlayer, 0)
}

public efk_ability_toggle(iPlayer)
{
	if (Player[iPlayer][Knife] != g_iKnifeId)
		return PLUGIN_CONTINUE
	Player[iPlayer][OverheatEnabled] = !Player[iPlayer][OverheatEnabled]
	return PLUGIN_HANDLED
}

public efk_ability(iPlayer)
{
	if (!can_act(iPlayer) || Player[iPlayer][RushUntil] > 0.0)
		return PLUGIN_HANDLED
	if (Player[iPlayer][ShieldMode])
		begin_cover(iPlayer)
	else if (Player[iPlayer][WaveReady] <= get_gametime() && create_wave(iPlayer))
		Player[iPlayer][WaveReady] = get_gametime() + WAVE_CD
	return PLUGIN_HANDLED
}

public efk_ability2(iPlayer)
{
	new Float:fNow = get_gametime()
	if (!can_act(iPlayer) || Player[iPlayer][RushUntil] > 0.0 || Player[iPlayer][NextSwitch] > fNow)
		return PLUGIN_HANDLED
	if (!Player[iPlayer][ShieldMode])
	{
		Player[iPlayer][OverheatMode] = (Player[iPlayer][OverheatMode] + 1) % 3
		Player[iPlayer][NextSwitch] = fNow + 0.25
	}
	else if (Player[iPlayer][RushReady] <= fNow && !Player[iPlayer][Zone]
		&& Player[iPlayer][ShieldLocked] <= fNow)
		begin_rush(iPlayer)
	return PLUGIN_HANDLED
}

public efk_ability3(iPlayer)
{
	if (!can_act(iPlayer) || Player[iPlayer][RushUntil] > 0.0)
		return PLUGIN_HANDLED
	new Float:fNow = get_gametime()
	if (Player[iPlayer][ShieldMode])
	{
		if (Player[iPlayer][ZoneReady] <= fNow && !Player[iPlayer][Zone]
			&& Player[iPlayer][ShieldLocked] <= fNow && Player[iPlayer][CoverCharge] >= 1.0
			&& Player[iPlayer][CoverLocked] <= fNow)
			create_zone(iPlayer)
	}
	else if (Player[iPlayer][FeastReady] <= fNow)
	{
		ember_feast(iPlayer)
		Player[iPlayer][FeastReady] = fNow + FEAST_CD
	}
	return PLUGIN_HANDLED
}

public efk_ability4(iPlayer)
{
	new Float:fNow = get_gametime()
	if (!can_act(iPlayer) || Player[iPlayer][RushUntil] > 0.0 || Player[iPlayer][NextSwitch] > fNow)
		return PLUGIN_HANDLED
	if (!Player[iPlayer][ShieldMode] && (Player[iPlayer][Zone] || Player[iPlayer][ShieldLocked] > fNow))
		return PLUGIN_HANDLED
	end_cover(iPlayer)
	Player[iPlayer][ShieldMode] = !Player[iPlayer][ShieldMode]
	Player[iPlayer][NextSwitch] = fNow + 0.25
	update_models(iPlayer)
	return PLUGIN_HANDLED
}

public efk_targeted_ability_block_pre(iPlayer, iTarget)
{
	if (is_entity_player(iTarget) && is_user_alive(iTarget) && iTarget != iPlayer
		&& get_member(iPlayer, m_iTeam) != get_member(iTarget, m_iTeam))
	{
		new Float:vOrigin[3]
		get_entvar(iPlayer, var_origin, vOrigin)
		if (cover_blocks(iTarget, vOrigin))
			return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public fw_Melee(iWeapon)
{
	new iPlayer = get_member(iWeapon, m_pPlayer)
	if (Player[iPlayer][Knife] != g_iKnifeId)
		return HAM_IGNORED
	if (Player[iPlayer][RushUntil] > 0.0 || Player[iPlayer][ShieldMode])
		return HAM_SUPERCEDE
	Player[iPlayer][MeleeDefaults][0] = get_member(iWeapon, m_Knife_flSwingBaseDamage)
	Player[iPlayer][MeleeDefaults][1] = get_member(iWeapon, m_Knife_flSwingBaseDamage_Fast)
	Player[iPlayer][MeleeDefaults][2] = get_member(iWeapon, m_Knife_flStabBaseDamage)
	Player[iPlayer][MeleeDefaults][3] = get_member(iWeapon, m_Knife_flSwingDistance)
	Player[iPlayer][MeleeDefaults][4] = get_member(iWeapon, m_Knife_flStabDistance)
	Player[iPlayer][InMelee] = true
	g_iMeleeTarget[iPlayer] = 0
	set_member(iWeapon, m_Knife_flSwingBaseDamage, 15.0)
	set_member(iWeapon, m_Knife_flSwingBaseDamage_Fast, 15.0)
	set_member(iWeapon, m_Knife_flStabBaseDamage, 65.0)
	set_member(iWeapon, m_Knife_flSwingDistance, 48.0)
	set_member(iWeapon, m_Knife_flStabDistance, 32.0)
	return HAM_IGNORED
}

public fw_Primary_Post(iWeapon)
{
	finish_melee(iWeapon, 0.45)
}

public fw_Secondary_Post(iWeapon)
{
	finish_melee(iWeapon, 1.0)
}

finish_melee(iWeapon, Float:fInterval)
{
	new iPlayer = get_member(iWeapon, m_pPlayer)
	if (Player[iPlayer][Knife] != g_iKnifeId || !Player[iPlayer][InMelee])
		return
	set_member(iWeapon, m_Knife_flSwingBaseDamage, Player[iPlayer][MeleeDefaults][0])
	set_member(iWeapon, m_Knife_flSwingBaseDamage_Fast, Player[iPlayer][MeleeDefaults][1])
	set_member(iWeapon, m_Knife_flStabBaseDamage, Player[iPlayer][MeleeDefaults][2])
	set_member(iWeapon, m_Knife_flSwingDistance, Player[iPlayer][MeleeDefaults][3])
	set_member(iWeapon, m_Knife_flStabDistance, Player[iPlayer][MeleeDefaults][4])
	Player[iPlayer][InMelee] = false
	if (GetHamReturnStatus() == HAM_SUPERCEDE)
		return
	set_member(iWeapon, m_Weapon_flNextPrimaryAttack, fInterval)
	set_member(iWeapon, m_Weapon_flNextSecondaryAttack, fInterval)
}

public efk_apply_damage(iVictim, iAttacker, &Float:fDamage, &Float:fPower, &Float:fAdd)
{
	if (Player[iAttacker][Knife] == g_iKnifeId && Player[iAttacker][InMelee])
	{
		g_iMeleeTarget[iAttacker] = iVictim
		g_fMeleeHeat[iAttacker] = g_fHeat[iVictim]
		g_fMeleeHealth[iAttacker] = get_entvar(iVictim, var_health)
	}
}

public fw_Damage_Post(iVictim, iInflictor, iAttacker, Float:fDamage, iBits)
{
	if (GetHamReturnStatus() == HAM_SUPERCEDE || fDamage <= 0.0 || !(iBits & DMG_BULLET)
		|| iInflictor != iAttacker || !is_entity_player(iAttacker) || !is_user_alive(iAttacker)
		|| Player[iAttacker][Knife] != g_iKnifeId || !Player[iAttacker][InMelee]
		|| !Player[iAttacker][OverheatEnabled] || Player[iAttacker][OverheatReady] > get_gametime()
		|| !can_act(iAttacker) || g_iMeleeTarget[iAttacker] != iVictim
		|| get_member(iAttacker, m_iTeam) == get_member(iVictim, m_iTeam)
		|| Float:get_entvar(iVictim, var_health) >= g_fMeleeHealth[iAttacker])
		return HAM_IGNORED

	new Float:fHeat = g_fMeleeHeat[iAttacker]
	g_iMeleeTarget[iAttacker] = 0
	Player[iAttacker][OverheatReady] = get_gametime() + OVERHEAT_CD
	if (Player[iAttacker][OverheatMode] != 0)
		take_heat(iVictim)
	switch (Player[iAttacker][OverheatMode])
	{
		case 0: add_heat(iVictim, iAttacker, 50.0)
		case 1:
		{
			if (is_user_alive(iVictim))
			{
				new Float:fBurnDamage = float(floatround(11.0 + 0.225 * fHeat))
				kc_player_set_death_reason(iVictim, "DEATH_REASON_BURNED")
				set_member(iVictim, m_LastHitGroup, HIT_GENERIC)
				ExecuteHamB(Ham_TakeDamage, iVictim, iAttacker, iAttacker, fBurnDamage, DMG_BURN)
			}
		}
		case 2: kc_player_heal(iAttacker, float(floatround(17.0 + fHeat / 3.0)), iAttacker)
	}
	return HAM_IGNORED
}

bool:enemy(iOwner, iTarget)
{
	return is_user_alive(iOwner) && is_user_alive(iTarget) && iOwner != iTarget
		&& get_member(iOwner, m_iTeam) != get_member(iTarget, m_iTeam)
		&& (!kc_player_check_game_flag(iTarget, PLGF_IN_UNABILITY)
			|| kc_player_get_visibility(iTarget) == VIS_CLONE)
}

add_heat(iTarget, iOwner, Float:fAmount)
{
	if (fAmount <= 0.0 || !enemy(iOwner, iTarget) || get_entvar(iTarget, var_waterlevel) > 0)
		return
	new bool:bBurning = kc_player_in_burn(iTarget) > 0
	new Float:fAccepted = floatmin(fAmount, 100.0 - g_fHeat[iTarget])
	g_fLastHeat[iTarget] = get_gametime()
	g_fHeat[iTarget] = floatmin(100.0, g_fHeat[iTarget] + fAmount)
	if (bBurning)
		extend_ignition(iTarget, iOwner, fAccepted)
	if (g_fHeat[iTarget] >= 99.9999)
	{
		g_fHeat[iTarget] = 0.0
		if (!bBurning)
			extend_ignition(iTarget, iOwner, 100.0)
	}
}

extend_ignition(iTarget, iOwner, Float:fHeat)
{
	g_fBurnRemainder[iTarget] += 0.06 * fHeat
	new iCycles = floatround((g_fBurnRemainder[iTarget] + 0.00001) / 0.2, floatround_floor)
	if (iCycles < 1)
		return
	g_fBurnRemainder[iTarget] -= float(iCycles) * 0.2
	kc_player_ignite(iTarget, iOwner, float(iCycles) * 0.2, 10.0)
}

public efk_unburn(iPlayer)
{
	g_fBurnRemainder[iPlayer] = 0.0
}

Float:take_heat(iTarget)
{
	new Float:fHeat = g_fHeat[iTarget]
	g_fHeat[iTarget] = 0.0
	return fHeat
}

ember_feast(iPlayer)
{
	new Float:vOrigin[3], Float:vTarget[3], Float:fTotal
	get_entvar(iPlayer, var_origin, vOrigin)
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!enemy(iPlayer, i))
			continue
		get_entvar(i, var_origin, vTarget)
		if (get_distance_f(vOrigin, vTarget) <= FEAST_RADIUS && !is_wall_between(vOrigin, vTarget, iPlayer))
			fTotal += take_heat(i)
	}
	kc_player_heal(iPlayer, floatmin(150.0, fTotal) / 3.0, iPlayer)
	fire_ring(vOrigin, FEAST_RADIUS)
	emit_sound(iPlayer, CHAN_ITEM, SOUND_FIRE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

begin_cover(iPlayer)
{
	new Float:fNow = get_gametime()
	if (Player[iPlayer][CoverRaised] > 0.0 || Player[iPlayer][CoverCharge] <= 0.0
		|| Player[iPlayer][CoverLocked] > fNow || Player[iPlayer][ShieldLocked] > fNow
		|| Player[iPlayer][Zone])
		return
	Player[iPlayer][CoverRaised] = fNow + COVER_RAISE
	Player[iPlayer][CoverBaseSpeed] = kc_player_get_def_maxspeed(iPlayer)
	kc_player_set_def_maxspeed(iPlayer, COVER_SPEED)
	kc_player_set_view_anim(iPlayer, 5)
}

end_cover(iPlayer)
{
	if (Player[iPlayer][CoverRaised] == 0.0)
		return
	Player[iPlayer][CoverRaised] = 0.0
	Player[iPlayer][CoverRegen] = get_gametime() + COVER_REGEN_DELAY
	if (is_user_connected(iPlayer) && Player[iPlayer][Knife] == g_iKnifeId && kc_player_get_knife(iPlayer) == g_iKnifeId)
	{
		kc_player_set_def_maxspeed(iPlayer, Player[iPlayer][CoverBaseSpeed])
		if (is_user_alive(iPlayer) && get_user_weapon(iPlayer) == CSW_KNIFE)
			kc_player_set_view_anim(iPlayer, 6)
	}
}

bool:cover_blocks(iPlayer, const Float:vSource[3])
{
	if (!is_user_alive(iPlayer) || Player[iPlayer][Knife] != g_iKnifeId
		|| !Player[iPlayer][ShieldMode] || Player[iPlayer][CoverRaised] <= 0.0
		|| get_gametime() < Player[iPlayer][CoverRaised] || Player[iPlayer][CoverCharge] <= 0.0
		|| get_user_weapon(iPlayer) != CSW_KNIFE || !can_act(iPlayer))
		return false
	new Float:vOrigin[3], Float:vDirection[3], Float:vForward[3]
	get_entvar(iPlayer, var_origin, vOrigin)
	xs_vec_sub(vSource, vOrigin, vDirection)
	vDirection[2] = 0.0
	if (xs_vec_len(vDirection) < 0.01)
		return false
	xs_vec_normalize(vDirection, vDirection)
	forward_flat(iPlayer, vForward)
	return xs_vec_dot(vForward, vDirection) >= 0.7071067
}

cover_heat(iPlayer, Float:fHeat)
{
	new Float:vOrigin[3], Float:vTarget[3], Float:vForward[3], Float:vDirection[3]
	get_entvar(iPlayer, var_origin, vOrigin)
	forward_flat(iPlayer, vForward)
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!enemy(iPlayer, i))
			continue
		get_entvar(i, var_origin, vTarget)
		if (get_distance_f(vOrigin, vTarget) > COVER_RADIUS || is_wall_between(vOrigin, vTarget, iPlayer))
			continue
		xs_vec_sub(vTarget, vOrigin, vDirection)
		vDirection[2] = 0.0
		xs_vec_normalize(vDirection, vDirection)
		if (xs_vec_dot(vForward, vDirection) >= 0.7071067)
			add_heat(i, iPlayer, fHeat)
	}
}

public efk_damage_block_pre(iVictim, iInflictor, iAttacker, Float:fDamage, iBits)
{
	if (!is_entity_player(iAttacker) || iAttacker == iVictim
		|| get_member(iAttacker, m_iTeam) == get_member(iVictim, m_iTeam)
		|| (iBits & (DMG_FALL | DMG_DROWN | DMG_BURN | DMG_POISON))
		|| (iInflictor == iAttacker && (iBits & (DMG_BULLET | DMG_SLASH))))
		return PLUGIN_CONTINUE
	if (iInflictor > MaxClients && !is_nullent(iInflictor)
		&& get_entvar(iInflictor, var_impulse) == IMPULSE_ZOMBIE)
		return PLUGIN_CONTINUE
	new Float:vOrigin[3]
	if (iInflictor > 0 && !is_nullent(iInflictor))
		get_entvar(iInflictor, var_origin, vOrigin)
	else
		get_entvar(iAttacker, var_origin, vOrigin)
	return cover_blocks(iVictim, vOrigin) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public efk_projectile_block_pre(iPlayer, iProjectile)
{
	new iOwner = get_entvar(iProjectile, var_owner)
	if (get_entvar(iProjectile, var_impulse) == IMPULSE_WIND_WAVE)
		iOwner = get_entvar(iProjectile, var_iuser1)
	if (is_entity_player(iOwner) && (iOwner == iPlayer
		|| get_member(iOwner, m_iTeam) == get_member(iPlayer, m_iTeam)))
		return PLUGIN_CONTINUE
	new Float:vOrigin[3]
	get_entvar(iProjectile, var_origin, vOrigin)
	if (!cover_blocks(iPlayer, vOrigin))
		return PLUGIN_CONTINUE
	send_msg_TE_SPARKS(vOrigin)
	send_msg_TE_KILLBEAM(iProjectile, MSG_ALL)
	return PLUGIN_HANDLED
}

public fw_Grenade_Touch(iEnt, iOther)
{
	if (kc_player_blocks_projectile(iOther, iEnt))
	{
		send_msg_TE_KILLBEAM(iEnt, MSG_ALL)
		rg_remove_entity(iEnt)
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public fw_Deploy_Post(iWeapon)
{
	if (GetHamReturnStatus() == HAM_SUPERCEDE)
		return
	new iPlayer = get_member(iWeapon, m_pPlayer)
	if (Player[iPlayer][Knife] == g_iKnifeId)
		update_models(iPlayer)
}

public fw_Idle(iWeapon)
{
	new iPlayer = get_member(iWeapon, m_pPlayer)
	if (Player[iPlayer][Knife] != g_iKnifeId || !Player[iPlayer][ShieldMode])
		return HAM_IGNORED
	if (Float:get_member(iWeapon, m_Weapon_flTimeWeaponIdle) <= 0.0)
	{
		kc_player_set_view_anim(iPlayer, Player[iPlayer][CoverRaised] > 0.0 ? 4 : 0)
		set_member(iWeapon, m_Weapon_flTimeWeaponIdle, 10.0)
	}
	return HAM_SUPERCEDE
}

update_models(iPlayer)
{
	if (!is_user_alive(iPlayer) || get_user_weapon(iPlayer) != CSW_KNIFE)
		return
	set_pev(iPlayer, pev_viewmodel, Player[iPlayer][ShieldMode] ? g_pShieldVStr : g_pKnifeVStr)
	set_pev(iPlayer, pev_weaponmodel, Player[iPlayer][ShieldMode] ? g_pShieldPStr : g_pKnifePStr)
	kc_player_set_view_anim(iPlayer, 0)
}

begin_rush(iPlayer)
{
	end_cover(iPlayer)
	new Float:fNow = get_gametime()
	Player[iPlayer][RushFull] = Player[iPlayer][CoverCharge] >= 1.0 && Player[iPlayer][CoverLocked] <= fNow
	if (Player[iPlayer][RushFull])
		spend_cover(iPlayer)
	Player[iPlayer][RushReady] = fNow + RUSH_CD
	Player[iPlayer][RushUntil] = fNow + RUSH_TIME
	Player[iPlayer][RushLast] = fNow
	Player[iPlayer][RushTrailNext] = 0.0
	Player[iPlayer][RushHits] = 0
	forward_flat(iPlayer, Player[iPlayer][RushDirection])
	Player[iPlayer][RushMoveType] = get_entvar(iPlayer, var_movetype)
	set_entvar(iPlayer, var_movetype, MOVETYPE_NOCLIP)
	set_entvar(iPlayer, var_velocity, NULL_VECTOR)
	kc_player_set_game_flag(iPlayer, PLGF_IN_BURNRUSH)
	emit_sound(iPlayer, CHAN_BODY, SOUND_FIRE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public fw_CmdStart(iPlayer, iUC)
{
	if (!is_user_alive(iPlayer) || Player[iPlayer][RushUntil] <= 0.0)
		return FMRES_IGNORED
	set_uc(iUC, UC_ForwardMove, 0.0)
	set_uc(iUC, UC_SideMove, 0.0)
	set_uc(iUC, UC_UpMove, 0.0)
	set_uc(iUC, UC_Buttons, get_uc(iUC, UC_Buttons) & ~(IN_ATTACK | IN_ATTACK2 | IN_JUMP | IN_DUCK))
	return FMRES_HANDLED
}

update_rush(iPlayer, Float:fNow)
{
	if (!can_act(iPlayer) || kc_player_in_chill(iPlayer))
	{
		stop_rush(iPlayer)
		return
	}
	new Float:fEnd = floatmin(fNow, Player[iPlayer][RushUntil])
	new Float:fDistance = RUSH_SPEED * floatmax(0.0, fEnd - Player[iPlayer][RushLast])
	Player[iPlayer][RushLast] = fEnd
	new Float:vStart[3], Float:vEnd[3]
	get_entvar(iPlayer, var_origin, vStart)
	xs_vec_mul_scalar(Player[iPlayer][RushDirection], fDistance, vEnd)
	xs_vec_add(vStart, vEnd, vEnd)
	new iHull = get_entvar(iPlayer, var_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
	engfunc(EngFunc_TraceHull, vStart, vEnd, IGNORE_MONSTERS, iHull, iPlayer, 0)
	new Float:fFraction
	get_tr2(0, TR_flFraction, fFraction)
	get_tr2(0, TR_vecEndPos, vEnd)
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
	{
		stop_rush(iPlayer)
		return
	}
	engfunc(EngFunc_SetOrigin, iPlayer, vEnd)
	set_entvar(iPlayer, var_velocity, NULL_VECTOR)
	rush_hits(iPlayer, vStart, vEnd)
	if (Player[iPlayer][RushFull] && Player[iPlayer][RushTrailNext] <= fNow)
	{
		Player[iPlayer][RushTrailNext] = fNow + 0.08
		create_trail(iPlayer, vEnd)
	}
	if (fFraction < 1.0)
	{
		rush_impact(iPlayer, vEnd)
		stop_rush(iPlayer)
	}
	else if (fNow >= Player[iPlayer][RushUntil])
		stop_rush(iPlayer)
}

rush_hits(iPlayer, Float:vStart[3], Float:vEnd[3])
{
	new Float:vMins[3], Float:vMaxs[3]
	for (new i = 1; i <= MaxClients; i++)
	{
		new iBit = 1 << (i - 1)
		if ((Player[iPlayer][RushHits] & iBit) || !enemy(iPlayer, i))
			continue
		get_entvar(i, var_absmin, vMins)
		get_entvar(i, var_absmax, vMaxs)
		for (new j = 0; j < 2; j++)
		{
			vMins[j] -= 16.0
			vMaxs[j] += 16.0
		}
		vMins[2] -= 36.0
		vMaxs[2] += 36.0
		if (!line_intersects_box(vStart, vEnd, vMins, vMaxs))
			continue
		Player[iPlayer][RushHits] |= iBit
		if (Player[iPlayer][RushFull])
			add_heat(i, iPlayer, 35.0)
		new Float:vPush[3]
		xs_vec_mul_scalar(Player[iPlayer][RushDirection], 400.0, vPush)
		vPush[2] = 160.0
		set_entvar(i, var_flags, get_entvar(i, var_flags) & ~FL_ONGROUND)
		set_entvar(i, var_velocity, vPush)
		kc_player_set_override_attacker(i, iPlayer, 4.0)
		kc_player_slow(i, 0.1, 0.5)
		send_msg_ScreenShake((1<<14), (1<<14), (1<<14), MSG_ONE, _, i)
	}
}

rush_impact(iPlayer, Float:vOrigin[3])
{
	fire_ring(vOrigin, 150.0)
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!enemy(iPlayer, i))
			continue
		new Float:vTarget[3]
		get_entvar(i, var_origin, vTarget)
		if (get_distance_f(vOrigin, vTarget) > 150.0 || is_wall_between(vOrigin, vTarget, iPlayer))
			continue
		kc_player_slow(i, 0.1, 0.5)
		send_msg_ScreenShake((1<<14), (1<<14), (1<<14), MSG_ONE, _, i)
	}
}

stop_rush(iPlayer)
{
	if (Player[iPlayer][RushUntil] <= 0.0)
		return
	Player[iPlayer][RushUntil] = 0.0
	if (is_user_connected(iPlayer))
	{
		set_entvar(iPlayer, var_movetype, Player[iPlayer][RushMoveType])
		set_entvar(iPlayer, var_velocity, NULL_VECTOR)
		kc_player_unset_game_flag(iPlayer, PLGF_IN_BURNRUSH)
	}
	Player[iPlayer][CoverRegen] = get_gametime() + COVER_REGEN_DELAY
}

public efk_disenergy(iPlayer)
{
	end_cover(iPlayer)
	stop_rush(iPlayer)
}

public efk_freeze(iPlayer)
{
	end_cover(iPlayer)
	stop_rush(iPlayer)
}

public efk_capture(iPlayer, CaptureType:iType)
{
	if (iType != CAPTURE_NONE)
	{
		end_cover(iPlayer)
		stop_rush(iPlayer)
	}
}

spend_cover(iPlayer)
{
	Player[iPlayer][CoverCharge] = floatmax(0.0, Player[iPlayer][CoverCharge] - 1.0)
	Player[iPlayer][CoverRegen] = get_gametime() + COVER_REGEN_DELAY
	if (Player[iPlayer][CoverCharge] <= 0.0)
		Player[iPlayer][CoverLocked] = get_gametime() + COVER_LOCK
}

bool:create_zone(iPlayer)
{
	new Float:vOrigin[3], Float:vForward[3], Float:vEnd[3]
	get_entvar(iPlayer, var_origin, vOrigin)
	forward_flat(iPlayer, vForward)
	xs_vec_mul_scalar(vForward, 45.0, vEnd)
	xs_vec_add(vOrigin, vEnd, vEnd)
	engfunc(EngFunc_TraceHull, vOrigin, vEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, iPlayer, 0)
	new Float:fFraction
	get_tr2(0, TR_flFraction, fFraction)
	if (fFraction < 1.0 || get_tr2(0, TR_StartSolid))
		return false
	if (!ground_point(vEnd, vEnd))
		return false
	vEnd[2] += 2.0
	new iEnt = rg_create_entity("env_explosion")
	if (is_nullent(iEnt))
		return false
	set_entvar(iEnt, var_classname, CLASSNAME_SHIELD)
	set_entvar(iEnt, var_impulse, IMPULSE_FIRE_SHIELD)
	set_entvar(iEnt, var_owner, iPlayer)
	set_entvar(iEnt, var_iuser4, get_user_userid(iPlayer))
	set_entvar(iEnt, var_skin, get_member(iPlayer, m_iTeam) - 1)
	set_entvar(iEnt, var_health, 90.0)
	set_entvar(iEnt, var_takedamage, DAMAGE_YES)
	set_entvar(iEnt, var_solid, SOLID_BBOX)
	set_entvar(iEnt, var_movetype, MOVETYPE_NONE)
	set_entvar(iEnt, var_fuser1, get_gametime() + ZONE_TIME)
	set_entvar(iEnt, var_fuser2, get_gametime())
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.05)
	engfunc(EngFunc_SetModel, iEnt, MODEL_SHIELD)
	engfunc(EngFunc_SetSize, iEnt, Float:{-12.0, -12.0, 0.0}, Float:{12.0, 12.0, 48.0})
	engfunc(EngFunc_SetOrigin, iEnt, vEnd)
	new Float:vAngles[3]
	get_entvar(iPlayer, var_v_angle, vAngles)
	vAngles[0] = vAngles[2] = 0.0
	set_entvar(iEnt, var_angles, vAngles)
	SetThink(iEnt, "zone_think")
	Player[iPlayer][Zone] = iEnt
	Player[iPlayer][ZoneReady] = get_gametime() + ZONE_CD
	end_cover(iPlayer)
	spend_cover(iPlayer)
	Player[iPlayer][ShieldMode] = false
	update_models(iPlayer)
	fire_ring(vEnd, ZONE_RADIUS)
	return true
}

public zone_think(iEnt)
{
	new iOwner = effect_owner(iEnt)
	if (!iOwner || Player[iOwner][Zone] != iEnt)
	{
		rg_remove_entity(iEnt)
		return
	}
	new Float:fNow = get_gametime(), Float:fExpire = get_entvar(iEnt, var_fuser1)
	new Float:fLast = get_entvar(iEnt, var_fuser2)
	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)
	heat_area(iOwner, iEnt, vOrigin, ZONE_RADIUS, 20.0 * floatmax(0.0, floatmin(fNow, fExpire) - fLast))
	if (fNow >= fExpire)
	{
		remove_zone(iOwner, false)
		return
	}
	if (Float:get_entvar(iEnt, var_fuser3) <= fNow)
	{
		set_entvar(iEnt, var_fuser3, fNow + 0.35)
		fire_ring(vOrigin, ZONE_RADIUS)
		flame(vOrigin, 6)
	}
	set_entvar(iEnt, var_fuser2, fNow)
	set_entvar(iEnt, var_nextthink, fNow + 0.05)
}

public fw_Shield_Damage(iEnt, iInflictor, iAttacker, Float:fDamage, iBits)
{
	if (get_entvar(iEnt, var_impulse) != IMPULSE_FIRE_SHIELD)
		return HAM_IGNORED
	new iOwner = effect_owner(iEnt)
	if (!iOwner || !is_entity_player(iAttacker)
		|| get_member(iAttacker, m_iTeam) == get_member(iOwner, m_iTeam) || fDamage <= 0.0)
		return HAM_SUPERCEDE
	new Float:fHealth = Float:get_entvar(iEnt, var_health) - fDamage
	if (fHealth <= 0.0)
		remove_zone(iOwner, true)
	else
		set_entvar(iEnt, var_health, fHealth)
	return HAM_SUPERCEDE
}

remove_zone(iPlayer, bool:bDestroyed)
{
	new iEnt = Player[iPlayer][Zone]
	Player[iPlayer][Zone] = 0
	if (!is_nullent(iEnt) && get_entvar(iEnt, var_impulse) == IMPULSE_FIRE_SHIELD
		&& get_entvar(iEnt, var_owner) == iPlayer)
	{
		if (bDestroyed)
		{
			new Float:vOrigin[3]
			get_entvar(iEnt, var_origin, vOrigin)
			send_msg_TE_SPARKS(vOrigin)
			Player[iPlayer][ShieldLocked] = get_gametime() + 10.0
		}
		set_entvar(iEnt, var_takedamage, DAMAGE_NO)
		set_entvar(iEnt, var_solid, SOLID_NOT)
		set_entvar(iEnt, var_flags, get_entvar(iEnt, var_flags) | FL_KILLME)
	}
	Player[iPlayer][CoverRegen] = get_gametime() + COVER_REGEN_DELAY
}

bool:create_wave(iPlayer)
{
	new Float:vOrigin[3]
	get_entvar(iPlayer, var_origin, vOrigin)
	if (!ground_point(vOrigin, vOrigin))
		return false
	new iEnt = create_effect(iPlayer, EFFECT_WAVE, vOrigin, WAVE_RANGE / WAVE_SPEED)
	if (!iEnt)
		return false
	new Float:vDirection[3]
	forward_flat(iPlayer, vDirection)
	set_entvar(iEnt, var_vuser1, vDirection)
	set_entvar(iEnt, var_fuser3, WAVE_RANGE)
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.02)
	SetThink(iEnt, "wave_think")
	return true
}

public wave_think(iEnt)
{
	new iOwner = effect_owner(iEnt)
	if (!iOwner)
	{
		rg_remove_entity(iEnt)
		return
	}
	new Float:fNow = get_gametime(), Float:fLast = get_entvar(iEnt, var_fuser2)
	new Float:fRemaining = get_entvar(iEnt, var_fuser3)
	new Float:fTravel = floatmin(fRemaining, WAVE_SPEED * (fNow - fLast))
	new Float:vStart[3], Float:vEnd[3], Float:vDirection[3]
	get_entvar(iEnt, var_origin, vStart)
	get_entvar(iEnt, var_vuser1, vDirection)
	while (fTravel > 0.001)
	{
		new Float:fStep = floatmin(16.0, fTravel)
		xs_vec_mul_scalar(vDirection, fStep, vEnd)
		xs_vec_add(vStart, vEnd, vEnd)
		if (!ground_point(vEnd, vEnd))
		{
			rg_remove_entity(iEnt)
			return
		}
		vStart[2] += 8.0
		vEnd[2] += 8.0
		engfunc(EngFunc_TraceLine, vStart, vEnd, IGNORE_MONSTERS, iEnt, 0)
		new Float:fFraction
		get_tr2(0, TR_flFraction, fFraction)
		vStart[2] -= 8.0
		vEnd[2] -= 8.0
		if (fFraction < 1.0)
		{
			rg_remove_entity(iEnt)
			return
		}
		wave_hits(iEnt, iOwner, vStart, vEnd, vDirection)
		if (is_nullent(iEnt))
			return
		xs_vec_copy(vEnd, vStart)
		fTravel -= fStep
		fRemaining -= fStep
	}
	engfunc(EngFunc_SetOrigin, iEnt, vStart)
	if (Float:get_entvar(iEnt, var_fuser4) <= fNow)
	{
		set_entvar(iEnt, var_fuser4, fNow + 0.05)
		for (new i = -2; i <= 2; i++)
		{
			new Float:vPoint[3]
			vPoint[0] = vStart[0] - vDirection[1] * i * 40.0 - vDirection[0] * floatabs(float(i)) * 8.0
			vPoint[1] = vStart[1] + vDirection[0] * i * 40.0 - vDirection[1] * floatabs(float(i)) * 8.0
			vPoint[2] = vStart[2] + 12.0
			flame(vPoint, 5)
		}
	}
	if (fRemaining <= 0.001)
	{
		rg_remove_entity(iEnt)
		return
	}
	set_entvar(iEnt, var_fuser3, fRemaining)
	set_entvar(iEnt, var_fuser2, fNow)
	set_entvar(iEnt, var_nextthink, fNow + 0.02)
}

wave_hits(iEnt, iOwner, Float:vStart[3], Float:vEnd[3], const Float:vDirection[3])
{
	new iHits = get_entvar(iEnt, var_iuser2)
	for (new i = 1; i <= MaxClients; i++)
	{
		new iBit = 1 << (i - 1)
		if ((iHits & iBit) || !enemy(iOwner, i))
			continue
		new Float:vTarget[3], Float:vMins[3], Float:vMaxs[3], Float:vDelta[3]
		get_entvar(i, var_origin, vTarget)
		get_entvar(i, var_absmin, vMins)
		get_entvar(i, var_absmax, vMaxs)
		xs_vec_sub(vTarget, vStart, vDelta)
		new Float:fAlong = xs_vec_dot(vDelta, vDirection)
		new Float:fAcross = floatabs(vDelta[0] * -vDirection[1] + vDelta[1] * vDirection[0])
		if (fAlong < -16.0 || fAlong > get_distance_f(vStart, vEnd) + 16.0
			|| fAcross > WAVE_WIDTH + 16.0 || vMins[2] > vEnd[2] + WAVE_HEIGHT
			|| vMaxs[2] < vEnd[2] || is_wall_between(vStart, vTarget, iEnt))
			continue
		if (kc_player_blocks_projectile(i, iEnt))
		{
			rg_remove_entity(iEnt)
			return
		}
		iHits |= iBit
		add_heat(i, iOwner, 40.0)
		kc_player_slow(i, 0.5, 0.3)
	}
	set_entvar(iEnt, var_iuser2, iHits)
}

create_trail(iPlayer, const Float:vOrigin[3])
{
	new Float:vFloor[3]
	if (!ground_point(vOrigin, vFloor))
		return
	new iEnt = create_effect(iPlayer, EFFECT_TRAIL, vFloor, TRAIL_TIME)
	if (iEnt)
	{
		SetThink(iEnt, "trail_think")
		flame(vFloor, 4)
	}
}

public trail_think(iEnt)
{
	new iOwner = effect_owner(iEnt)
	new Float:fNow = get_gametime(), Float:fExpire = get_entvar(iEnt, var_fuser1)
	if (!iOwner || fNow >= fExpire)
	{
		rg_remove_entity(iEnt)
		return
	}
	// Overlapping samples of one trail must not multiply its 20 Heat/sec.
	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)
	new Float:fLast = get_entvar(iEnt, var_fuser2)
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!enemy(iOwner, i))
			continue
		new Float:vTarget[3]
		get_entvar(i, var_origin, vTarget)
		vTarget[2] -= get_entvar(i, var_flags) & FL_DUCKING ? 18.0 : 36.0
		if (get_distance_f(vOrigin, vTarget) > 55.0 || is_wall_between(vOrigin, vTarget, iEnt))
			continue
		new Float:fApplied = g_fTrailApplied[iOwner][i]
		new Float:fDelta = floatmax(0.0, fNow - floatmax(fLast, fApplied))
		g_fTrailApplied[iOwner][i] = fNow
		add_heat(i, iOwner, 20.0 * fDelta)
	}
	if (Float:get_entvar(iEnt, var_fuser4) <= fNow)
	{
		set_entvar(iEnt, var_fuser4, fNow + 0.3)
		flame(vOrigin, 4)
	}
	set_entvar(iEnt, var_fuser2, fNow)
	set_entvar(iEnt, var_nextthink, fNow + 0.1)
}

create_effect(iPlayer, iType, const Float:vOrigin[3], Float:fLife)
{
	new iEnt = rg_create_entity("info_target")
	if (is_nullent(iEnt))
		return 0
	set_entvar(iEnt, var_classname, CLASSNAME_EFFECT)
	set_entvar(iEnt, var_impulse, IMPULSE_FIRE_EFFECT)
	set_entvar(iEnt, var_owner, iPlayer)
	set_entvar(iEnt, var_iuser4, get_user_userid(iPlayer))
	set_entvar(iEnt, var_iuser1, iType)
	set_entvar(iEnt, var_movetype, MOVETYPE_NONE)
	set_entvar(iEnt, var_solid, SOLID_NOT)
	set_entvar(iEnt, var_effects, EF_NODRAW)
	set_entvar(iEnt, var_fuser1, get_gametime() + fLife)
	set_entvar(iEnt, var_fuser2, get_gametime())
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.1)
	engfunc(EngFunc_SetOrigin, iEnt, vOrigin)
	return iEnt
}

effect_owner(iEnt)
{
	new iOwner = get_entvar(iEnt, var_owner)
	if (!is_user_alive(iOwner) || get_user_userid(iOwner) != get_entvar(iEnt, var_iuser4)
		|| Player[iOwner][Knife] != g_iKnifeId)
		return 0
	return iOwner
}

remove_owned_effects(iPlayer)
{
	new iEnt
	while ((iEnt = rg_find_ent_by_class(iEnt, CLASSNAME_EFFECT)))
		if (get_entvar(iEnt, var_owner) == iPlayer)
			rg_remove_entity(iEnt)
	arrayset(g_fTrailApplied[iPlayer], 0, MAX_PLAYERS + 1)
	for (new i = 1; i <= MaxClients; i++)
		g_fTrailApplied[i][iPlayer] = 0.0
}

heat_area(iOwner, iSource, const Float:vOrigin[3], Float:fRadius, Float:fHeat)
{
	new Float:vTarget[3], Float:vStart[3]
	xs_vec_copy(vOrigin, vStart)
	vStart[2] += 24.0
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!enemy(iOwner, i))
			continue
		get_entvar(i, var_origin, vTarget)
		if (get_distance_f(vOrigin, vTarget) <= fRadius && !is_wall_between(vStart, vTarget, iSource))
			add_heat(i, iOwner, fHeat)
	}
}

bool:ground_point(const Float:vOrigin[3], Float:vFloor[3])
{
	new Float:vStart[3], Float:vEnd[3], Float:vNormal[3], Float:fFraction
	xs_vec_copy(vOrigin, vStart)
	xs_vec_copy(vOrigin, vEnd)
	vStart[2] += 32.0
	vEnd[2] -= 72.0
	engfunc(EngFunc_TraceLine, vStart, vEnd, IGNORE_MONSTERS, 0, 0)
	get_tr2(0, TR_flFraction, fFraction)
	get_tr2(0, TR_vecPlaneNormal, vNormal)
	if (fFraction >= 1.0 || get_tr2(0, TR_StartSolid) || vNormal[2] < 0.5)
		return false
	get_tr2(0, TR_vecEndPos, vFloor)
	vFloor[2] += 1.0
	return true
}

forward_flat(iPlayer, Float:vForward[3])
{
	new Float:vAngles[3]
	get_entvar(iPlayer, var_v_angle, vAngles)
	vAngles[0] = vAngles[2] = 0.0
	angle_vector(vAngles, ANGLEVECTOR_FORWARD, vForward)
	xs_vec_normalize(vForward, vForward)
}

flame(const Float:vOrigin[3], iScale)
{
	send_msg_TE_SPRITE(vOrigin, g_pFlameSpr, iScale, 180, MSG_PVS, vOrigin)
}

fire_ring(const Float:vOrigin[3], Float:fRadius)
{
	new Float:vAxis[3]
	xs_vec_copy(vOrigin, vAxis)
	vAxis[2] += fRadius * 2.0
	send_msg_TE_BEAMCYLINDER(vOrigin, vAxis, g_pRingSpr, 0, 0, 3, 10, 0, {255, 90, 15}, 150, 0, MSG_PVS, vOrigin)
}

public efk_charge_draw_pre(iPlayer, iSubject, iKnifeId)
{
	return iKnifeId == g_iKnifeId ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public efk_status_draw(iPlayer, iSubject, iKnifeId)
{
	if (iKnifeId != g_iKnifeId)
		return PLUGIN_CONTINUE
	new Float:fNow = get_gametime()
	set_hudmessage(255, 145, 45, 0.01, 0.65, 0, 0.0, 0.2, 0.0, 0.0, HUDCHANNEL_STATUS)
	show_hudmessage(iPlayer, "%s (F) | Cover: %d%% | Heat: %d%%^nOverheat: %s %s (T): %d s^nWave: %d s | Rush: %d s^nFeast: %d s | Zone: %d s^nE: %s | R: %s | Shield lock: %d s",
		Player[iSubject][ShieldMode] ? "Shield" : "Blade",
		floatround(Player[iSubject][CoverCharge] * 20.0), floatround(g_fHeat[iSubject]),
		OVERHEAT_NAMES[Player[iSubject][OverheatMode]], Player[iSubject][OverheatEnabled] ? "ON" : "OFF",
		seconds_left(Player[iSubject][OverheatReady], fNow), seconds_left(Player[iSubject][WaveReady], fNow),
		seconds_left(Player[iSubject][RushReady], fNow), seconds_left(Player[iSubject][FeastReady], fNow),
		seconds_left(Player[iSubject][ZoneReady], fNow),
		Player[iSubject][ShieldMode] ? "Burner Rush" : "Heat / Burn / Heal",
		Player[iSubject][ShieldMode] ? "Inferno Zone" : "Ember Feast",
		seconds_left(floatmax(Player[iSubject][CoverLocked], Player[iSubject][ShieldLocked]), fNow))
	return PLUGIN_CONTINUE
}

seconds_left(Float:fUntil, Float:fNow)
{
	return floatround(floatmax(0.0, fUntil - fNow), floatround_ceil)
}
