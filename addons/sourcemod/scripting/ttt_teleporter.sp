#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "1.00"

#define BUY_TRAITOR			1
#define BUY_DETECTIVE		2
#define BUY_INNOCENT		4

#include <sourcemod>
#include <sdktools>
#include <logdebug>
#include <ttt>
#include <cstrike>
#include <sdkhooks>
#include <multicolors>

public Plugin myinfo = 
{
	name = "TTT - Teleporter", 
	author = PLUGIN_AUTHOR, 
	description = "Buy a teleporter in the shop :)", 
	version = PLUGIN_VERSION, 
	url = "painlessgaming.eu"
};

ConVar g_cPrice;
ConVar g_cName;
ConVar g_cMode;

bool g_bHasTeleporter[MAXPLAYERS + 1];
bool g_bHasPressed[MAXPLAYERS + 1];

float g_fPosition[MAXPLAYERS + 1][3];

int g_iEnt[MAXPLAYERS + 1];

public void OnPluginStart()
{
	InitDebugLog("teleporter_debug", "TTTT", ADMFLAG_ROOT);
	LogDebug("Started");
	
	g_cPrice = CreateConVar("ttt_teleporter_price", "25000", "The price for the teleporter");
	g_cName = CreateConVar("ttt_teleporter_name", "Teleporter", "The name of the Teleporter in the Shop");
	g_cMode = CreateConVar("ttt_teleporter_mode", "1", "Who is able to buy the teleporter? 1=Traitor 2=Detective 4=Innocent (Add them if you want)");
	
	AddCommandListener(Command_Weapon, "+lookatweapon");
	
	LoadTranslations("teleporter.phrases");
	AutoExecConfig(true);
}

public OnMapStart()
{
	AddFileToDownloadsTable("particles/iEx.pcf");
	AddFileToDownloadsTable("particles/iEx2.pcf");
	AddFileToDownloadsTable("particles/boomer_fx.pcf");
	PrecacheGeneric("particles/boomer_fx.pcf",true);
	PrecacheGeneric("particles/iEx.pcf",true);
	PrecacheGeneric("particles/iEx2.pcf",true);
}

public Action Command_Weapon(int client, const char[] command, int argc)
{
	LogDebug("%d pressed lookupweapon", client);
	if (g_bHasTeleporter[client])
		LogDebug("%d has a teleporter", client);
	if (TTT_IsClientValid(client))
		LogDebug("%d Is valid", client);
	if (g_bHasTeleporter[client] && TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		LogDebug("%d's position 0 = %f", client, g_fPosition[client][0]);
		if (g_bHasPressed[client] && g_fPosition[client][1] != 0.0)
		{
			LogDebug("Teleported %d", client);
			GiveSmoke(client);
			TeleportEntity(client, g_fPosition[client], NULL_VECTOR, NULL_VECTOR);
			CreateTimer(1.75, Timer_Smoke, client);
			ResetClient(client);
		} else {
			LogDebug("%d pressed lookupweapon once", client);
			g_bHasPressed[client] = true;
			CreateTimer(1.0, Press_Timer, client);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (g_bHasTeleporter[client] && TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (buttons & IN_ATTACK2 && g_fPosition[client][0] == 0.0)
		{
			CPrintToChat(client, "%t", "Pos_Saved");
			GetClientAbsOrigin(client, g_fPosition[client]);
			LogDebug("Saved position for %d: %f", client, g_fPosition[client][1]);
		}
	}
}

public Action Timer_Smoke(Handle timer, int data)
{
	LogDebug("%d recieved", data);
	RemoveSmoke(data);
	return Plugin_Handled;
}

public Action Press_Timer(Handle timer, int data)
{
	g_bHasPressed[data] = false;
	return Plugin_Handled;
}

public void RemoveSmoke(int iClient)
{
	if (g_iEnt[iClient] != 0 && IsValidEdict(g_iEnt[iClient]) && IsClientInGame(iClient))
		AcceptEntityInput(g_iEnt[iClient], "Kill");
}

public void GiveSmoke(int iClient) {
	if (g_iEnt[iClient] != 0)
		RemoveSmoke(iClient);
	
	if (IsPlayerAlive(iClient))
	{
		float clientOrigin[3];
		GetClientAbsOrigin(iClient, clientOrigin);
		g_iEnt[iClient] = CreateEntityByName("info_particle_system");
		DispatchKeyValue(g_iEnt[iClient], "start_active", "0");
		DispatchKeyValue(g_iEnt[iClient], "effect_name", "boomer_explode_E");
		DispatchSpawn(g_iEnt[iClient]);
		TeleportEntity(g_iEnt[iClient], clientOrigin, NULL_VECTOR, NULL_VECTOR);
		ActivateEntity(g_iEnt[iClient]);
		SetVariantString("!activator");
		CreateTimer(0.25, Timer_Run, g_iEnt[iClient]);
	}
}

public Action Timer_Run(Handle timer, any ent)
{
	if (ent > 0 && IsValidEntity(ent))
	{
		AcceptEntityInput(ent, "Start");
	}
}

public void OnAllPluginsLoaded()
{
	int iPrice = g_cPrice.IntValue;
	
	if (iPrice > 0)
	{
		int iMode = g_cMode.IntValue;
		
		char sName[256];
		g_cName.GetString(sName, sizeof(sName));
		
		if (iMode & BUY_TRAITOR)
			TTT_RegisterCustomItem("teleporter_t", sName, iPrice, TTT_TEAM_TRAITOR);
		
		if (iMode & BUY_DETECTIVE)
			TTT_RegisterCustomItem("teleporter_d", sName, iPrice, TTT_TEAM_DETECTIVE);
		
		if (iMode & BUY_INNOCENT)
			TTT_RegisterCustomItem("teleporter_i", sName, iPrice, TTT_TEAM_INNOCENT);
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	LogDebug("%d bought %s", client, itemshort);
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if ((strcmp(itemshort, "teleporter_i", false) == 0)
			 || (strcmp(itemshort, "teleporter_d", false) == 0)
			 || (strcmp(itemshort, "teleporter_t", false) == 0))
		{
			g_bHasTeleporter[client] = true;
			LogDebug("%d bought a Teleporter", client);
			CPrintToChat(client, "%t", "Bought");
		}
	}
}

public void ResetClient(int iClient)
{
	g_bHasTeleporter[iClient] = false;
	g_fPosition[iClient][0] = 0.0;
	g_fPosition[iClient][1] = 0.0;
	g_fPosition[iClient][2] = 0.0;
	g_bHasPressed[iClient] = false;
}

public void Reset()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		ResetClient(i);
	}
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	Reset();
	return Plugin_Continue;
}

public Action TTT_OnRoundStart_Pre()
{
	Reset();
	return Plugin_Continue;
}

public void TTT_OnRoundStartFailed(int p, int r, int d)
{
	Reset();
}

public void TTT_OnRoundStart(int i, int t, int d)
{
	Reset();
}

public void TTT_OnClientDeath(int v, int a)
{
	ResetClient(v);
} 