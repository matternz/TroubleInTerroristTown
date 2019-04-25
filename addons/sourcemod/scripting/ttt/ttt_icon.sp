#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Icons"

int g_iIcon[MAXPLAYERS + 1] =  { -1, ... };

ConVar g_cAdminImmunity = null;
ConVar g_cSeeRoles = null;
ConVar g_cTraitorIcon = null;
ConVar g_cDetectiveIcon = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_SetIcon", Native_SetIcon);

    RegPluginLibrary("ttt_icon");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    
    TTT_StartConfig("icon");
    CreateConVar("ttt2_icon_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cSeeRoles = AutoExecConfig_CreateConVar("ttt_dead_players_can_see_other_roles", "0", "Allow dead players to see other roles. 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);
    g_cTraitorIcon = AutoExecConfig_CreateConVar("ttt_icon_traitor_icon", "decals/ttt/traitor_iconNew", "Path to traitor icon file");
    g_cDetectiveIcon = AutoExecConfig_CreateConVar("ttt_icon_detective_icon", "decals/ttt/detective_iconNew", "Path to detective icon file");
    g_cAdminImmunity = AutoExecConfig_CreateConVar("ttt_icon_dead_admin", "b", "Show traitor icon for dead admins? (Nothing to disable it)");
    TTT_EndConfig();
    
    HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeamPre, EventHookMode_Pre);

    CreateTimer(2.0, Timer_CreateIcon, _, TIMER_REPEAT);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnPluginEnd()
{
    LoopValidClients(i)
    {
        ClearIcon(i);
    }
}

public void OnMapStart()
{
    char sBuffer[PLATFORM_MAX_PATH];
    
    g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
    AddFileToDownloadsTable(sBuffer);

    g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
    AddFileToDownloadsTable(sBuffer);
    PrecacheModel(sBuffer);

    g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
    AddFileToDownloadsTable(sBuffer);

    g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
    AddFileToDownloadsTable(sBuffer);
    PrecacheModel(sBuffer);
}

public void OnClientDisconnect(int client)
{
    ClearIcon(client);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    LoopValidClients(client)
    {
        ClearIcon(client);
    }
}

public Action Timer_CreateIcon(Handle timer)
{
    if (!TTT_IsRoundActive())
    {
        return Plugin_Continue;
    }

    LoopValidClients(client)
    {
        if (IsPlayerAlive(client))
        {
            g_iIcon[client] = CreateIcon(client, TTT_GetClientRole(client));
        }
    }

    return Plugin_Continue;
}

public void TTT_OnRoundStart()
{
    ApplyIcons();
}

public void TTT_OnClientGetRole(int client, int role)
{
    g_iIcon[client] = CreateIcon(client, role);
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    ClearIcon(client);
}

public Action Event_PlayerTeamPre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(event.GetInt("team") == CS_TEAM_SPECTATOR)
    {
        ClearIcon(client);
    }

    return Plugin_Continue;
}

void ApplyIcons()
{
    LoopValidClients(i)
    {
        if (IsPlayerAlive(i))
        {
            g_iIcon[i] = CreateIcon(i, TTT_GetClientRole(i));
        }
    }
}

int CreateIcon(int client, int role)
{
    ClearIcon(client);

    if (role < TTT_TEAM_TRAITOR)
    {
        return -1;
    }

    char iTarget[16];
    Format(iTarget, 16, "client%d", client);
    DispatchKeyValue(client, "targetname", iTarget);

    float origin[3];

    GetClientAbsOrigin(client, origin);
    origin[2] = origin[2] + 80.0;

    int ent = CreateEntityByName("env_sprite");
    if (!ent)
    {
        return -1;
    }

    char sBuffer[PLATFORM_MAX_PATH];

    if (role == TTT_TEAM_DETECTIVE)
    {
        g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "%s.vmt", sBuffer);
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "%s.vmt", sBuffer);
    }

    DispatchKeyValue(ent, "model", sBuffer);
    DispatchKeyValue(ent, "classname", "env_sprite");
    DispatchKeyValue(ent, "spawnflags", "1");
    DispatchKeyValue(ent, "scale", "0.08");
    DispatchKeyValue(ent, "rendermode", "1");
    DispatchKeyValue(ent, "rendercolor", "255 255 255");
    DispatchSpawn(ent);
    TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
    SetVariantString(iTarget);
    AcceptEntityInput(ent, "SetParent", ent, ent);

    if (role == TTT_TEAM_TRAITOR)
    {
        SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmitT);
    }
    return ent;
}

public Action Hook_SetTransmitT(int entity, int client)
{
    if (TTT_IsClientValid(client))
    {
        if (!IsPlayerAlive(client))
        {
            if (g_cSeeRoles.BoolValue)
            {
                return Plugin_Continue;
            }
            else
            {
                if (TTT_CheckCommandAccess(client, "icon_immunity", g_cAdminImmunity, true))
                {
                    return Plugin_Continue;
                }
            }
        }

        if (IsPlayerAlive(client) && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
        {
            return Plugin_Continue;
        }
    }
    return Plugin_Handled;
}

void ClearIcon(int client)
{
    int role = TTT_GetClientRole(client);

    if (IsValidEdict(g_iIcon[client]))
    {
        if (role == TTT_TEAM_TRAITOR)
        {
            SDKUnhook(g_iIcon[client], SDKHook_SetTransmit, Hook_SetTransmitT);
        }
        AcceptEntityInput(g_iIcon[client], "Kill");
    }

    g_iIcon[client] = -1;

}

public int Native_SetIcon(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int role = GetNativeCell(2);

    g_iIcon[client] = CreateIcon(client, role);

    return 0;
}
