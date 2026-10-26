#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <reapi>
#include <xs>
#include <efk_core>
#include <efk_utils>

new const PLUGIN[] = "EFK: Ninja Knife"

#define KNIFE_CLASSNAME "weapon_next21_ninja"
#define KNIFE_MENUDESC  "KNIFE_NINJA_DESC"
#define KNIFE_CHATDESC  "KNIFE_NINJA_CHAT"

#define HP				90.0
#define GRAVITY			0.75
#define SPEED			255.0
#define MINDAMAGE		0.0
#define MAXDAMAGE		0.0

#define ABIL1_NAME		"Ninja"
#define ABIL1_CHARGE	7.143

#define Player[%1][%2]		g_player_data[%1 - 1][%2]
#define PlayerF[%1][%2]		g_player_data_f[%1 - 1][%2]

new const MODEL_V_KNIFE[] = "models/next21_efk/v_ninja_knife_b02.mdl"
new const MODEL_V_KNIFE_I[] = "models/next21_efk/v_ninja_knife_i_b02.mdl"
new const MODEL_P_KNIFE[] = "models/next21_efk/p_ninja_knife.mdl"

#define SOUND_KNIFE_HIT1	"next21_efk/ninja_knife_hit1.wav"
#define SOUND_KNIFE_STAB	"next21_efk/ninja_knife_stab.wav"
#define SOUND_KNIFE_HITWALL	"next21_efk/ninja_knife_hitwall1.wav"
#define SOUND_KNIFE_SLASH1	"next21_efk/ninja_knife_slash1.wav"
#define SOUND_KNIFE_SLASH2	"next21_efk/ninja_knife_slash2.wav"
#define SOUND_KNIFE_DEPLOY	"next21_efk/ninja_knife_deploy.wav"

#define HEAD_MODEL 		"models/GIB_Skull.mdl"

#define SOUND_UNINVIS		"next21_efk/ninja_uninvisible.wav"
#define SOUND_FAILABILITY	"next21_efk/fail_ability.wav"
#define SOUND_KAMUI			"next21_efk/kamui.wav"

#define CLASSNAME_FAKEPART	"next21_fakepart"
#define CLASSNAME_SHADOW_CLONE	"next21_ninja_shadow"
#define CLASSNAME_SHADOW_CLONE_KNIFE	"next21_ninja_shadow_knife"
#define MODEL_SHADOW_CLONE	"models/player/efk_player_b7/efk_player_b7.mdl"

#define INVISTIME		7.0
#define SHADOW_CLONE_DISTANCE	100.0
#define SHADOW_CLONE_RANGE	700.0
#define SHADOW_CLONE_LIFE	5.0
#define SHADOW_CLONE_SPREAD_TIME	0.5
#define SHADOW_CLONE_THINK_INTERVAL	0.02
#define SHADOW_AIM_RADIUS		48.0
#define SHADOW_GLOW_UPDATE_INTERVAL	0.1
#define SHADOW_JUMP_COOLDOWN	0.1
#define SHADOW_CLONE_RENDER_AMT	128.0

#define MODE_LASTMOVE		0
#define MODE_FOLLOW		1

#define TIME_FAKE		10.0

enum _:ViewSeq
{
	VIEW_SEQ_IDLE
}

enum _:NinjaModeType
{
	NINJA_MODE_INVISION,
	NINJA_MODE_KAMUI,
	NINJA_MODE_SHADOW
}

new const SZ_INFO_TARGET[]			= "info_target"
new const NINJA_MODE_NAMES[][] =
{
	"Invision",
	"Kamui",
	"Shadow Clones"
}

#define var_fakeowner				var_iuser2
#define var_shadow_endtime			var_fuser1
#define var_shadow_spread_starttime	var_fuser2
#define var_shadow_spread_endtime	var_fuser3
#define var_shadow_startorigin		var_vuser1
#define var_shadow_endorigin		var_vuser2
#define var_shadow_hull			var_iuser3

enum _:Player_Properties
{
	bool:IsAlive,
	Knife,
	Team,
	Mode,
	FakeSeq,
	FakeMode,
	FakeSkeleton,
	FakeShell,
	FakeKnife,
	FakeHat,
	CanSwap,
	ShadowTarget,
	bool:ShadowUsePressed
}

enum _:Player_Properties_F
{
	Float:InvisibleTime,
	Float:FakeVelocity[3],
	Float:FakeModeDelay,
	Float:FakeSolidDelay,
	Float:FakeInvisTimeDelay,
	Float:FakeRenderDalay,
	Float:FakeAttackDalay,
	Float:FakeStepDelay,
	Float:ShadowJumpTime,
	Float:ShadowGlowUpdateTime
}

new g_iKnifeId,
g_player_data[MAX_PLAYERS][Player_Properties], Float:g_player_data_f[32][Player_Properties_F],
Float:g_vShadowCloneOrigins[MAX_PLAYERS + 1][3][3], bool:g_bShadowClonePositionValid[MAX_PLAYERS + 1][3],
sprIllusion, g_pKnifeVStr, g_pKnifeInvisVStr, g_pKnifePMdl

public plugin_precache()
{
	g_pKnifeVStr = engfunc(EngFunc_AllocString, MODEL_V_KNIFE)
	g_pKnifeInvisVStr = engfunc(EngFunc_AllocString, MODEL_V_KNIFE_I)
	precache_model(MODEL_V_KNIFE)
	precache_model(MODEL_V_KNIFE_I)
	g_pKnifePMdl = precache_model(MODEL_P_KNIFE)

	precache_sound(SOUND_KNIFE_HIT1)
	precache_sound(SOUND_KNIFE_STAB)
	precache_sound(SOUND_KNIFE_HITWALL)
	precache_sound(SOUND_KNIFE_SLASH1)
	precache_sound(SOUND_KNIFE_SLASH2)
	precache_sound(SOUND_KNIFE_DEPLOY)

	precache_sound(SOUND_UNINVIS)
	precache_sound(SOUND_FAILABILITY)
	precache_sound(SOUND_KAMUI)

	sprIllusion = precache_model("sprites/next21_efk/illusion_destroy.spr")

	precache_generic(fmt("sprites/%s.txt", KNIFE_CLASSNAME))
}

public plugin_init()
{
	register_plugin(PLUGIN, EFK_VERSION, "Next21 Team")

	g_iKnifeId = kc_register_knife(KNIFE_CLASSNAME, KNIFE_MENUDESC, KNIFE_CHATDESC,
		g_pKnifeVStr, engfunc(EngFunc_AllocString, MODEL_P_KNIFE),
		g_pKnifePMdl, HP, GRAVITY, SPEED, MINDAMAGE, MAXDAMAGE)

	if (g_iKnifeId < 0)
		set_fail_state("[%s] error registration", PLUGIN)

	kc_register_ability1(g_iKnifeId, ABIL1_NAME, ABIL1_CHARGE)
	kc_knife_set_flags(g_iKnifeId, KNFF_ABIL1_TOGGLEABLE)
	kc_knife_set_charge_boost_coeff(g_iKnifeId, 0.25)

	kc_knife_set_sound(g_iKnifeId, "weapons/knife_hit1.wav", SOUND_KNIFE_HIT1)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_hit2.wav", SOUND_KNIFE_HIT1)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_hit3.wav", SOUND_KNIFE_HIT1)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_hit4.wav", SOUND_KNIFE_HIT1)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_stab.wav", SOUND_KNIFE_STAB)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_hitwall1.wav", SOUND_KNIFE_HITWALL)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_slash1.wav", SOUND_KNIFE_SLASH1)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_slash2.wav", SOUND_KNIFE_SLASH2)
	kc_knife_set_sound(g_iKnifeId, "weapons/knife_deploy1.wav", SOUND_KNIFE_DEPLOY)

	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1)
	RegisterHam(Ham_Player_PostThink, "player", "fw_PostThink", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_PrePrimaryAttack")
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_PreSecondaryAttack")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHookChain(RG_CSGameRules_CleanUpMap, "RG_CSGameRules_CleanUpMap_Post", true)

	register_impulse(100, "fw_PlayerFlashlight")

	register_forward(FM_EmitSound, "fw_EmitSound")
}

public client_putinserver(iPlayer)
{
	Player[iPlayer][IsAlive] = false
	Player[iPlayer][Team] = 0
	Player[iPlayer][Mode] = NINJA_MODE_INVISION
	Player[iPlayer][ShadowTarget] = 0
	Player[iPlayer][ShadowUsePressed] = false
	PlayerF[iPlayer][ShadowJumpTime] = 0.0
	PlayerF[iPlayer][ShadowGlowUpdateTime] = 0.0
}

public client_disconnected(iPlayer)
{
	Player[iPlayer][IsAlive] = false
	Player[iPlayer][Team] = 0
	shadow_remove_owned(iPlayer)

	if (Player[iPlayer][FakeSkeleton])
		fakeplayer_think(Player[iPlayer][FakeSkeleton])
}

