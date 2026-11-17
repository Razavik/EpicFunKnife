new g_iTestA, g_iTestB, g_iPassed, g_iFailed
new Float:g_fTickHealth

public test_create_bots()
{
	g_iTestA = engfunc(EngFunc_CreateFakeClient, "FireTestA")
	g_iTestB = engfunc(EngFunc_CreateFakeClient, "FireTestB")
	new players[2]; players[0] = g_iTestA; players[1] = g_iTestB
	for (new i; i < 2; i++)
	{
		new p = players[i], name[32]; get_user_name(p, name, charsmax(name))
		dllfunc(DLLFunc_ClientConnect, p, name, "127.0.0.1", "")
		dllfunc(DLLFunc_ClientPutInServer, p)

	}
	set_task(8.0, "test_cases", 49001)
	set_task(1.0, "test_finish_bots", 49004)
	set_task(0.05, "test_move", 49002, _, _, "b")
}

public test_finish_bots()
{
	new players[2]; players[0] = g_iTestA; players[1] = g_iTestB
	for (new i; i < 2; i++)
	{
		new p = players[i]
		rg_join_team(p, i == 0 ? TEAM_TERRORIST : TEAM_CT)
		set_member(p, m_iJoiningState, JOINED)
		set_member(p, m_bJustConnected, false)
		ExecuteHamB(Ham_CS_RoundRespawn, p)
		kc_player_give_knife(p, g_iKnifeId, false, false)
		new w = rg_find_weapon_bpack_by_name(p, "weapon_knife")
		if (!w) w = rg_give_item(p, "weapon_knife")
		rg_switch_weapon(p, w)
		ExecuteHamB(Ham_Item_Deploy, w)
		message_begin(MSG_ONE, get_user_msgid("CurWeapon"), _, p)
		write_byte(1); write_byte(CSW_KNIFE); write_byte(-1); message_end()
		server_print("[FireTest] bot %d alive=%d team=%d hp=%f", p, is_user_alive(p), get_member(p, m_iTeam), Float:get_entvar(p, var_health))
	}
}
public test_move()
{
	new players[2]; players[0] = g_iTestA; players[1] = g_iTestB
	for (new i; i < 2; i++)
		if (is_user_connected(players[i]))
			engfunc(EngFunc_RunPlayerMove, players[i], Float:{0.0, 0.0, 0.0}, 0.0, 0.0, 0.0, 0, 0, 50)
}

test_assert(const name[], bool:pass, Float:actual=0.0)
{
	if (pass) g_iPassed++; else g_iFailed++
	server_print("[FireTest] %s %s (%.3f)", pass ? "PASS" : "FAIL", name, actual)
}

