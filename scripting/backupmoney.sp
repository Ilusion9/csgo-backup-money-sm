#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <intmap>
#pragma newdecls required

enum GamePhase
{
	GAMEPHASE_WARMUP_ROUND,
	GAMEPHASE_PLAYING_STANDARD,	
	GAMEPHASE_PLAYING_FIRST_HALF,
	GAMEPHASE_PLAYING_SECOND_HALF,
	GAMEPHASE_HALFTIME,
	GAMEPHASE_MATCH_ENDED
};

IntMap g_Map_Money;
GamePhase g_GamePhase;

public Plugin myinfo = 
{
	name = "Backup Money",
	author = "Ilusion9",
	description = "Save players money on retry or team change.",
	version = "1.0",
	url = "https://github.com/Ilusion9/"
};

public void OnPluginStart()
{
	g_Map_Money = new IntMap();	
	
	HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
	g_GamePhase = GAMEPHASE_WARMUP_ROUND;
}

public void OnMapEnd()
{
	g_Map_Money.Clear();
}

public void Event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast) 
{
	if (IsValveWarmupPeriod())
	{
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
	{
		return;
	}
	
	int accountId = GetSteamAccountID(client);
	if (!accountId)
	{
		return;
	}
	
	if (event.GetBool("disconnect"))
	{
		g_Map_Money.SetValue(accountId, GetClientMoney(client));
	}
	else
	{
		if (event.GetInt("oldteam") < CS_TEAM_T)
		{
			return;
		}
		
		g_Map_Money.SetValue(accountId, GetClientMoney(client));
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) 
{
	if (IsValveWarmupPeriod() || event.GetBool("disconnect") || event.GetInt("team") < CS_TEAM_T)
	{
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
	{
		return;
	}
	
	int accountId = GetSteamAccountID(client);
	if (!accountId)
	{
		return;
	}
	
	int clientMoney;
	if (!g_Map_Money.GetValue(accountId, clientMoney))
	{
		return;
	}
	
	int currentMoney = GetClientMoney(client);
	if (clientMoney > currentMoney)
	{
		GiveClientMoney(client, clientMoney - currentMoney);
	}
	else
	{
		TakeClientMoney(client, currentMoney - clientMoney);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	GamePhase gamePhase = view_as<GamePhase>(GameRules_GetProp("m_gamePhase"));
	if (gamePhase == g_GamePhase)
	{
		return;
	}
	
	if (gamePhase == GAMEPHASE_PLAYING_STANDARD 
		|| gamePhase == GAMEPHASE_PLAYING_FIRST_HALF 
		|| gamePhase == GAMEPHASE_PLAYING_SECOND_HALF)
	{
		g_Map_Money.Clear();
	}
	
	g_GamePhase = gamePhase;
}

void GiveClientMoney(int client, int amount)
{
	int entity = CreateMoneyEntity();
	if (entity != -1)
	{
		SetVariantInt(amount);
		AcceptEntityInput(entity, "SetMoneyAmount");
		
		AcceptEntityInput(entity, "AddMoneyPlayer", client);
		RemoveEntity(entity);
	}
}

void TakeClientMoney(int client, int amount)
{
	int entity = CreateMoneyEntity();
	if (entity != -1)
	{
		SetVariantInt(amount);
		AcceptEntityInput(entity, "SetMoneyAmount");
		
		AcceptEntityInput(entity, "SpendMoneyFromPlayer", client);
		RemoveEntity(entity);
	}
}

bool IsValveWarmupPeriod()
{
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}

int GetClientMoney(int client)
{
	return GetEntProp(client, Prop_Send, "m_iAccount");
}

int CreateMoneyEntity()
{
	int entity = CreateEntityByName("game_money");
	if (entity != -1)
	{
		DispatchSpawn(entity);
		ActivateEntity(entity);
	}
	
	return entity;
}