public fw_PlayerSpawn(iPlayer)
{
	if (is_user_alive(iPlayer))
	{
		Player[iPlayer][IsAlive] = true
		PlayerF[iPlayer][FakeRenderDalay] = 0.0
		PlayerF[iPlayer][InvisibleTime] = 0.0
		PlayerF[iPlayer][ShadowJumpTime] = 0.0
		PlayerF[iPlayer][ShadowGlowUpdateTime] = 0.0
		Player[iPlayer][ShadowUsePressed] = false
		shadow_remove_owned(iPlayer)

		if (Player[iPlayer][Knife] == g_iKnifeId)
			ninja_update_ability_target(iPlayer)

		if (Player[iPlayer][FakeSkeleton])
			fakeplayer_think(Player[iPlayer][FakeSkeleton])
	}
}

new const Float:STEP_DELAY = 0.308333333334
new const STEP_SOUNDS[][] = {
	"player/pl_step1.wav",
	"player/pl_step2.wav",
	"player/pl_step3.wav",
	"player/pl_step4.wav"
}

public fw_PostThink(iPlayer)
{
	if (!Player[iPlayer][IsAlive] || Player[iPlayer][Knife] != g_iKnifeId)
		return HAM_IGNORED

	new Float:fGameTime = get_gametime()
	if (Player[iPlayer][Mode] == NINJA_MODE_SHADOW)
	{
		if (fGameTime >= PlayerF[iPlayer][ShadowGlowUpdateTime])
		{
			PlayerF[iPlayer][ShadowGlowUpdateTime] = fGameTime + SHADOW_GLOW_UPDATE_INTERVAL
			shadow_update_aim_glow(iPlayer)
		}

		new iButtons = get_entvar(iPlayer, var_button)
		if (!(iButtons & IN_USE))
			Player[iPlayer][ShadowUsePressed] = false
		else if (!Player[iPlayer][ShadowUsePressed])
		{
			Player[iPlayer][ShadowUsePressed] = true
			if (fGameTime >= PlayerF[iPlayer][ShadowJumpTime]
				&& !kc_player_in_silence(iPlayer) && kc_player_get_capture(iPlayer) == CAPTURE_NONE)
				shadow_jump(iPlayer)
		}

		return HAM_IGNORED
	}

	static iPlayerSeq, iFakeModeButton, iSwapButton

	if (fGameTime < kc_player_get_swap(iPlayer))
	{
		iFakeModeButton = IN_RELOAD
		iSwapButton = IN_USE
	}
	else
	{
		iFakeModeButton = IN_USE
		iSwapButton = IN_RELOAD
	}

	if (PlayerF[iPlayer][FakeRenderDalay] > 0.0 && PlayerF[iPlayer][FakeRenderDalay] <= fGameTime)
	{
		if (Player[iPlayer][FakeSkeleton])
		{
			set_entvar(Player[iPlayer][FakeShell], var_renderamt, 16.0)
			set_entvar(Player[iPlayer][FakeShell], var_rendermode, kRenderNormal)
		}
		PlayerF[iPlayer][FakeRenderDalay] = 0.0

		if (pev(iPlayer, pev_viewmodel) != g_pKnifeInvisVStr)
		{
			PlayerF[iPlayer][InvisibleTime] = 0.0
			engfunc(EngFunc_EmitSound, iPlayer, CHAN_STATIC, SOUND_UNINVIS, 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		else
			kc_player_invision(iPlayer, INVISTIME, Player[iPlayer][FakeSkeleton], 0)
	}

	static iFakeSkeleton
	iFakeSkeleton = Player[iPlayer][FakeSkeleton]

	if (!iFakeSkeleton)
		return HAM_IGNORED

	static iSeq
	iSeq = get_entvar(iFakeSkeleton, var_sequence)
	if (iSeq == 6 || iSeq == 7 || iSeq == 16 || iSeq == 17)
	{
		if (PlayerF[iPlayer][FakeStepDelay] < fGameTime
			&& get_entvar(iFakeSkeleton, var_flags) & FL_ONGROUND)
			{
				PlayerF[iPlayer][FakeStepDelay] = fGameTime + STEP_DELAY
				emit_sound(iFakeSkeleton, CHAN_BODY, STEP_SOUNDS[random(4)], 1.0, ATTN_IDLE, 0, PITCH_NORM)
			}
	}

	if (PlayerF[iPlayer][FakeModeDelay] < fGameTime)
	{
		if ((get_entvar(iPlayer, var_button) & iFakeModeButton) && !kc_player_in_silence(iPlayer))
		{
			PlayerF[iPlayer][FakeModeDelay] = fGameTime + 0.25
			Player[iPlayer][FakeMode] = Player[iPlayer][FakeMode] == MODE_LASTMOVE ? MODE_FOLLOW : MODE_LASTMOVE
		}
	}

	if (Player[iPlayer][CanSwap] && PlayerF[iPlayer][InvisibleTime] == 0.0 && (get_entvar(iPlayer, var_button) & iSwapButton)
		&& kc_player_get_capture(iPlayer) == CAPTURE_NONE && !kc_player_in_silence(iPlayer))
	{
		static seq
		iPlayerSeq = get_entvar(iPlayer, var_gaitsequence)

		switch (iPlayerSeq)
		{
			case 1: seq = 0 // idle
			case 2: seq = 2 // crouch_idle
			case 3: seq = 4 // walk
			case 4: seq = 6 // run
			case 5: seq = 8 // crouch_run
			default: seq = -1
		}

		if (seq != -1)
		{
			new Float:vOrigin[2][3], Float:vVelocity[3], Float:vAngles[2][3], blend[2]

			get_entvar(iPlayer, var_origin, vOrigin[0])
			get_entvar(iFakeSkeleton, var_origin, vOrigin[1])

			get_entvar(iPlayer, var_velocity, PlayerF[iPlayer][FakeVelocity])
			get_entvar(iFakeSkeleton, var_velocity, vVelocity)

			vAngles[0][0] = 0.0
			vAngles[0][1] = get_member(iPlayer, m_flGaityaw)
			vAngles[0][2] = 0.0

			get_entvar(iFakeSkeleton, var_angles, vAngles[1])

			pev(iPlayer, pev_blending, blend)

			if (blend[0] <= 128)
			{
				blend[0] = min(blend[0], 127)
				set_pev(iFakeSkeleton, pev_blending_0, blend[0] * 2)
			}
			else
			{
				set_pev(iFakeSkeleton, pev_blending_0, (blend[0] - 128) * 2)
				seq++
			}

			if ((iPlayerSeq == 2 || iPlayerSeq == 5) && Player[iPlayer][FakeSeq] != 2 && Player[iPlayer][FakeSeq] != 5)
			{
				vOrigin[1][2] += 18.0

				engfunc(EngFunc_SetSize, iFakeSkeleton, {-16.0, -16.0, -18.0 }, { 16.0,  16.0,  32.0 })
			}
			else if ((Player[iPlayer][FakeSeq] == 2 || Player[iPlayer][FakeSeq] == 5) && iPlayerSeq != 2 && iPlayerSeq != 5)
			{
				set_entvar(iPlayer, var_flags, get_entvar(iPlayer, var_flags) | FL_DUCKING)
				engfunc(EngFunc_SetSize, iPlayer, {-16.0, -16.0, -18.0 }, { 16.0,  16.0,  32.0 })

				engfunc(EngFunc_SetSize, iFakeSkeleton, {-16.0, -16.0, -36.0 }, { 16.0,  16.0,  36.0 })
			}

			engfunc(EngFunc_SetOrigin, iFakeSkeleton, vOrigin[0])
			engfunc(EngFunc_SetOrigin, iPlayer, vOrigin[1])

			set_entvar(iFakeSkeleton, var_origin, vOrigin[0])
			set_entvar(iPlayer, var_origin, vOrigin[1])
			set_entvar(iFakeSkeleton, var_angles, vAngles[0])
			set_entvar(iFakeSkeleton, var_sequence, seq)
			set_entvar(iFakeSkeleton, var_framerate, (iPlayerSeq == 3 ? 2.0 : 1.0))

			set_entvar(iPlayer, var_velocity, vVelocity)
			set_entvar(iPlayer, var_angles, vAngles[1])
			set_entvar(iPlayer, var_fixangle, 1)

			checkstuck(iPlayer)

			Player[iPlayer][FakeSeq] = iPlayerSeq
			Player[iPlayer][CanSwap] = 0
		}
	}

	if (PlayerF[iPlayer][FakeSolidDelay] && PlayerF[iPlayer][FakeSolidDelay] <= fGameTime)
	{
		set_entvar(iFakeSkeleton, var_solid, SOLID_BBOX)
		set_entvar(iFakeSkeleton, var_gravity, GRAVITY)

		PlayerF[iPlayer][FakeSolidDelay] = 0.0

		new Float:vMins[3], Float:vMaxs[3]
		get_entvar(iFakeSkeleton, var_mins, vMins)
		get_entvar(iFakeSkeleton, var_maxs, vMaxs)

		engfunc(EngFunc_SetSize, iFakeSkeleton, vMins, vMaxs)
	}

	if (!PlayerF[iPlayer][FakeAttackDalay])
	{
		if (Player[iPlayer][FakeMode] == MODE_FOLLOW)
		{
			static blend[2], seq, Float:vecAngles[3]
			pev(iPlayer, pev_blending, blend)
			iPlayerSeq = get_entvar(iPlayer, var_gaitsequence)

			switch (iPlayerSeq)
			{
				case 1: seq = 0 // idle
				case 2: seq = 2 // crouch_idle
				case 3: seq = 4 // walk
				case 4: seq = 6 // run
				case 5: seq = 8 // crouch_run
				default: seq = -1
			}

			if (seq != -1)
			{
				get_entvar(iPlayer, var_velocity, PlayerF[iPlayer][FakeVelocity])

				if (blend[0] <= 128)
				{
					blend[0] = min(blend[0], 127)
					set_pev(iFakeSkeleton, pev_blending_0, blend[0] * 2)
				}
				else
				{
					set_pev(iFakeSkeleton, pev_blending_0, (blend[0] - 128) * 2)
					seq++
				}

				vecAngles[0] = 0.0
				vecAngles[1] = get_member(iPlayer, m_flGaityaw)
				vecAngles[2] = 0.0

				if (Player[iPlayer][FakeSeq] != iPlayerSeq)
				{
					if ((iPlayerSeq == 2 || iPlayerSeq == 5) && Player[iPlayer][FakeSeq] != 2 && Player[iPlayer][FakeSeq] != 5)
					{
						new Float:vOrigin[3]
						get_entvar(iFakeSkeleton, var_origin, vOrigin)
						vOrigin[2] -= 18.0
						engfunc(EngFunc_SetOrigin, iFakeSkeleton, vOrigin)
						set_entvar(iFakeSkeleton, var_origin, vOrigin)
						engfunc(EngFunc_SetSize, iFakeSkeleton, {-16.0, -16.0, -18.0 }, { 16.0,  16.0,  32.0 })
					}
					else if ((Player[iPlayer][FakeSeq] == 2 || Player[iPlayer][FakeSeq] == 5) && iPlayerSeq != 2 && iPlayerSeq != 5)
					{
						new Float:vOrigin[3]
						get_entvar(iFakeSkeleton, var_origin, vOrigin)
						vOrigin[2] += 18.0
						engfunc(EngFunc_SetOrigin, iFakeSkeleton, vOrigin)
						set_entvar(iFakeSkeleton, var_origin, vOrigin)
						engfunc(EngFunc_SetSize, iFakeSkeleton, {-16.0, -16.0, -36.0 }, { 16.0,  16.0,  36.0 })

						checkstuck(iPlayer)
					}

					set_entvar(iFakeSkeleton, var_frame, 0.0)

					Player[iPlayer][FakeSeq] = iPlayerSeq
				}

				set_entvar(iFakeSkeleton, var_angles, vecAngles)
				set_entvar(iFakeSkeleton, var_sequence, seq)
				set_entvar(iFakeSkeleton, var_framerate, (iPlayerSeq == 3 ? 2.0 : 1.0))
			}
		}
	}
	else if (PlayerF[iPlayer][FakeAttackDalay] <= fGameTime)
	{
		set_entvar(iFakeSkeleton, var_sequence, get_entvar(iFakeSkeleton, var_sequence) - 10)
		set_entvar(iFakeSkeleton, var_framerate, (iPlayerSeq == 3 ? 2.0 : 1.0))

		PlayerF[iPlayer][FakeAttackDalay] = 0.0
	}

	static Float:vVelocity[3]
	get_entvar(iFakeSkeleton, var_velocity, vVelocity)
	PlayerF[iPlayer][FakeVelocity][2] = vVelocity[2]
	set_entvar(iFakeSkeleton, var_velocity, PlayerF[iPlayer][FakeVelocity])

	return HAM_IGNORED
}

public fw_PrePrimaryAttack(iWeapon)
{
	if (GetHamReturnStatus() == HAM_SUPERCEDE)
		return HAM_SUPERCEDE

	if (is_nullent(iWeapon))
		return HAM_IGNORED

	new iPlayer = get_member(iWeapon, m_pPlayer)

	if (!Player[iPlayer][IsAlive])
		return HAM_IGNORED

	if (Player[iPlayer][Knife] != g_iKnifeId)
		return HAM_IGNORED

	if (Player[iPlayer][Mode] == NINJA_MODE_KAMUI && PlayerF[iPlayer][InvisibleTime] > 0.0)
	{
		kc_player_uninvision(iPlayer)
		set_member(iWeapon, m_Weapon_flNextPrimaryAttack, 0.35)
		set_member(iWeapon, m_Weapon_flNextSecondaryAttack, 0.35)
		return HAM_SUPERCEDE
	}

	return HAM_IGNORED
}

public fw_PreSecondaryAttack(iWeapon)
{
	if (GetHamReturnStatus() == HAM_SUPERCEDE)
		return HAM_SUPERCEDE

	if (is_nullent(iWeapon))
		return HAM_IGNORED

	new iPlayer = get_member(iWeapon, m_pPlayer)

	if (!Player[iPlayer][IsAlive])
		return HAM_IGNORED

	if (Player[iPlayer][Knife] != g_iKnifeId)
		return HAM_IGNORED

	if (Player[iPlayer][Mode] == NINJA_MODE_KAMUI && PlayerF[iPlayer][InvisibleTime] > 0.0)
	{
		kc_player_uninvision(iPlayer)
		set_member(iWeapon, m_Weapon_flNextPrimaryAttack, 0.35)
		set_member(iWeapon, m_Weapon_flNextSecondaryAttack, 0.35)
		return HAM_SUPERCEDE
	}

	if (Player[iPlayer][Mode] == NINJA_MODE_SHADOW)
	{
		new iTarget, iBody
		new Float:fDistance = get_user_aiming(iPlayer, iTarget, iBody)
		log_amx("[NinjaShadow] MOUSE2: player=%d mode=%d target=%d distance=%d charge=%d ready=%d silence=%d capture=%d",
			iPlayer, Player[iPlayer][Mode], iTarget, floatround(fDistance, floatround_floor),
			floatround(kc_player_get_abil1_charge(iPlayer), floatround_floor), kc_player_is_abil1_ready(iPlayer),
			kc_player_in_silence(iPlayer), _:kc_player_get_capture(iPlayer))
		return HAM_IGNORED
	}

	if (kc_player_in_silence(iPlayer))
		return HAM_IGNORED

	if (!kc_player_is_abil1_ready(iPlayer))
		return HAM_IGNORED

	if (!pev(iPlayer, pev_maxspeed))
		return HAM_IGNORED

	if (pev(iPlayer, pev_viewmodel) != g_pKnifeVStr)
		return HAM_IGNORED

	if (!check_stab_hit(iPlayer))
	{
		set_member(iPlayer, m_flNextAttack, 1.0)
		kc_player_set_view_anim(iPlayer, VIEW_SEQ_IDLE)

		return HAM_SUPERCEDE
	}

	return HAM_IGNORED
}

public fw_PlayerKilled(iVictim)
{
	Player[iVictim][IsAlive] = false
	PlayerF[iVictim][FakeRenderDalay] = 0.0
	shadow_remove_owned(iVictim)

	if (Player[iVictim][FakeSkeleton])
		fakeplayer_think(Player[iVictim][FakeSkeleton])
}

public efk_player_change_team(iPlayer, iTeam)
{
	Player[iPlayer][Team] = iTeam
	Player[iPlayer][ShadowTarget] = 0
	shadow_remove_owned(iPlayer)
}

public fw_FakeDamage(iEnt, iInflictor, iAttacker)
{
	if (is_nullent(iEnt))
		return HAM_IGNORED

	if (get_entvar(iEnt, var_impulse) != IMPULSE_FAKEPLAYER)
		return HAM_IGNORED

	for (new i = 1; i <= MaxClients; i++)
	{
		if (iEnt != Player[i][FakeSkeleton])
			continue

		if (is_entity_player(iAttacker))
		{
			if (iAttacker != i && Player[iAttacker][Team] == Player[i][Team])
				return HAM_SUPERCEDE

			if (iAttacker == iInflictor && Player[iAttacker][Team] != Player[i][Team] &&
				kc_player_get_vision(iAttacker) != VISION_BLIND && !kc_player_in_freeze(iAttacker) && !kc_player_in_chill(iAttacker))
			{
				send_msg_ScreenFade((1<<12), (1<<8), (1<<4), {255, 255, 255}, 100, MSG_ONE, _, iAttacker)
			}
		}

		new Float:vOrigin[3]
		get_entvar(iEnt, var_origin, vOrigin)

		send_msg_TE_SPRITE(vOrigin, sprIllusion, 8, 100)

		Player[i][FakeSkeleton] = 0
		Player[i][FakeShell] = 0
		Player[i][FakeKnife] = 0
		Player[i][FakeHat] = 0

		Player[i][CanSwap] = 0

		kc_invision_unfake(i)
	}

	new iPartEnt = NULLENT
	while ((iPartEnt = rg_find_ent_by_aiment(iPartEnt, CLASSNAME_FAKEPART, iEnt)))
		rg_remove_entity(iPartEnt)

	return HAM_IGNORED
}

public fakeplayer_think(iEnt)
{
	new iPartEnt = NULLENT
	while ((iPartEnt = rg_find_ent_by_aiment(iPartEnt, CLASSNAME_FAKEPART, iEnt)))
		rg_remove_entity(iPartEnt)

	new Float:vOrigin[3]
	get_entvar(iEnt, var_origin, vOrigin)

	send_msg_TE_SPRITE(vOrigin, sprIllusion, 8, 100)

	new iOwner = get_entvar(iEnt, var_fakeowner)

	Player[iOwner][FakeSkeleton] = 0
	Player[iOwner][FakeShell] = 0
	Player[iOwner][FakeKnife] = 0
	Player[iOwner][FakeHat] = 0

	Player[iOwner][CanSwap] = 0

	kc_invision_unfake(iOwner)

	rg_remove_entity(iEnt)
}

public fakeplayer_touch(iEnt, iOther)
{
	if (!iEnt)
		return HC_CONTINUE

	new iOwner = get_entvar(iEnt, var_fakeowner)

	if (is_entity_player(iOther))
	{
		if (PlayerF[iOwner][FakeSolidDelay])
			PlayerF[iOwner][FakeSolidDelay] = get_gametime() + 0.1
	}
	else
	{
		if (get_entvar(iOther, var_impulse) == IMPULSE_FIELD_WALL)
		{
			if (Player[get_entvar(iOther, var_owner)][Team] != Player[iOwner][Team])
				fakeplayer_think(iEnt)
		}
	}

	return HC_CONTINUE
}

public fw_PlayerFlashlight(iPlayer)
{
	if (Player[iPlayer][Knife] != g_iKnifeId)
		return PLUGIN_CONTINUE

	if (Player[iPlayer][IsAlive])
		ninja_cycle_mode(iPlayer)

	return PLUGIN_HANDLED
}

public efk_ability_toggle(iPlayer)
{
	return Player[iPlayer][Knife] == g_iKnifeId ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

ninja_cycle_mode(iPlayer)
{
	if (PlayerF[iPlayer][InvisibleTime] > 0.0)
		kc_player_uninvision(iPlayer)

	if (Player[iPlayer][FakeSkeleton])
		fakeplayer_think(Player[iPlayer][FakeSkeleton])

	Player[iPlayer][ShadowUsePressed] = false
	Player[iPlayer][ShadowTarget] = 0
	PlayerF[iPlayer][ShadowGlowUpdateTime] = 0.0
	Player[iPlayer][Mode] = (Player[iPlayer][Mode] + 1) % 3
	log_amx("[NinjaShadow] mode changed: player=%d mode=%d", iPlayer, Player[iPlayer][Mode])
	ninja_update_ability_target(iPlayer)
}

public fw_EmitSound(iEnt, channel, const sample[])
{
	return (iEnt <= MaxClients && Player[iEnt][FakeSkeleton] && equal(sample[7], "wpn_denyselect.wav"))
		? FMRES_SUPERCEDE : FMRES_IGNORED
}

public efk_status_draw(iPlayer, iSubject, iKnifeId)
{
	if (iKnifeId != g_iKnifeId)
		return PLUGIN_CONTINUE

	if (PlayerF[iSubject][InvisibleTime] > 0.0)
	{
		set_hudmessage(255, 255, 255, -1.0, -0.30, 0, 0.0, 0.1, 0.1, 0.0, HUDCHANNEL_STATUS)
		show_hudmessage(iPlayer, "%L", iPlayer, Player[iSubject][Mode] == NINJA_MODE_KAMUI ? "KAMUI_TIMER" : "INVISION_TIMER",
			floatmax(0.0, PlayerF[iSubject][InvisibleTime] - get_gametime()))
	}

	set_hudmessage(255, 255, 255, 0.01, -0.73, 0, 0.0, 0.2, 0.2, 0.0, HUDCHANNEL_ALTABILITY)
	static szAbilName[128]
	szAbilName[0] = 0

	if (Player[iSubject][FakeSkeleton])
	{
		switch(Player[iSubject][FakeMode])
		{
			case MODE_LASTMOVE: formatex(szAbilName, charsmax(szAbilName), "%L", iPlayer, "FAKE_MODE_LASTMOVE")
			case MODE_FOLLOW: formatex(szAbilName, charsmax(szAbilName), "%L", iPlayer, "FAKE_MODE_FOLLOW")
		}

		if (Player[iSubject][CanSwap] && PlayerF[iSubject][InvisibleTime] == 0.0)
		{
			if (kc_player_in_silence(iSubject))
				add(szAbilName, charsmax(szAbilName), "^n...NO SIGNAL...")
			else
				format(szAbilName, charsmax(szAbilName), "%s^n%L", szAbilName, iPlayer, "FAKE_SWAP")
		}
	}

	if (!kc_player_in_silence(iSubject))
	{
		format(szAbilName, charsmax(szAbilName), "%s^nMode: %s (F)", szAbilName,
			NINJA_MODE_NAMES[Player[iSubject][Mode]])
		if (Player[iSubject][Mode] == NINJA_MODE_SHADOW)
			add(szAbilName, charsmax(szAbilName), "^nTeleport to clone (E)")
	}

	show_hudmessage(iPlayer, szAbilName)

	return PLUGIN_CONTINUE
}

public efk_change_knife_core_post(iPlayer, iKnifeId)
{
	if (Player[iPlayer][Knife] == g_iKnifeId && iKnifeId != g_iKnifeId && PlayerF[iPlayer][InvisibleTime] > 0.0)
		kc_player_uninvision(iPlayer)

	Player[iPlayer][Knife] = iKnifeId
	PlayerF[iPlayer][FakeRenderDalay] = 0.0

	if (iKnifeId != g_iKnifeId)
		shadow_remove_owned(iPlayer)
	else
		ninja_update_ability_target(iPlayer)

	if (Player[iPlayer][FakeSkeleton])
		fakeplayer_think(Player[iPlayer][FakeSkeleton])
}

public efk_uninvisible(iPlayer)
{
	PlayerF[iPlayer][InvisibleTime] = 0.0
	engfunc(EngFunc_EmitSound, iPlayer, CHAN_STATIC, SOUND_UNINVIS, 1.0, ATTN_NORM, 0, PITCH_NORM)

	if (Player[iPlayer][Mode] == NINJA_MODE_KAMUI)
	{
		kc_player_unset_game_flag(iPlayer, PLGF_IN_UNABILITY)
		set_entvar(iPlayer, var_solid, SOLID_SLIDEBOX)
	}

	if (Player[iPlayer][IsAlive] && Player[iPlayer][Knife] == g_iKnifeId)
	{
		if (pev(iPlayer, pev_viewmodel) == g_pKnifeInvisVStr)
			set_pev(iPlayer, pev_viewmodel, g_pKnifeVStr)
	}
}

public efk_crosshair_draw_pre(iPlayer, iTarget, &AbilityType:iAbilType, bool:bDistanceAllowed)
{
	if (!iTarget || (iAbilType != ABIL_TARGET_PLAYER && iAbilType != ABIL_TARGET_ENEMY))
		return PLUGIN_CONTINUE

	if (get_entvar(iTarget, var_impulse) == IMPULSE_FAKEPLAYER)
	{
		new iOwner = get_entvar(iTarget, var_fakeowner)
		if (Player[iPlayer][Team] != Player[iOwner][Team])
		{
			kc_player_set_crosshair(iPlayer, bDistanceAllowed ? CROSSHAIR_OK : CROSSHAIR_FAR)
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}

public efk_ability_pre(iPlayer, iTarget)
{
	if (Player[iPlayer][Mode] == NINJA_MODE_SHADOW)
	{
		new bool:bTargetValid = is_entity_player(iTarget) && is_user_alive(iTarget) && iTarget != iPlayer
		new Float:fDistance = bTargetValid ? rg_entity_range(iPlayer, iTarget) : 0.0
		new bool:bPositionsValid = bTargetValid && fDistance <= SHADOW_CLONE_RANGE
		if (bPositionsValid)
			bPositionsValid = shadow_calculate_origins(iPlayer, iTarget)

		log_amx("[NinjaShadow] ability_pre: player=%d target=%d target_valid=%d distance=%d positions_valid=%d",
			iPlayer, iTarget, bTargetValid, floatround(fDistance, floatround_floor), bPositionsValid)

		if (!bPositionsValid)
			return PLUGIN_HANDLED

		Player[iPlayer][ShadowTarget] = iTarget
		return PLUGIN_CONTINUE
	}

	if (!iTarget)
		return PLUGIN_CONTINUE

	for (new i = 1, Float:fDist; i < MaxClients; i++)
	{
		if (Player[i][FakeSkeleton] == iTarget && Player[iPlayer][Team] != Player[i][Team])
		{
			fDist = rg_entity_range(iPlayer, iTarget)

			if (75.0 > fDist ||  fDist > 700.0)
				return PLUGIN_CONTINUE

			ExecuteHamB(Ham_TakeDamage, iTarget, i, iPlayer, 10.0, DMG_BULLET)

			if (kc_player_get_vision(iPlayer) != VISION_BLIND && !kc_player_in_freeze(iPlayer) && !kc_player_in_chill(iPlayer))
				send_msg_ScreenFade((1<<12), (1<<8), (1<<4), {255, 255, 255}, 100, MSG_ONE, _, iPlayer)

			client_cmd(iPlayer, "spk %s", SOUND_FAILABILITY)

			if (kc_player_get_vision(iPlayer) != VISION_FULL)
				kc_player_set_abil1_charge(iPlayer, -1.0)

			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}

public efk_ability(iPlayer)
{
	if (Player[iPlayer][Mode] == NINJA_MODE_SHADOW)
	{
		new iTarget = Player[iPlayer][ShadowTarget]
		new bool:bTargetValid = is_entity_player(iTarget) && is_user_alive(iTarget) && iTarget != iPlayer
		new Float:fDistance = bTargetValid ? rg_entity_range(iPlayer, iTarget) : 0.0
		new bool:bPositionsValid = bTargetValid && fDistance <= SHADOW_CLONE_RANGE
		if (bPositionsValid)
			bPositionsValid = shadow_calculate_origins(iPlayer, iTarget)

		log_amx("[NinjaShadow] ability: player=%d target=%d target_valid=%d distance=%d positions_valid=%d",
			iPlayer, iTarget, bTargetValid, floatround(fDistance, floatround_floor), bPositionsValid)
		if (!bPositionsValid)
			return PLUGIN_HANDLED

		new iCreated
		for (new i; i < 3; i++)
		{
			if (!g_bShadowClonePositionValid[iPlayer][i])
				continue

			new iHull = get_entvar(iTarget, var_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
			if (!shadow_is_hull_vacant(g_vShadowCloneOrigins[iPlayer][i], iHull, iPlayer))
			{
				log_amx("[NinjaShadow] clone skipped: player=%d target=%d index=%d reason=hull_blocked_at_spawn",
					iPlayer, iTarget, i)
				continue
			}

			new iClone = shadow_create_clone(iPlayer, iTarget, g_vShadowCloneOrigins[iPlayer][i])
			if (!iClone)
			{
				log_amx("[NinjaShadow] entity creation failed: player=%d target=%d index=%d", iPlayer, iTarget, i)
				continue
			}

			iCreated++
			log_amx("[NinjaShadow] clone created: player=%d target=%d index=%d ent=%d", iPlayer, iTarget, i, iClone)
		}

		Player[iPlayer][ShadowTarget] = 0
		log_amx("[NinjaShadow] clone set complete: player=%d target=%d created=%d", iPlayer, iTarget, iCreated)
		return iCreated ? PLUGIN_CONTINUE : PLUGIN_HANDLED
	}

	if (Player[iPlayer][Mode] != NINJA_MODE_KAMUI && !pev(iPlayer, pev_maxspeed))
		return PLUGIN_HANDLED

	set_pev(iPlayer, pev_viewmodel, g_pKnifeInvisVStr)

	if (kc_player_get_vision(iPlayer) != VISION_BLIND && !kc_player_in_freeze(iPlayer) && !kc_player_in_chill(iPlayer))
		send_msg_ScreenFade((1<<12), (1<<8), (1<<4), {8, 37, 103}, 130, MSG_ONE, _, iPlayer)

	new Float:fGameTime = get_gametime()

	PlayerF[iPlayer][InvisibleTime] = fGameTime + INVISTIME

	if (Player[iPlayer][Mode] == NINJA_MODE_KAMUI)
	{
		Player[iPlayer][CanSwap] = 0
		PlayerF[iPlayer][FakeRenderDalay] = 0.0

		kc_player_unfreeze(iPlayer)
		kc_player_unchill(iPlayer)
		kc_player_unburn(iPlayer)
		kc_player_invision(iPlayer, INVISTIME, 0, 1)
		kc_player_set_game_flag(iPlayer, PLGF_IN_UNABILITY)
		set_entvar(iPlayer, var_solid, SOLID_NOT)

		engfunc(EngFunc_EmitSound, iPlayer, CHAN_STATIC, SOUND_KAMUI, 1.0, ATTN_NORM, 0, PITCH_NORM)

		checkstuck(iPlayer)

		return PLUGIN_CONTINUE
	}

	PlayerF[iPlayer][FakeRenderDalay] = fGameTime + 0.1

	new plFlags = get_entvar(iPlayer, var_flags)
	if (!(plFlags & FL_ONGROUND) || (plFlags & FL_INWATER))
		return PLUGIN_CONTINUE

	new plBut = get_entvar(iPlayer, var_button)
	if ((plBut & IN_DUCK) && !(plFlags & FL_DUCKING))
		return PLUGIN_CONTINUE

	new iFakeSkeleton = Player[iPlayer][FakeSkeleton]

	if (iFakeSkeleton)
		fakeplayer_think(iFakeSkeleton)

	iFakeSkeleton = rg_create_entity(SZ_INFO_TARGET)
	if (is_nullent(iFakeSkeleton))
	{
		Player[iPlayer][FakeSkeleton] = 0
		return PLUGIN_CONTINUE
	}

	Player[iPlayer][FakeSkeleton] = iFakeSkeleton

	set_fake_params(iPlayer, iFakeSkeleton)
	set_pev(iFakeSkeleton, pev_nextthink, fGameTime + TIME_FAKE)

	PlayerF[iPlayer][FakeSolidDelay] = fGameTime + 0.1

	new iFakeShell = rg_create_entity(SZ_INFO_TARGET)
	Player[iPlayer][FakeShell] = iFakeShell

	set_entvar(iFakeShell, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(iFakeShell, var_aiment, iFakeSkeleton)
	set_entvar(iFakeShell, var_classname, CLASSNAME_FAKEPART)
	set_entvar(iFakeShell, var_impulse, IMPULSE_FAKEPLAYER_SHELL)

	//set_entvar(iFakeShell, var_modelindex, get_entvar(iPlayer, var_modelindex))
	engfunc(EngFunc_SetModel, iFakeShell, fmt("models/player/%s/%s.mdl",
		CUSTOM_PLAYER_MODEL, CUSTOM_PLAYER_MODEL))

	set_entvar(iFakeShell, var_body, get_entvar(iPlayer, var_body))
	set_entvar(iFakeShell, var_skin, get_entvar(iPlayer, var_skin))

	set_entvar(iFakeShell, var_rendermode, kRenderTransAlpha)
	set_entvar(iFakeShell, var_renderamt, 0.1)

	new iFakeKnife = rg_create_entity(SZ_INFO_TARGET)
	Player[iPlayer][FakeKnife] = iFakeKnife

	set_entvar(iFakeKnife, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(iFakeKnife, var_rendermode, kRenderNormal)
	set_entvar(iFakeKnife, var_aiment, iFakeSkeleton)
	set_entvar(iFakeKnife, var_classname, CLASSNAME_FAKEPART)

	set_entvar(iFakeKnife, var_modelindex, g_pKnifePMdl)

	new iHatEnt = kc_player_get_hat_ent(iPlayer)
	if (iHatEnt)
	{
		new iFakeHat = rg_create_entity(SZ_INFO_TARGET)
		Player[iPlayer][FakeHat] = iFakeHat

		set_entvar(iFakeHat, var_movetype, MOVETYPE_FOLLOW)
		set_entvar(iFakeHat, var_rendermode, kRenderNormal)
		set_entvar(iFakeHat, var_aiment, iFakeSkeleton)
		set_entvar(iFakeHat, var_classname, CLASSNAME_FAKEPART)
		set_entvar(iFakeHat, var_modelindex, get_entvar(iHatEnt, var_modelindex))

		new iHatBody = get_entvar(iHatEnt, var_body)

		set_entvar(iFakeHat, var_impulse, IMPULSE_FAKEHAT)
		set_entvar(iFakeHat, var_skin, get_entvar(iHatEnt, var_skin))
		set_entvar(iFakeHat, var_body, iHatBody)

		set_entvar(iFakeHat, var_sequence, iHatBody)
		set_entvar(iFakeHat, var_framerate, 1.0)
		set_entvar(iFakeHat, var_animtime, fGameTime)
	}

	Player[iPlayer][CanSwap] = 1

	return PLUGIN_CONTINUE
}

shadow_jump(iPlayer)
{
	if (Player[iPlayer][Mode] != NINJA_MODE_SHADOW)
		return PLUGIN_HANDLED

	new Float:fGameTime = get_gametime()
	if (fGameTime < PlayerF[iPlayer][ShadowJumpTime])
		return PLUGIN_HANDLED

	new iClone = shadow_get_aimed_clone(iPlayer)
	if (is_nullent(iClone))
		return PLUGIN_HANDLED

	new Float:vOldOrigin[3], Float:vNewOrigin[3], Float:vVelocity[3], Float:vBaseVelocity[3], Float:vCloneAngles[3]
	get_entvar(iPlayer, var_origin, vOldOrigin)
	get_entvar(iClone, var_origin, vNewOrigin)
	get_entvar(iClone, var_angles, vCloneAngles)
	get_entvar(iPlayer, var_velocity, vVelocity)
	get_entvar(iPlayer, var_basevelocity, vBaseVelocity)

	new iHull = get_entvar(iPlayer, var_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
	if (!shadow_is_hull_vacant(vNewOrigin, iHull, iPlayer))
		return PLUGIN_HANDLED

	new bool:bHit = shadow_damage_segment(iPlayer, vOldOrigin, vNewOrigin)
	engfunc(EngFunc_SetOrigin, iPlayer, vNewOrigin)
	set_entvar(iPlayer, var_origin, vNewOrigin)
	set_entvar(iPlayer, var_angles, vCloneAngles)
	set_entvar(iPlayer, var_v_angle, vCloneAngles)
	set_entvar(iPlayer, var_fixangle, 1)
	set_entvar(iPlayer, var_velocity, vVelocity)
	set_entvar(iPlayer, var_basevelocity, vBaseVelocity)

	rg_set_animation(iPlayer, PLAYER_ATTACK1)
	engfunc(EngFunc_EmitSound, iPlayer, CHAN_WEAPON,
		bHit ? SOUND_KNIFE_HIT1 : (random(2) ? SOUND_KNIFE_SLASH1 : SOUND_KNIFE_SLASH2),
		1.0, ATTN_NORM, 0, PITCH_NORM)

	PlayerF[iPlayer][ShadowJumpTime] = fGameTime + SHADOW_JUMP_COOLDOWN
	shadow_remove_clone(iClone)

	return PLUGIN_CONTINUE
}

ninja_update_ability_target(iPlayer)
{
	if (Player[iPlayer][Knife] != g_iKnifeId)
		return

	if (Player[iPlayer][Mode] == NINJA_MODE_SHADOW)
	{
		kc_player_set_abil1_type(iPlayer, ABIL_TARGET_PLAYER)
		kc_player_set_abil1_dist(iPlayer, 0.0, SHADOW_CLONE_RANGE)
	}
	else
	{
		kc_player_set_abil1_type(iPlayer, ABIL_NORMAL)
		kc_player_set_abil1_dist(iPlayer)
	}
}

bool:shadow_calculate_origins(iPlayer, iTarget)
{
	new Float:vOrigin[3], Float:vOwnerOrigin[3], Float:vLookDirection[3]
	new Float:vAngles[3], Float:vForward[3], Float:vRight[3]
	get_entvar(iTarget, var_origin, vOrigin)
	get_entvar(iPlayer, var_origin, vOwnerOrigin)
	xs_vec_sub(vOrigin, vOwnerOrigin, vLookDirection)
	vLookDirection[2] = 0.0

	if (xs_vec_len(vLookDirection) < 0.001)
	{
		get_entvar(iPlayer, var_v_angle, vAngles)
		vAngles[0] = 0.0
		vAngles[2] = 0.0
	}
	else
	{
		xs_vec_normalize(vLookDirection, vLookDirection)
		vector_to_angle(vLookDirection, vAngles)
		vAngles[0] = 0.0
		vAngles[2] = 0.0
	}

	angle_vector(vAngles, ANGLEVECTOR_FORWARD, vForward)
	angle_vector(vAngles, ANGLEVECTOR_RIGHT, vRight)

	new iValidPositions
	for (new i; i < 3; i++)
	{
		g_bShadowClonePositionValid[iPlayer][i] = false

		new Float:vDirection[3], Float:vOffset[3]
		switch (i)
		{
			case 0: xs_vec_copy(vForward, vDirection)
			case 1: xs_vec_neg(vRight, vDirection)
			case 2: xs_vec_copy(vRight, vDirection)
		}

		xs_vec_mul_scalar(vDirection, SHADOW_CLONE_DISTANCE, vOffset)
		xs_vec_add(vOrigin, vOffset, g_vShadowCloneOrigins[iPlayer][i])

		new Float:vStart[3], Float:vEnd[3], Float:fFraction
		xs_vec_copy(g_vShadowCloneOrigins[iPlayer][i], vStart)
		xs_vec_copy(vStart, vEnd)
		vStart[2] += 48.0
		vEnd[2] -= 96.0

		new iTrace = create_tr2()
		engfunc(EngFunc_TraceLine, vStart, vEnd, IGNORE_MONSTERS, iTarget, iTrace)
		get_tr2(iTrace, TR_flFraction, fFraction)
		if (fFraction >= 1.0)
		{
			log_amx("[NinjaShadow] placement failed: player=%d target=%d index=%d reason=no_floor", iPlayer, iTarget, i)
			free_tr2(iTrace)
			continue
		}

		get_tr2(iTrace, TR_vecEndPos, g_vShadowCloneOrigins[iPlayer][i])
		free_tr2(iTrace)

		new Float:fFloorDelta = floatabs(g_vShadowCloneOrigins[iPlayer][i][2] - vOrigin[2])
		if (fFloorDelta > 64.0)
		{
			log_amx("[NinjaShadow] placement failed: player=%d target=%d index=%d reason=floor_delta delta=%d",
				iPlayer, iTarget, i, floatround(fFloorDelta, floatround_floor))
			continue
		}

		new Float:vOwnerMins[3]
		get_entvar(iPlayer, var_mins, vOwnerMins)
		g_vShadowCloneOrigins[iPlayer][i][2] -= vOwnerMins[2]
		g_vShadowCloneOrigins[iPlayer][i][2] += 1.0
		new iHull = get_entvar(iPlayer, var_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
		if (!shadow_is_hull_vacant(g_vShadowCloneOrigins[iPlayer][i], iHull, iPlayer))
		{
			log_amx("[NinjaShadow] placement failed: player=%d target=%d index=%d reason=hull_blocked",
				iPlayer, iTarget, i)
			continue
		}

		g_bShadowClonePositionValid[iPlayer][i] = true
		iValidPositions++
		log_amx("[NinjaShadow] placement OK: player=%d target=%d index=%d origin=(%d,%d,%d)",
			iPlayer, iTarget, i,
			floatround(g_vShadowCloneOrigins[iPlayer][i][0], floatround_floor),
			floatround(g_vShadowCloneOrigins[iPlayer][i][1], floatround_floor),
			floatround(g_vShadowCloneOrigins[iPlayer][i][2], floatround_floor))
	}

	return iValidPositions > 0
}

shadow_create_clone(iOwner, iTarget, const Float:vOrigin[3])
{
	new iClone = rg_create_entity(SZ_INFO_TARGET)
	if (is_nullent(iClone))
		return NULLENT

	new Float:vAngles[3], Float:vTargetOrigin[3], Float:vStartOrigin[3]
	new Float:fGameTime = get_gametime()
	new Float:vTargetMins[3], Float:vOwnerMins[3], Float:vLookDirection[3]
	get_entvar(iTarget, var_origin, vTargetOrigin)
	get_entvar(iTarget, var_origin, vStartOrigin)
	get_entvar(iTarget, var_mins, vTargetMins)
	get_entvar(iOwner, var_mins, vOwnerMins)
	vStartOrigin[2] += vTargetMins[2] - vOwnerMins[2] + 1.0
	xs_vec_sub(vTargetOrigin, vOrigin, vLookDirection)
	vector_to_angle(vLookDirection, vAngles)
	vAngles[2] = 0.0

	new iHull = get_entvar(iOwner, var_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
	new iSeq = iHull == HULL_HEAD ? 2 : 0

	engfunc(EngFunc_SetModel, iClone, MODEL_SHADOW_CLONE)
	engfunc(EngFunc_SetOrigin, iClone, vStartOrigin)
	engfunc(EngFunc_SetSize, iClone, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0})

	set_entvar(iClone, var_classname, CLASSNAME_SHADOW_CLONE)
	set_entvar(iClone, var_impulse, IMPULSE_NINJA_SHADOW)
	set_entvar(iClone, var_owner, iOwner)
	set_entvar(iClone, var_team, get_member(iOwner, m_iTeam))
	set_entvar(iClone, var_origin, vStartOrigin)
	set_entvar(iClone, var_angles, vAngles)
	set_entvar(iClone, var_sequence, iSeq)
	set_entvar(iClone, var_frame, 0.0)
	set_entvar(iClone, var_framerate, 1.0)
	set_entvar(iClone, var_animtime, fGameTime)
	set_entvar(iClone, var_body, get_entvar(iOwner, var_body))
	set_entvar(iClone, var_skin, get_entvar(iOwner, var_skin))
	set_entvar(iClone, var_shadow_startorigin, vStartOrigin)
	set_entvar(iClone, var_shadow_endorigin, vOrigin)
	set_entvar(iClone, var_shadow_hull, iHull)
	set_entvar(iClone, var_shadow_spread_starttime, fGameTime)
	set_entvar(iClone, var_shadow_spread_endtime, fGameTime + SHADOW_CLONE_SPREAD_TIME)
	set_entvar(iClone, var_movetype, MOVETYPE_NONE)
	set_entvar(iClone, var_solid, SOLID_NOT)
	set_entvar(iClone, var_takedamage, DAMAGE_NO)
	set_entvar(iClone, var_rendermode, kRenderNormal)
	set_entvar(iClone, var_renderfx, kRenderFxGlowShell)
	set_entvar(iClone, var_rendercolor, Float:{0.0, 0.0, 0.0})
	set_entvar(iClone, var_renderamt, SHADOW_CLONE_RENDER_AMT)
	set_entvar(iClone, var_shadow_endtime, fGameTime + SHADOW_CLONE_LIFE)
	set_entvar(iClone, var_nextthink, fGameTime + SHADOW_CLONE_THINK_INTERVAL)

	new iCloneKnife = rg_create_entity(SZ_INFO_TARGET)
	if (!is_nullent(iCloneKnife))
	{
		set_entvar(iCloneKnife, var_movetype, MOVETYPE_FOLLOW)
		set_entvar(iCloneKnife, var_rendermode, kRenderNormal)
		set_entvar(iCloneKnife, var_aiment, iClone)
		set_entvar(iCloneKnife, var_classname, CLASSNAME_SHADOW_CLONE_KNIFE)
		set_entvar(iCloneKnife, var_owner, iOwner)
		set_entvar(iCloneKnife, var_modelindex, g_pKnifePMdl)
	}

	SetThink(iClone, "shadow_clone_think")
	return iClone
}

public shadow_clone_think(iClone)
{
	new Float:fGameTime = get_gametime()
	new Float:fEndTime = get_entvar(iClone, var_shadow_endtime)
	if (fGameTime >= fEndTime)
	{
		shadow_remove_clone(iClone)
		return
	}

	new Float:fSpreadEndTime = get_entvar(iClone, var_shadow_spread_endtime)
	new Float:vStartOrigin[3], Float:vEndOrigin[3], Float:vOrigin[3]
	get_entvar(iClone, var_shadow_startorigin, vStartOrigin)
	get_entvar(iClone, var_shadow_endorigin, vEndOrigin)

	if (fGameTime < fSpreadEndTime)
	{
		new Float:fProgress = floatclamp((fGameTime - get_entvar(iClone, var_shadow_spread_starttime))
			/ SHADOW_CLONE_SPREAD_TIME, 0.0, 1.0)
		new Float:fInv = 1.0 - fProgress
		new Float:fEase = 1.0 - fInv * fInv * fInv
		new Float:vDirection[3], Float:vOffset[3]
		xs_vec_sub(vEndOrigin, vStartOrigin, vDirection)
		xs_vec_mul_scalar(vDirection, fEase, vOffset)
		xs_vec_add(vStartOrigin, vOffset, vOrigin)

		if (!shadow_is_world_hull_vacant(vOrigin, get_entvar(iClone, var_shadow_hull), iClone))
		{
			log_amx("[NinjaShadow] clone removed during spread: ent=%d reason=hull_blocked", iClone)
			shadow_remove_clone(iClone)
			return
		}

		engfunc(EngFunc_SetOrigin, iClone, vOrigin)
		set_entvar(iClone, var_origin, vOrigin)
		set_entvar(iClone, var_nextthink, floatmin(fGameTime + SHADOW_CLONE_THINK_INTERVAL, fSpreadEndTime))
		return
	}

	if (!shadow_is_world_hull_vacant(vEndOrigin, get_entvar(iClone, var_shadow_hull), iClone))
	{
		log_amx("[NinjaShadow] clone removed after spread: ent=%d reason=hull_blocked", iClone)
		shadow_remove_clone(iClone)
		return
	}

	engfunc(EngFunc_SetOrigin, iClone, vEndOrigin)
	set_entvar(iClone, var_origin, vEndOrigin)
	set_entvar(iClone, var_nextthink, floatmin(fGameTime + 0.1, fEndTime))
}

shadow_remove_clone(iClone)
{
	if (is_nullent(iClone) || get_entvar(iClone, var_impulse) != IMPULSE_NINJA_SHADOW)
		return

	new iKnife = NULLENT
	while ((iKnife = rg_find_ent_by_aiment(iKnife, CLASSNAME_SHADOW_CLONE_KNIFE, iClone)))
		rg_remove_entity(iKnife)

	rg_remove_entity(iClone)
}

shadow_remove_owned(iOwner)
{
	new iClone = NULLENT
	while ((iClone = rg_find_ent_by_class(iClone, CLASSNAME_SHADOW_CLONE)))
		if (get_entvar(iClone, var_owner) == iOwner)
			shadow_remove_clone(iClone)
}

public RG_CSGameRules_CleanUpMap_Post()
{
	new iClone = NULLENT
	while ((iClone = rg_find_ent_by_class(iClone, CLASSNAME_SHADOW_CLONE)))
		shadow_remove_clone(iClone)
}

bool:shadow_is_hull_vacant(const Float:vOrigin[3], iHull, iIgnore)
{
	new iTrace = create_tr2()
	engfunc(EngFunc_TraceHull, vOrigin, vOrigin, DONT_IGNORE_MONSTERS, iHull, iIgnore, iTrace)
	new bool:bVacant = !get_tr2(iTrace, TR_StartSolid) && !get_tr2(iTrace, TR_AllSolid) && get_tr2(iTrace, TR_InOpen)
	free_tr2(iTrace)
	return bVacant
}

bool:shadow_is_world_hull_vacant(const Float:vOrigin[3], iHull, iIgnore)
{
	new iTrace = create_tr2()
	engfunc(EngFunc_TraceHull, vOrigin, vOrigin, IGNORE_MONSTERS, iHull, iIgnore, iTrace)
	new bool:bVacant = !get_tr2(iTrace, TR_StartSolid) && !get_tr2(iTrace, TR_AllSolid) && get_tr2(iTrace, TR_InOpen)
	free_tr2(iTrace)
	return bVacant
}

shadow_update_aim_glow(iPlayer)
{
	new iClone = shadow_get_aimed_clone(iPlayer)
	if (is_nullent(iClone))
		return

	new Float:vOrigin[3]
	get_entvar(iClone, var_origin, vOrigin)
	vOrigin[2] += 36.0
	send_msg_TE_DLIGHT(vOrigin, 48, {255, 255, 255}, 2, 0, MSG_ONE, _, iPlayer)
}

shadow_get_aimed_clone(iPlayer)
{
	new Float:vStart[3], Float:vAngles[3], Float:vForward[3], Float:vViewOfs[3]
	get_entvar(iPlayer, var_origin, vStart)
	get_entvar(iPlayer, var_view_ofs, vViewOfs)
	xs_vec_add(vStart, vViewOfs, vStart)
	get_entvar(iPlayer, var_v_angle, vAngles)
	angle_vector(vAngles, ANGLEVECTOR_FORWARD, vForward)

	new iBestClone = NULLENT
	new Float:fBestDistance = SHADOW_CLONE_RANGE + 1.0
	new Float:fNow = get_gametime()
	new iClone = NULLENT
	while ((iClone = rg_find_ent_by_class(iClone, CLASSNAME_SHADOW_CLONE)))
	{
		if (get_entvar(iClone, var_owner) != iPlayer || get_entvar(iClone, var_shadow_endtime) <= fNow
			|| get_entvar(iClone, var_shadow_spread_endtime) > fNow)
			continue

		new Float:vCloneOrigin[3], Float:vAimOrigin[3], Float:vOffset[3], Float:vClosest[3]
		get_entvar(iClone, var_origin, vCloneOrigin)
		xs_vec_copy(vCloneOrigin, vAimOrigin)
		vAimOrigin[2] += 36.0
		xs_vec_sub(vAimOrigin, vStart, vOffset)
		new Float:fAlong = xs_vec_dot(vOffset, vForward)
		if (fAlong <= 0.0 || fAlong > SHADOW_CLONE_RANGE || fAlong >= fBestDistance)
			continue

		xs_vec_mul_scalar(vForward, fAlong, vClosest)
		xs_vec_add(vStart, vClosest, vClosest)
		if (get_distance_f(vAimOrigin, vClosest) > SHADOW_AIM_RADIUS)
			continue

		new iTrace = create_tr2()
		new Float:fFraction
		engfunc(EngFunc_TraceLine, vStart, vAimOrigin, IGNORE_MONSTERS, iPlayer, iTrace)
		get_tr2(iTrace, TR_flFraction, fFraction)
		free_tr2(iTrace)
		if (fFraction < 0.98)
			continue

		fBestDistance = fAlong
		iBestClone = iClone
	}

	return iBestClone
}

bool:shadow_damage_segment(iPlayer, const Float:vStart[3], const Float:vEnd[3])
{
	new Float:vSegment[3]
	xs_vec_sub(vEnd, vStart, vSegment)
	new Float:fLengthSq = xs_vec_dot(vSegment, vSegment)
	if (fLengthSq <= 0.0)
		return false

	new bool:bHit = false

	for (new iTarget = 1; iTarget <= MaxClients; iTarget++)
	{
		if (iTarget == iPlayer || !is_user_alive(iTarget))
			continue

		new Float:vOrigin[3], Float:vOffset[3], Float:vClosest[3]
		get_entvar(iTarget, var_origin, vOrigin)
		vOrigin[2] += 36.0
		xs_vec_sub(vOrigin, vStart, vOffset)
		new Float:fAlong = floatclamp(xs_vec_dot(vOffset, vSegment) / fLengthSq, 0.0, 1.0)
		xs_vec_mul_scalar(vSegment, fAlong, vClosest)
		xs_vec_add(vStart, vClosest, vClosest)
		if (get_distance_f(vOrigin, vClosest) > 48.0)
			continue

		set_member(iTarget, m_LastHitGroup, HIT_GENERIC)
		new iDamageAttacker = get_member(iTarget, m_iTeam) == get_member(iPlayer, m_iTeam) ? 0 : iPlayer
		ExecuteHamB(Ham_TakeDamage, iTarget, iPlayer, iDamageAttacker, 5.0, DMG_GENERIC)
		bHit = true

		if (!is_user_alive(iTarget))
			continue

		kc_player_slow(iTarget, 0.1, 0.5)
	}

	return bHit
}

set_fake_params(iOwner, iFakeSkeleton)
{
	engfunc(EngFunc_SetModel, iFakeSkeleton, MODEL_PLAYER_ANIMATIONS)

	new blend[2], seq, iPlayerSeq, Float:vAngles[3]
	pev(iOwner, pev_blending, blend)
	iPlayerSeq = get_entvar(iOwner, var_gaitsequence)

	new Float:fFrameRate = (iPlayerSeq == 3 ? 2.0 : 1.0)

	set_entvar(iFakeSkeleton, var_classname, CLASSNAME_FAKEPLAYER)
	set_entvar(iFakeSkeleton, var_impulse, IMPULSE_FAKEPLAYER)
	set_entvar(iFakeSkeleton, var_team, Player[iOwner][Team])
	set_entvar(iFakeSkeleton, var_framerate, fFrameRate)
	set_entvar(iFakeSkeleton, var_gravity, 0.000001)
	set_entvar(iFakeSkeleton, var_movetype, MOVETYPE_PUSHSTEP)
	set_entvar(iFakeSkeleton, var_solid, SOLID_TRIGGER)
	set_entvar(iFakeSkeleton, var_rendermode, kRenderTransAlpha)
	set_entvar(iFakeSkeleton, var_renderamt, 0.0)
	set_entvar(iFakeSkeleton, var_takedamage, 1.0)
	set_entvar(iFakeSkeleton, var_health, 1.0)
	set_entvar(iFakeSkeleton, var_fakeowner, iOwner)

	switch (iPlayerSeq)
	{
		case 1: seq = 0 // idle
		case 2: seq = 2 // crouch_idle
		case 3: seq = 4 // walk
		case 4: seq = 6 // run
		case 5: seq = 8 // crouch_run
	}

	if(blend[0] <= 128)
	{
		blend[0] = min(blend[0], 127)
		set_pev(iFakeSkeleton, pev_blending_0, blend[0] * 2)
	}
	else
	{
		set_pev(iFakeSkeleton, pev_blending_0, (blend[0] - 128) * 2)
		seq++
	}

	if (iPlayerSeq == 2 || iPlayerSeq == 5)
		engfunc(EngFunc_SetSize, iFakeSkeleton, {-16.0, -16.0, -18.0 }, { 16.0,  16.0,  32.0 })
	else
		engfunc(EngFunc_SetSize, iFakeSkeleton, {-16.0, -16.0, -36.0 }, { 16.0,  16.0,  36.0 })

	vAngles[0] = 0.0
	vAngles[1] = get_member(iOwner, m_flGaityaw)
	vAngles[2] = 0.0

	new main_seq = get_entvar(iOwner, var_sequence)
	if(main_seq  == 74 || main_seq  == 76)
	{
		new Float:fGameTime = get_gametime()

		set_entvar(iFakeSkeleton, var_sequence, seq + 10)
		set_entvar(iFakeSkeleton, var_frame, 0.0)
		set_entvar(iFakeSkeleton, var_animtime, fGameTime)
		PlayerF[iOwner][FakeAttackDalay] = fGameTime + 1.366666 / fFrameRate
	}
	else
	{
		set_entvar(iFakeSkeleton, var_sequence, seq)
		set_entvar(iFakeSkeleton, var_frame, Float:get_member(iOwner, m_flGaitframe))
	}

	set_entvar(iFakeSkeleton, var_angles, vAngles)

	new Float:vOrigin[3]
	get_entvar(iOwner, var_origin, vOrigin)
	get_entvar(iOwner, var_velocity, PlayerF[iOwner][FakeVelocity])

	engfunc(EngFunc_SetOrigin, iFakeSkeleton, vOrigin)
	set_entvar(iFakeSkeleton, var_origin, vOrigin)

	Player[iOwner][FakeMode] = MODE_LASTMOVE
	Player[iOwner][FakeSeq] = iPlayerSeq

	static fakeSoldReg
	if (!fakeSoldReg)
	{
		RegisterHamFromEntity(Ham_TakeDamage, iFakeSkeleton, "fw_FakeDamage")
		fakeSoldReg = true
	}

	SetThink(iFakeSkeleton, "fakeplayer_think")
	SetTouch(iFakeSkeleton, "fakeplayer_touch")
}

new const Float:fUnstuckSize[][3] = {
	{0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
	{0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
	{0.0, 0.0, 6.0}, {0.0, 0.0, -6.0}, {0.0, 6.0, 0.0}, {0.0, -6.0, 0.0}, {6.0, 0.0, 0.0}, {-6.0, 0.0, 0.0}, {-6.0, 6.0, 6.0}, {6.0, 6.0, 6.0}, {6.0, -6.0, 6.0}, {6.0, 6.0, -6.0}, {-6.0, -6.0, 6.0}, {6.0, -6.0, -6.0}, {-6.0, 6.0, -6.0}, {-6.0, -6.0, -6.0},
	{0.0, 0.0, 8.0}, {0.0, 0.0, -8.0}, {0.0, 8.0, 0.0}, {0.0, -8.0, 0.0}, {8.0, 0.0, 0.0}, {-8.0, 0.0, 0.0}, {-8.0, 8.0, 8.0}, {8.0, 8.0, 8.0}, {8.0, -8.0, 8.0}, {8.0, 8.0, -8.0}, {-8.0, -8.0, 8.0}, {8.0, -8.0, -8.0}, {-8.0, 8.0, -8.0}, {-8.0, -8.0, -8.0},
	{0.0, 0.0, 10.0}, {0.0, 0.0, -10.0}, {0.0, 10.0, 0.0}, {0.0, -10.0, 0.0}, {10.0, 0.0, 0.0}, {-10.0, 0.0, 0.0}, {-10.0, 10.0, 10.0}, {10.0, 10.0, 10.0}, {10.0, -10.0, 10.0}, {10.0, 10.0, -10.0}, {-10.0, -10.0, 10.0}, {10.0, -10.0, -10.0}, {-10.0, 10.0, -10.0}, {-10.0, -10.0, -10.0}
}

checkstuck(const iPlayer)
{
	new Float:vOrigin[3], Float:vMins[3], Float:vVec[3]

	get_entvar(iPlayer, var_origin, vOrigin)
	new iHull = get_entvar(iPlayer, var_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
	if (!is_hull_vacant(vOrigin, iHull, iPlayer) && get_entvar(iPlayer, var_movetype) != MOVETYPE_NOCLIP && get_entvar(iPlayer, var_solid) != SOLID_NOT)
	{
		get_entvar(iPlayer, var_mins, vMins)
		vVec[2] = vOrigin[2]
		for (new i; i < sizeof fUnstuckSize; ++i)
		{
			vVec[0] = vOrigin[0] - vMins[0] * fUnstuckSize[i][0]
			vVec[1] = vOrigin[1] - vMins[1] * fUnstuckSize[i][1]
			vVec[2] = vOrigin[2] - vMins[2] * fUnstuckSize[i][2]
			if (is_hull_vacant(vVec, iHull, iPlayer))
			{
				set_entvar(iPlayer, var_origin, vVec)
				break
			}
		}
	}
}

bool:is_hull_vacant(Float:vOrigin[3], iHull, iEnt)
{
	engfunc(EngFunc_TraceHull, vOrigin, vOrigin, DONT_IGNORE_MONSTERS, iHull, iEnt, 0)
	return !get_tr2(0, TR_StartSolid) || !get_tr2(0, TR_AllSolid)
}

Float:rg_entity_range(iEntA, iEntB)
{
	static Float:vOriginA[3], Float:vOriginB[3]
	get_entvar(iEntA, var_origin, vOriginA)
	get_entvar(iEntB, var_origin, vOriginB)

	return get_distance_f(vOriginA, vOriginB)
}

rg_find_ent_by_aiment(iEnt, const szClassName[], iAimEnt)
{
	while ((iEnt = rg_find_ent_by_class(iEnt, szClassName)) && get_entvar(iEnt, var_aiment) != iAimEnt) {}
	return iEnt
}

check_stab_hit(iPlayer)
{
	new tr = create_tr2()
	new Float:vSrc[3], Float:vEnd[3], Float:vAdd[3]

	get_entvar(iPlayer, var_origin, vSrc)
	get_entvar(iPlayer, var_view_ofs, vEnd)
	xs_vec_add(vSrc, vEnd, vSrc)

	get_entvar(iPlayer, var_v_angle, vAdd)
	engfunc(EngFunc_MakeVectors, vAdd)
	global_get(glb_v_forward, vAdd)
	xs_vec_mul_scalar(vAdd, 32.0, vAdd)
	xs_vec_add(vSrc, vAdd, vEnd)

	new Float:fFraction
	engfunc(EngFunc_TraceLine, vSrc, vEnd, DONT_IGNORE_MONSTERS, iPlayer, tr)
	get_tr2(tr, TR_flFraction, fFraction)

	if (fFraction >= 1.0)
	{
		engfunc(EngFunc_TraceHull, vSrc, vEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, iPlayer, tr)
		get_tr2(tr, TR_flFraction, fFraction)
	}

	free_tr2(tr)
	return fFraction < 1.0
}