public test_cases()
{
	new a = g_iTestA, b = g_iTestB
	server_print("[FireTest] before cases: a hp=%f dead=%d flags=%d join=%d; b hp=%f dead=%d flags=%d join=%d", Float:get_entvar(a,var_health), get_entvar(a,var_deadflag), get_entvar(a,var_flags), get_member(a,m_iJoiningState), Float:get_entvar(b,var_health), get_entvar(b,var_deadflag), get_entvar(b,var_flags), get_member(b,m_iJoiningState))
	test_assert("both bots alive", is_user_alive(a) && is_user_alive(b))
	kc_player_unset_game_flag(a, PLGF_IN_UNABILITY)
	kc_player_unset_game_flag(b, PLGF_IN_UNABILITY)
	kc_player_set_abil4_charge(a, 100.0)
	kc_player_set_abil4_charge(b, 100.0)
	test_assert("shared ability guard", can_act(a))
	server_print("[FireTest] weapons a=%d b=%d knives a=%d b=%d g=%d", get_user_weapon(a), get_user_weapon(b), Player[a][Knife], Player[b][Knife], g_iKnifeId)
	set_entvar(a, var_health, 100.0); set_entvar(b, var_health, 1000.0)
	add_heat(b, a, 40.0)
	test_assert("wave amount 40", floatabs(g_fHeat[b] - 40.0) < 0.01, g_fHeat[b])
	add_heat(b, a, 70.0)
	test_assert("heat threshold resets and discards overflow", g_fHeat[b] == 0.0, g_fHeat[b])
	test_assert("ignition starts for 6 seconds", kc_player_in_burn(b) == 30, float(kc_player_in_burn(b)))
	add_heat(b, a, 50.0)
	test_assert("burn extension 3 seconds", kc_player_in_burn(b) == 45, float(kc_player_in_burn(b)))
	add_heat(b, a, 50.0)
	test_assert("burn capped at 10 seconds", kc_player_in_burn(b) == 50, float(kc_player_in_burn(b)))
	kc_player_unburn(b)
	g_fHeat[b] = 0.0
	add_heat(a, a, 50.0)
	test_assert("no self heat", g_fHeat[a] == 0.0, g_fHeat[a])
	set_entvar(b, var_waterlevel, 1)
	add_heat(b, a, 50.0)
	test_assert("water rejects heat", g_fHeat[b] == 0.0, g_fHeat[b])
	set_entvar(b, var_waterlevel, 0)
	Player[a][OverheatMode] = 1; Player[a][OverheatEnabled] = true; Player[a][OverheatReady] = 0.0
	g_fHeat[b] = 70.0; Player[a][InMelee] = true
	ExecuteHamB(Ham_TakeDamage, b, a, a, 15.0, DMG_BULLET)
	Player[a][InMelee] = false
	new Float:hp = get_entvar(b, var_health)
	test_assert("Burn melee plus rounded 27", floatabs(hp - 958.0) < 0.01, hp)
	test_assert("Burn consumes heat without ignition", g_fHeat[b] == 0.0 && !kc_player_in_burn(b))
	test_assert("Overheat cooldown starts after hit", Player[a][OverheatReady] > get_gametime() + 16.9)
	Player[a][OverheatMode] = 2; Player[a][OverheatReady] = 0.0
	g_fHeat[b] = 70.0; set_entvar(a, var_health, 30.0); Player[a][InMelee] = true
	ExecuteHamB(Ham_TakeDamage, b, a, a, 15.0, DMG_BULLET)
	Player[a][InMelee] = false
	hp = get_entvar(a, var_health)
	test_assert("Heal rounded 40", floatabs(hp - 70.0) < 0.01, hp)
	Player[a][OverheatReady] = 0.0; g_fHeat[b] = 0.0; set_entvar(a, var_health, 30.0); Player[a][InMelee] = true
	ExecuteHamB(Ham_TakeDamage, b, a, a, 15.0, DMG_BULLET)
	Player[a][InMelee] = false
	hp = get_entvar(a, var_health)
	test_assert("Heal base 17 at zero heat", floatabs(hp - 47.0) < 0.01, hp)
	Player[a][ShieldMode] = true; Player[a][CoverCharge] = 5.0
	begin_cover(a)
	new Float:pos[3]; get_entvar(a, var_origin, pos); pos[0] += 100.0
	test_assert("Cover raising delay", !cover_blocks(a, pos))
	Player[a][CoverRaised] = get_gametime() - 0.1
	test_assert("Cover front blocks", cover_blocks(a, pos))
	pos[0] -= 200.0
	test_assert("Cover rear bypasses", !cover_blocks(a, pos))
	get_entvar(a, var_origin, pos); pos[1] += 100.0
	test_assert("Cover side bypasses", !cover_blocks(a, pos))
	get_entvar(a, var_origin, pos); pos[0] += 100.0
	new ent = create_effect(b, EFFECT_WAVE, pos, 1.0)
	test_assert("projectile native calls Cover", kc_player_blocks_projectile(a, ent))
	rg_remove_entity(ent)
	end_cover(a)
	Player[a][CoverCharge] = 1.0
	spend_cover(a)
	test_assert("full exhaustion starts 15 second lock", Player[a][CoverCharge] == 0.0 && Player[a][CoverLocked] > get_gametime() + 14.9)
	Player[a][ShieldMode] = false
	Player[a][WaveReady] = get_gametime() + 10.0
	Player[a][NextSwitch] = 0.0
	Player[a][ShieldLocked] = 0.0
	efk_ability4(a)
	test_assert("mode switch preserves cooldown", Player[a][WaveReady] > get_gametime() + 9.9)
	test_assert("mode switch preserves charge", Player[a][CoverCharge] == 0.0)
	test_more()
	kc_player_unburn(b); set_entvar(b, var_health, 1000.0)
	kc_player_ignite(b, a, 2.0, 10.0)
	g_fTickHealth = get_entvar(b, var_health)
	set_task(1.05, "test_burn_result", 49003)
}

