#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Talk Override"

ConVar g_cEnableTVoice = null;

bool g_bTVoice[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[128];

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_StartConfig("talk_override");
    CreateConVar("ttt2_talk_override_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cEnableTVoice = AutoExecConfig_CreateConVar("tor_traitor_voice_chat", "1", "Enable traitor voice chat (command for players: sm_tvoice)?", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    if (g_cEnableTVoice.BoolValue)
    {
        RegConsoleCmd("sm_tvoice", Command_TVoice);
    }

    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);

    TTT_LoadTranslations();
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnClientPutInServer(int client)
{
    g_bTVoice[client] = false;
}

public void OnClientDisconnect(int client)
{
    g_bTVoice[client] = false;
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action Command_TVoice(int client, int args)
{
    if (!TTT_IsRoundActive())
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
    {
        return Plugin_Handled;
    }

    if (g_bTVoice[client])
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Traitor Voice Chat: Disabled!", client);

        g_bTVoice[client] = false;

        LoopValidClients(i)
        {
            SetListenOverride(i, client, Listen_Yes);

            if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
            {
                CPrintToChat(i, "%s %T", g_sPluginTag, "stopped talking in Traitor Voice Chat", i, client);
            }
        }
    }
    else
    {
        g_bTVoice[client] = true;

        CPrintToChat(client, "%s %T", g_sPluginTag, "Traitor Voice Chat: Enabled!", client);

        LoopValidClients(i)
        {
            if (TTT_GetClientRole(i) != TTT_TEAM_TRAITOR)
            {
                SetListenOverride(i, client, Listen_No);
            }
            else
            {
                CPrintToChat(i, "%s %T", g_sPluginTag, "is now talking in Traitor Voice Chat", i, client);
            }
        }
    }
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        LoopValidClients(i)
        {
            SetListenOverride(i, client, Listen_Yes);
        }
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(victim))
    {
        g_bTVoice[victim] = false;
        LoopValidClients(i)
        {
            if (TTT_IsPlayerAlive(i))
            {
                SetListenOverride(i, victim, Listen_No);
            }
            else
            {
                SetListenOverride(i, victim, Listen_Yes);
            }
        }
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        SetListen(client);
    }
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    LoopValidClients(i)
    {
        LoopValidClients(j)
        {
            SetListenOverride(i, j, Listen_Default);
        }
    }
}

public void TTT_OnClientGetRole(int client, int role)
{
    SetListen(client);
}

void SetListen(int client)
{
    LoopValidClients(i)
    {
        if (!TTT_IsPlayerAlive(client))
        {
            if (TTT_IsPlayerAlive(i))
            {
                SetListenOverride(i, client, Listen_No);
                SetListenOverride(client, i, Listen_Yes);
            }
            else
            {
                SetListenOverride(i, client, Listen_Yes);
                SetListenOverride(client, i, Listen_Yes);
            }
        }
        else
        {
            SetListenOverride(client, i, Listen_Yes);
            SetListenOverride(i, client, Listen_Yes);
        }
    }
}