public test_burn_result()
{
	new Float:damage = g_fTickHealth - Float:get_entvar(g_iTestB, var_health)
	test_assert("fixed burn 1 HP per tick", damage >= 5.0 && damage <= 6.0, damage)
	server_print("[FireTest] RESULT %d passed, %d failed", g_iPassed, g_iFailed)
	server_cmd("quit")
}
public test_more()
{
	new a = g_iTestA, b = g_iTestB
	new Float:origin[3], Float:target[3], Float:angles[3], Float:dir[3], Float:floor[3]
	get_entvar(a, var_origin, origin)
	new bool:placed
	for (new i; i < 8; i++)
	{
		angles[1] = float(i) * 45.0
		angle_vector(angles, ANGLEVECTOR_FORWARD, dir)
		xs_vec_mul_scalar(dir, 100.0, target); xs_vec_add(origin, target, target)
		if (!ground_point(target, floor)) continue
		xs_vec_copy(floor, target); target[2] += 36.0
		engfunc(EngFunc_TraceHull, target, target, IGNORE_MONSTERS, HULL_HUMAN, b, 0)
		if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || is_wall_between(origin, target, a)) continue
		placed = true; break
	}
	test_assert("open fixture for area effects", placed)
	engfunc(EngFunc_SetOrigin, b, target)
	set_entvar(a, var_v_angle, angles)
	set_entvar(a, var_angles, angles)
	kc_player_unburn(b)
	g_fHeat[b] = 60.0; g_fLastHeat[b] = get_gametime() - 4.0
	Player[b][TickTime] = get_gametime() - 0.1
	fw_PreThink_Post(b)
	test_assert("Heat decays 10 per second", floatabs(g_fHeat[b] - 59.0) < 0.01, g_fHeat[b])
	Player[a][ShieldMode] = true; Player[a][CoverCharge] = 0.01
	Player[a][CoverLocked] = 0.0; Player[a][ShieldLocked] = 0.0
	Player[a][CoverRaised] = get_gametime() - 1.0; Player[a][CoverBaseSpeed] = SPEED
	Player[a][TickTime] = get_gametime() - 0.05
	set_entvar(a, var_button, IN_ATTACK2)
	g_fHeat[b] = 99.8
	fw_PreThink_Post(a)
	test_assert("last Cover charge still applies Heat", kc_player_in_burn(b) == 30, float(kc_player_in_burn(b)))
	test_assert("Cover exhaustion closes shield", Player[a][CoverRaised] == 0.0 && Player[a][CoverLocked] > get_gametime())
	set_entvar(a, var_button, 0)
	kc_player_unburn(b); g_fHeat[b] = 60.0
	new Float:beforeFeast = 30.0
	set_entvar(a, var_health, beforeFeast)
	ember_feast(a)
	test_assert("Feast converts 60 Heat into 20 HP", floatabs(Float:get_entvar(a, var_health) - 50.0) < 0.01)
	test_assert("Feast consumes Heat without ignition", g_fHeat[b] == 0.0 && !kc_player_in_burn(b))
	new weapon = rg_find_weapon_bpack_by_name(a, "weapon_knife")
	Player[a][ShieldMode] = false
	new Float:originalDamage = get_member(weapon, m_Knife_flSwingBaseDamage)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, weapon)
	test_assert("melee restores default weapon damage", Float:get_member(weapon, m_Knife_flSwingBaseDamage) == originalDamage)
	test_assert("primary attack interval 0.45 seconds", floatabs(Float:get_member(weapon, m_Weapon_flNextPrimaryAttack) - 0.45) < 0.01)
	Player[a][ShieldMode] = true
	kc_player_unburn(b); g_fHeat[b] = 0.0
	Player[a][CoverLocked] = 0.0; Player[a][CoverCharge] = 5.0
	new bool:zoneCreated = create_zone(a)
	test_assert("zone creates placed shield", zoneCreated)
	if (zoneCreated)
	{
		new ent = Player[a][Zone]
		test_assert("zone shield starts at 90 HP", Float:get_entvar(ent, var_health) == 90.0)
		new Float:pos[3]; get_entvar(ent, var_origin, pos)
		heat_area(a, ent, pos, ZONE_RADIUS, 20.0)
		test_assert("zone does not block its own Heat", floatabs(g_fHeat[b] - 20.0) < 0.01, g_fHeat[b])
		test_assert("zone consumes 20 percent Cover", floatabs(Player[a][CoverCharge] - 4.0) < 0.01)
		Player[a][NextSwitch] = 0.0
		efk_ability4(a)
		test_assert("active zone prevents Shield mode", !Player[a][ShieldMode])
		ExecuteHamB(Ham_TakeDamage, ent, b, b, 45.0, DMG_BULLET)
		test_assert("zone shield takes damage", Float:get_entvar(ent, var_health) == 45.0, Float:get_entvar(ent, var_health))
		ExecuteHamB(Ham_TakeDamage, ent, b, b, 45.0, DMG_BULLET)
		test_assert("destroyed zone removes shield and locks Shield", !Player[a][Zone] && Player[a][ShieldLocked] > get_gametime() + 9.9)
		Player[a][ShieldLocked] = 0.0
		if (create_zone(a))
		{
			ent = Player[a][Zone]
			set_entvar(ent, var_fuser1, get_gametime() - 0.1)
			zone_think(ent)
			test_assert("normal zone expiry has no destruction lock", !Player[a][Zone] && Player[a][ShieldLocked] == 0.0)
		}
	}
	Player[a][CoverCharge] = 0.0; Player[a][ZoneReady] = 0.0
	Player[a][ShieldMode] = true
	efk_ability3(a)
	test_assert("zone unavailable without Cover charge", !Player[a][Zone])
	Player[a][CoverCharge] = 5.0; Player[a][CoverLocked] = 0.0
	begin_rush(a)
	test_assert("full Rush consumes 20 percent", Player[a][RushFull] && floatabs(Player[a][CoverCharge] - 4.0) < 0.01)
	new Float:savedDir[3]; xs_vec_copy(Player[a][RushDirection], savedDir)
	angles[1] += 90.0; set_entvar(a, var_v_angle, angles)
	test_assert("Rush direction fixed at activation", xs_vec_dot(savedDir, Player[a][RushDirection]) > 0.999)
	stop_rush(a)
	test_assert("Rush restores movement and clears flag", get_entvar(a, var_movetype) != MOVETYPE_NOCLIP && !kc_player_check_game_flag(a, PLGF_IN_BURNRUSH))
	Player[a][CoverCharge] = 0.0
	begin_rush(a)
	test_assert("empty Rush has no Heat or trail", !Player[a][RushFull])
	efk_disenergy(a)
	test_assert("disenergy interrupts Rush", Player[a][RushUntil] == 0.0)
	Player[a][CoverCharge] = 5.0
	begin_rush(a)
	efk_freeze(a)
	test_assert("Frost interrupts Rush", Player[a][RushUntil] == 0.0)
	Player[a][ShieldMode] = false
	get_entvar(b, var_origin, target)
	new Float:start[3], Float:end[3], Float:direction[3]
	xs_vec_copy(target, start); start[2] -= 36.0; start[0] -= 16.0
	xs_vec_copy(start, end); end[0] += 32.0; direction[0] = 1.0
	new wave = create_effect(a, EFFECT_WAVE, start, 1.0)
	g_fHeat[b] = 0.0
	wave_hits(wave, a, start, end, direction)
	wave_hits(wave, a, start, end, direction)
	test_assert("wave hits a target only once", floatabs(g_fHeat[b] - 40.0) < 0.01, g_fHeat[b])
	rg_remove_entity(wave)
	wave = create_effect(a, EFFECT_WAVE, start, 1.0)
	target[2] += 80.0; engfunc(EngFunc_SetOrigin, b, target)
	g_fHeat[b] = 0.0
	wave_hits(wave, a, start, end, direction)
	test_assert("jump clears wave hit volume", g_fHeat[b] == 0.0)
	rg_remove_entity(wave)
	target[2] -= 80.0; engfunc(EngFunc_SetOrigin, b, target)
}