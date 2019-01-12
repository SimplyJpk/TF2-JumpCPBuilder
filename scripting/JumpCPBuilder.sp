#pragma semicolon 1

#include "JumpTimer"

#include <sourcemod>
#include <sdktools_functions>
#include <sdktools>
#include <morecolors>

//TODO Update the SQL to new syntax

#define PLUGIN_VERSION "0.9.0"

public Plugin myinfo = 
{
	name = "Control Point Builder", 
	author = "SimplyJpk", 
	description = "Attempts to Generate Control Points for Players to use, while offering Admins the ability to create Map specific Control Points.", 
	version = PLUGIN_VERSION, 
	url = "http://www.simplyjpk.com"
}

#define MAX_CPS				12

#define MAX_ENTITIES		64

#define MAX_CP_TYPES		3

#define CP_NAME_LENGTH		16

char TagColor[] = "{lightgreen}";

// Global Error Char
static char errorString[255];
// Global Query String
static char QueryString[400];

int CurrentDrawnBox = 0;

enum AXIS
{
	AX_X = 0, 
	AX_Y = 1, 
	AX_Z = 2, 
	AXIS_COUNT = 3
}

static char CPTypeNames[][] =  { "Normal", "Bonus", "Out of Bounds" };

Handle CPDatabase = INVALID_HANDLE;

float DefaultZoneMax[] =  { 100.0, 100.0, 200.0 };
float DefaultZoneMin[] =  { -100.0, -100.0, 0.0 };

#define RED    0
#define GRE    1
#define BLU    2
#define WHI    3
#define BLA    4
#define YEL    5

int colort[6][4] =  {  { 255, 0, 0, 255 }, { 0, 255, 0, 255 }, { 0, 0, 255, 255 }, { 255, 255, 255, 255 }, { 0, 0, 0, 255 }, { 255, 255, 0, 150 } };

// Current Map
char CURRENTMAP[128];
// More Information
int CPCount = 0;
// Stored Information
int ST_UniqueID[MAX_CPS];
char ST_Map[MAX_CPS][128];
char ST_Name[MAX_CPS][CP_NAME_LENGTH * 2];
int ST_Type[MAX_CPS];
float ST_Pos[MAX_CPS][3];
float ST_Min[MAX_CPS][3];
float ST_Max[MAX_CPS][3];

bool ST_NotSaved[MAX_CPS];

// Information Display
int UserActiveBox = -1;
bool ShowBoxes = false;
int UserTurnedOnBoxes = -1;
#define BoxFlicker 0.5

static float XAxisInfo[] =  { 75.0, 0.0, 0.0 };
static float YAxisInfo[] =  { 0.0, 75.0, 0.0 };
static float ZAxisInfo[] =  { 0.0, 0.0, 75.0 };

static char moveDist[5];

int g_sprite;

public OnMapStart()
{
	g_sprite = PrecacheModel("materials/sprites/laser.vmt");
}

public OnPluginStart()
{
	RegAdminCmd("sm_cpshow", CMD_DisplayBoxes, ADMFLAG_GENERIC, "Shows Map Control Points.");
	
	RegAdminCmd("sm_cpnew", CMD_CreateNewCP, ADMFLAG_GENERIC, "Creates a New ControlPoint which can be customized before being saved.");
	
	RegAdminCmd("sm_cpsave", CMD_SaveCPs, ADMFLAG_GENERIC, "Saves any changes made to Control Points on the map.");
	
	RegAdminCmd("sm_cpbonus", CMD_SetBonus, ADMFLAG_GENERIC, "Marks a CP as a Bonus CP.");
	RegAdminCmd("sm_cpblock", CMD_SetBlock, ADMFLAG_GENERIC, "Marks a CP as Out of Bounds CP.");
	
	RegAdminCmd("sm_cpscale", CMD_MultiplySize, ADMFLAG_GENERIC, "Increases size of the Zone in all directions by Scale.");
	
	RegAdminCmd("sm_cpdeleteall", CMD_DeleteAllCPs, ADMFLAG_GENERIC, "Removes all Saved Control Points from Map and uses map CPs to regen.");
	RegAdminCmd("sm_cpdelete", CMD_DeleteCPs, ADMFLAG_GENERIC, "Deletes the Active CP and reloads the Control Points.");
	
	RegAdminCmd("sm_cpreload", CMD_ResetCPs, ADMFLAG_GENERIC, "Reloads Saved Control Points (Restarts Plugin).");
	
	RegAdminCmd("sm_cpcancel", CMD_Cancel, ADMFLAG_GENERIC, "Destroys the last created CP if not saved.");
	
	// Rename
	RegAdminCmd("sm_cpname", CMD_RenameCP, ADMFLAG_GENERIC, "Gives a Control Point a name. (Naw)");
	
	// Shorter Move
	RegAdminCmd("sm_x", CMD_MoveX, ADMFLAG_GENERIC, "Moves X Axis in Direction (RED).");
	RegAdminCmd("sm_y", CMD_MoveY, ADMFLAG_GENERIC, "Moves Y Axis in Direction (GREEN).");
	RegAdminCmd("sm_z", CMD_MoveZ, ADMFLAG_GENERIC, "Moves Z Axis in Direction (BLUE).");
	// Shorter resize
	RegAdminCmd("sm_size", CMD_SizeCP, ADMFLAG_GENERIC, "Increases the size of the Active ControlPoint.");
	
	RegAdminCmd("sm_cpx", CMD_MoveX, ADMFLAG_GENERIC, "Moves X Axis in Direction (RED).");
	RegAdminCmd("sm_cpy", CMD_MoveY, ADMFLAG_GENERIC, "Moves Y Axis in Direction (GREEN).");
	RegAdminCmd("sm_cpz", CMD_MoveZ, ADMFLAG_GENERIC, "Moves Z Axis in Direction (BLUE).");
	RegAdminCmd("sm_cpsize", CMD_SizeCP, ADMFLAG_GENERIC, "Increases the size of the Active ControlPoint.");
	
	InitializeDataBase();
}

public ClearVariables()
{
	ShowBoxes = false;
	UserTurnedOnBoxes = -1;
	CurrentDrawnBox = 0;
	UserActiveBox = -1;
	CPCount = 0;
	
	for (int i = 0; i < MAX_CPS; i++)
	{
		Format(ST_Name[i], sizeof(ST_Name[]), "UNKNOWN");
		ST_UniqueID[i] = -1;
		ST_NotSaved[i] = false;
	}
}

public OnConfigsExecuted()
{
	GetCurrentMap(CURRENTMAP, sizeof(CURRENTMAP));
	
	ClearVariables();
	
	InitializeDataBase();
	
	CheckControlPoints();
}

public InitializeDataBase()
{
	if (CPDatabase == INVALID_HANDLE)
	{
		CPDatabase = SQL_Connect("JumpDetails", true, errorString, sizeof(errorString));
		if (CPDatabase == INVALID_HANDLE)
		{
			SetFailState(errorString);
		}
	}
}

public Action CMD_MoveX(client, args)
{
	if (args > 0)
	{
		GetCmdArg(1, moveDist, sizeof(moveDist));
		MoveCP(client, 0);
	}
	return Plugin_Handled;
}
public Action CMD_MoveY(client, args)
{
	if (args > 0)
	{
		GetCmdArg(1, moveDist, sizeof(moveDist));
		MoveCP(client, 1);
	}
	return Plugin_Handled;
}
public Action CMD_MoveZ(client, args)
{
	if (args > 0)
	{
		GetCmdArg(1, moveDist, sizeof(moveDist));
		MoveCP(client, 2);
	}
	return Plugin_Handled;
}

public MoveCP(int client, int axis)
{
	if (UserActiveBox == -1)
	{
		CPrintToChat(client, "%s[CP-Build]{WHITE} No Zone Activate.", TagColor);
	}
	else
	{
		int distance;
		distance = StringToInt(moveDist, 10);
		if (distance == 0)distance = 5;
		
		ST_NotSaved[UserActiveBox] = true;
		ST_Pos[UserActiveBox][axis] += distance;
	}
	return;
}

public Action TMR_CheckControlPoints(Handle timer) { CheckControlPoints(); }
public CheckControlPoints()
{
	// Safety First
	if (CPDatabase != INVALID_HANDLE)
	{
		static char SelectQuery[200];
		Format(SelectQuery, 200, "SELECT * FROM MapControlpoints WHERE map = '%s' ORDER BY type ASC", CURRENTMAP);
		SQL_TQuery(CPDatabase, SQL_CheckExist, SelectQuery);
	}
}

public SQL_CheckExist(Handle owner, Handle hQuery, const char[] error, any:data)
{
	if (!StrEqual("", error))
	{
		PrintToServer("SQL Error: %s", error);
		return;
	}
	// We need to create ControlPoints
	if (SQL_GetRowCount(hQuery) == 0)
	{
		CPrintToChatAll("%s[CP-Build]{WHITE} No Stored CPs, Building Control Points.", TagColor);
		BuildControlPoints();
	}
	else
	{
		PrintToConsoleAll("%s[CP-Build]{WHITE} Loading %i Control Points.", TagColor, SQL_GetRowCount(hQuery));
		int CPIndex = 0;
		while (SQL_FetchRow(hQuery))
		{
			CPIndex = CPCount;
			
			ST_UniqueID[CPIndex] = SQL_FetchInt(hQuery, 0);
			
			SQL_FetchString(hQuery, 1, ST_Map[CPIndex], sizeof(ST_Map[]));
			SQL_FetchString(hQuery, 2, ST_Name[CPIndex], sizeof(ST_Name[]));
			
			ST_Type[CPIndex] = SQL_FetchInt(hQuery, 3);
			// Pos
			ST_Pos[CPIndex][0] = SQL_FetchFloat(hQuery, 4);
			ST_Pos[CPIndex][1] = SQL_FetchFloat(hQuery, 5);
			ST_Pos[CPIndex][2] = SQL_FetchFloat(hQuery, 6);
			// X
			ST_Min[CPIndex][0] = SQL_FetchFloat(hQuery, 7);
			ST_Max[CPIndex][0] = SQL_FetchFloat(hQuery, 8);
			// Y
			ST_Min[CPIndex][1] = SQL_FetchFloat(hQuery, 9);
			ST_Max[CPIndex][1] = SQL_FetchFloat(hQuery, 10);
			// Z
			ST_Min[CPIndex][2] = SQL_FetchFloat(hQuery, 11);
			ST_Max[CPIndex][2] = SQL_FetchFloat(hQuery, 12);
			
			CPCount++;
		}
	}
}

public BuildControlPoints()
{
	bool CreatedCPs = false;
	
	int iCP = -1;
	
	float _Pos[3];
	float _Min[3];
	float _Max[3];
	int _count = 0;
	while ((iCP = FindEntityByClassname(iCP, "trigger_capture_area")) != -1)
	{
		GetEntPropVector(iCP, Prop_Send, "m_vecMins", _Min);
		GetEntPropVector(iCP, Prop_Send, "m_vecMaxs", _Max);
		// Get Position
		_Pos[0] = (_Min[0] + _Max[0]) / 2;
		_Pos[1] = (_Min[1] + _Max[1]) / 2;
		_Pos[2] = (_Min[2] + _Max[2]) / 2;
		// Set Min
		_Min[0] -= _Pos[0];
		_Min[1] -= _Pos[1];
		_Min[2] = 0.0;
		// Set Max
		_Max[0] -= _Pos[0];
		_Max[1] -= _Pos[1];
		_Max[2] -= _Pos[2];
		
		_Pos[2] -= _Max[2];
		_Max[2] *= 2.0;
		
		// Build Query
		Format(QueryString, sizeof(QueryString), "INSERT INTO MapControlpoints (map, type, PosX, PosY, PosZ, MinX, MinY, MinZ, MaxX, MaxY, MaxZ) VALUES ('%s', %i, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f)", CURRENTMAP, CP_NORMAL, _Pos[0], _Pos[1], _Pos[2], _Min[0], _Min[1], _Min[2], _Max[0], _Max[1], _Max[2]);
		SQL_TQuery(CPDatabase, SQL_EmptyCallback, QueryString, _, DBPrio_High);
		
		
		// DEBUG Info
		_count++;
		PrintToConsoleAll("CP %i Added {%0.3f, %0.3f, %0.3f}", _count, _Pos[0], _Pos[1], _Pos[2]);
		
		CreatedCPs = true;
	}
	// If we created our CPs we want to store the Info
	if (CreatedCPs)
		CreateTimer(2.0, TMR_CheckControlPoints);
}

// Empty Callback so we can Thread Queries
public SQL_EmptyCallback(Handle owner, Handle hndl, const char[] error, any:data)
{
	if (!StrEqual("", error))
	{
		PrintToServer("SQL Error: %s", error);
	}
	return;
}

public SQL_SavingCallback(Handle owner, Handle hndl, const char[] error, any:data)
{
	if (!StrEqual("", error))
	{
		CPrintToChatAll("%s[CP-Build]{RED} Error Inserting/Updating Database (Try Again?).", TagColor);
		PrintToServer("SQL Error: %s", error);
	}
	else
	{
		ST_NotSaved[data] = false;
		PrintToConsoleAll("CP %i Saved/Updated", data);
		
	}
	return;
}
public SQL_DeleteMapCP(Handle owner, Handle hndl, const char[] error, any:data)
{
	if (!StrEqual("", error))
	{
		PrintToServer("SQL Error: %s", error);
	}
	else
	{
		CPrintToChat(data, "%s[CP-Build]{WHITE} %i CPs cleared. Now Rebuilding.", TagColor, SQL_GetAffectedRows(hndl));
		ClearVariables();
		CheckControlPoints();
	}
	return;
}

public Action CMD_SizeCP(client, args)
{
	if (client == 0)
		return Plugin_Handled;
	if (UserActiveBox == -1)
	{
		CPrintToChat(client, "%s[CP-Build]{WHITE} No active zone detected.", TagColor);
		return Plugin_Handled;
	}
	
	if (args < 2)
	{
		CPrintToChat(client, "%s[CP-Build]{WHITE} More arguments required. (Check Console)", TagColor);
		PrintToConsole(client, "\nUsage: 'sm_size AXIS VALUE DIMENSION(optional)'");
		PrintToConsole(client, "Usage: 'sm_size X 50'");
		PrintToConsole(client, "-- AXIS: \t\tX Y Z");
		PrintToConsole(client, "-- VALUE: \t\tAny Numeric Value '500' '-500'");
		PrintToConsole(client, "-- DIMENSION:\n+\t Only Axis_MAX will change.\n-\t Only Axis_MIN will increase.\nNone:\t Both MIN & MAX will change.\n");
		PrintToConsole(client, "Additional Note:\nZ Axis will only update Max if no Dimension is provided.");
	}
	else
	{
		char ArgChar[10];
		// We have enough args to do stuff
		// Get Axis
		GetCmdArg(1, ArgChar, sizeof(ArgChar));
		int Axis;
		if (StrEqual(ArgChar, "X", false))
			Axis = 0;
		else if (StrEqual(ArgChar, "Y", false))
			Axis = 1;
		else if (StrEqual(ArgChar, "Z", false))
			Axis = 2;
		else
		{
			CPrintToChat(client, "%s[CP-Build]{WHITE} No Axis Detected within {YELLOW}'%s'{WHITE}, Try Again?", TagColor, ArgChar);
			return Plugin_Handled;
		}
		// Get Dimension
		int Dim = 0;
		if (args == 3)
		{
			GetCmdArg(3, ArgChar, sizeof(ArgChar));
			if (StrEqual(ArgChar, "+", false))
				Dim = 1;
			else if (StrEqual(ArgChar, "-", false))
				Dim = -1;
		}
		// Get Value
		GetCmdArg(2, ArgChar, sizeof(ArgChar));
		float AddValue = StringToFloat(ArgChar);
		if (AddValue == 0.0)
		{
			CPrintToChat(client, "%s[CP-Build]{WHITE} Can not resize Area by 0.0", TagColor);
			return Plugin_Handled;
		}
		// Add out Value
		if (Dim == -1)
		{
			ST_Min[UserActiveBox][Axis] += -AddValue;
		}
		else if (Dim == 1)
		{
			ST_Max[UserActiveBox][Axis] += AddValue;
		}
		else
		{
			// We don't want to change Z by default
			if (Axis != 2)
				ST_Min[UserActiveBox][Axis] += -AddValue;
			ST_Max[UserActiveBox][Axis] += AddValue;
		}
		ST_NotSaved[UserActiveBox] = true;
		CPrintToChat(client, "%s[CP-Build]{WHITE} Control Point Resized Successfully.", TagColor);
	}
	return Plugin_Handled;
	
}

public Action CMD_ResetCPs(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	ClearVariables();
	CheckControlPoints();
	
	return Plugin_Handled;
}

public Action CMD_DeleteAllCPs(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	Format(QueryString, sizeof(QueryString), "DELETE FROM MapControlpoints WHERE map='%s'", CURRENTMAP);
	SQL_TQuery(CPDatabase, SQL_DeleteMapCP, QueryString, client);
	
	CPrintToChat(client, "%s[CP-Build]{WHITE} Removing Map ControlPoints.", TagColor);
	return Plugin_Handled;
}

public Action CMD_DeleteCPs(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	else if (UserActiveBox == -1)
		CPrintToChat(client, "%s[CP-Build]{WHITE} No active zone detected.", TagColor);
	else
	{
		if (ST_UniqueID[UserActiveBox] < 0)
		{
			CPrintToChat(client, "%s[CP-Build]{WHITE} Can only Delete saved CPs.", TagColor);
			return Plugin_Handled;
		}
		Format(QueryString, sizeof(QueryString), "DELETE FROM MapControlpoints WHERE map='%s' AND uniqueid = %i", CURRENTMAP, ST_UniqueID[UserActiveBox]);
		SQL_TQuery(CPDatabase, SQL_DeleteMapCP, QueryString, client);
	}
	return Plugin_Handled;
}


public Action CMD_DisplayBoxes(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	ShowBoxes = !ShowBoxes;
	UserTurnedOnBoxes = client;
	if (ShowBoxes)
	{
		CreateTimer(0.1, TMR_DisplayBoxes);
		CPrintToChatAll("%s[CP-Build]{WHITE} Now Displaying CP Zones.", TagColor);
	}
	else
		CPrintToChatAll("%s[CP-Build]{WHITE} Hiding CP Zones.", TagColor);
	return Plugin_Handled;
}

public Action CMD_CreateNewCP(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	if (!ShowBoxes)
	{
		ShowBoxes = !ShowBoxes;
		CreateTimer(0.1, TMR_DisplayBoxes);
	}
	UserTurnedOnBoxes = client;
	
	if (CPCount >= MAX_CPS)
	{
		CPrintToChat(client, "%s[CP-Build]{WHITE} Reached Max CP Limit.", TagColor);
		return Plugin_Handled;
	}
	ST_NotSaved[CPCount] = true;
	
	Format(ST_Map[CPCount], sizeof(ST_Map[]), "%s", CURRENTMAP);
	Format(ST_Name[CPCount], sizeof(ST_Name[]), "UNKNOWN");
	
	ST_Type[CPCount] = view_as<int>(CP_NORMAL);
	
	float abs[3];
	GetClientAbsOrigin(UserTurnedOnBoxes, abs);
	
	ST_Pos[CPCount][0] = abs[0];
	ST_Pos[CPCount][1] = abs[1];
	ST_Pos[CPCount][2] = abs[2];
	
	ST_Min[CPCount][0] = DefaultZoneMin[0];
	ST_Min[CPCount][1] = DefaultZoneMin[1];
	ST_Min[CPCount][2] = DefaultZoneMin[2];
	
	ST_Max[CPCount][0] = DefaultZoneMax[0];
	ST_Max[CPCount][1] = DefaultZoneMax[1];
	ST_Max[CPCount][2] = DefaultZoneMax[2];
	
	CPCount++;
	if (IsClientInGame(client))
		CPrintToChat(client, "%s[CP-Build]{WHITE} Created New Control Point.", TagColor);
	return Plugin_Handled;
}

public Action CMD_Cancel(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	if (CPCount == 0)
	{
		CPrintToChat(client, "%s[CP-Build]{WHITE} Map has no Control Points.", TagColor);
		return Plugin_Handled;
	}
	else if (ST_UniqueID[CPCount - 1] != -1)
	{
		CPrintToChat(client, "%s[CP-Build]{WHITE} Can only cancel non-saved CPs.", TagColor);
		return Plugin_Handled;
	}
	else
	{
		ST_UniqueID[CPCount - 1] = -1;
		ST_NotSaved[CPCount - 1] = false;
		CPCount--;
		CPrintToChat(client, "%s[CP-Build]{WHITE} Destroyed last created Control Point.", TagColor);
		
		// Just in case it has already past the number
		CurrentDrawnBox = 0;
		return Plugin_Handled;
	}
}

public Action CMD_RenameCP(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	if (args != 1)
		CPrintToChat(client, "%s[CP-Build]{WHITE} Only pass in 1 argument, use console and use quote marks to include spaces.", TagColor);
	else if (UserActiveBox == -1)
		CPrintToChat(client, "%s[CP-Build]{WHITE} No active zone detected.", TagColor);
	else
	{
		char arg[CP_NAME_LENGTH];
		GetCmdArg(1, arg, sizeof(arg));
		Format(ST_Name[UserActiveBox], sizeof(ST_Name[]), "%s", arg);
		if (!SQL_EscapeString(CPDatabase, ST_Name[UserActiveBox], ST_Name[UserActiveBox], sizeof(ST_Name[])))
		{
			Format(ST_Name[UserActiveBox], sizeof(ST_Name[]), "UNKNOWN", arg);
			CPrintToChat(client, "%s[CP-Build]{WHITE} Failed to Rename (15 char Limit).", TagColor);
			return Plugin_Handled;
		}
		
		ST_NotSaved[UserActiveBox] = true;
		CPrintToChatAll("%s[CP-Build]{WHITE} CP %i renamed to '%s'", TagColor, UserActiveBox, ST_Name[UserActiveBox]);
	}
	return Plugin_Handled;
}

public Action CMD_MultiplySize(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	if (args != 1)
		CPrintToChat(client, "%s[CP-Build]{WHITE} Needs 1 arg passed in.", TagColor);
	else if (UserActiveBox == -1)
		CPrintToChat(client, "%s[CP-Build]{WHITE} No active zone detected.", TagColor);
	else
	{
		ST_NotSaved[UserActiveBox] = true;
		
		char arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		
		float scale = StringToFloat(arg);
		if (scale == 0.0)
		{
			CPrintToChat(client, "%s[CP-Build]{WHITE} Error Converting String to Float.", TagColor);
			return Plugin_Handled;
		}
		ScaleVector(ST_Min[UserActiveBox], scale);
		ScaleVector(ST_Max[UserActiveBox], scale);
		CPrintToChat(client, "%s[CP-Build]{WHITE} Zone Scaled.", TagColor);
	}
	return Plugin_Handled;
}

public Action CMD_SetBonus(int client, int args)
{
	SetType(client, CP_BONUS);
	return Plugin_Handled;
}

public Action CMD_SetBlock(int client, int args)
{
	SetType(client, CP_OUTOFBOUNDS);
	return Plugin_Handled;
}

public SetType(int client, CPTypes Type)
{
	if (client == 0)
		return;
	if (UserActiveBox != -1)
	{
		ST_NotSaved[UserActiveBox] = true;
		if (ST_Type[UserActiveBox] == view_as<int>(Type))
		{
			ST_Type[UserActiveBox] = view_as<int>(Type);
			CPrintToChat(client, "%s[CP-Build]{WHITE} Control Point Marked as Normal!", TagColor);
		}
		else
		{
			ST_Type[UserActiveBox] = view_as<int>(Type);
			CPrintToChat(client, "%s[CP-Build]{WHITE} Control Point Marked as %s!", TagColor, CPTypeNames[view_as<int>(Type)]);
		}
	}
}

public Action CMD_SaveCPs(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;
	
	bool Saved = false;
	
	for (int i = 0; i < CPCount; i++)
	{
		if (ST_NotSaved[i])
		{
			Saved = true;
			// Build Query
			if (ST_UniqueID[i] != -1)
			{
				Format(QueryString, sizeof(QueryString), "UPDATE MapControlpoints SET name = '%s', type = %i, PosX = %0.3f, PosY = %0.3f, PosZ = %0.3f, MinX = %0.3f, MaxX = %0.3f, MinY = %0.3f, MaxY = %0.3f, MinZ = %0.3f, MaxZ = %0.3f WHERE uniqueid = '%i'", ST_Name[i], view_as<int>(ST_Type[i]), ST_Pos[i][0], ST_Pos[i][1], ST_Pos[i][2], ST_Min[i][0], ST_Max[i][0], ST_Min[i][1], ST_Max[i][1], ST_Min[i][2], ST_Max[i][2], ST_UniqueID[i]);
			}
			else
			{
				Format(QueryString, sizeof(QueryString), "INSERT INTO MapControlpoints (map, name, type, PosX, PosY, PosZ, MinX, MaxX, MinY, MaxY, MinZ, MaxZ) VALUES ('%s', '%s', %i, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f, %0.3f)", CURRENTMAP, ST_Name[i], view_as<int>(ST_Type[i]), ST_Pos[i][0], ST_Pos[i][1], ST_Pos[i][2], ST_Min[i][0], ST_Max[i][0], ST_Min[i][1], ST_Max[i][1], ST_Min[i][2], ST_Max[i][2]);
			}
			// Finally Insert or Update whatever
			SQL_TQuery(CPDatabase, SQL_SavingCallback, QueryString, i);
		}
	}
	if (!Saved)
		CPrintToChat(client, "%s[CP-Build]{WHITE} Nothing was saved, no new Information!", TagColor);
	else
		CPrintToChat(client, "%s[CP-Build]{WHITE} Saving!", TagColor);
	
	return Plugin_Handled;
}

public Action TMR_DisplayBoxes(Handle timer)
{
	if (IsValidClient(UserTurnedOnBoxes) && IsClientInGame(UserTurnedOnBoxes))
	{
		if (ShowBoxes)
		{
			if (CPCount == 0)
				CreateTimer(BoxFlicker, TMR_DisplayBoxes);
			else
				CreateTimer(BoxFlicker / CPCount, TMR_DisplayBoxes);
		}
		float playerOrigin[3];
		GetClientAbsOrigin(UserTurnedOnBoxes, playerOrigin);
		
		static float BottomCorner[3];
		static float TopCorner[3];
		
		if (CPCount == 0)
			return;
		
		CurrentDrawnBox++;
		if (CurrentDrawnBox >= CPCount)
			CurrentDrawnBox = 0;
		
		// Check if User is closest to this Indicator
		if (GetVectorDistance(playerOrigin, ST_Pos[CurrentDrawnBox]) <= ST_Max[CurrentDrawnBox][2] * 3.0)
			UserActiveBox = CurrentDrawnBox;
		else if (UserActiveBox == CurrentDrawnBox)
			UserActiveBox = -1;
		
		AddVectors(ST_Min[CurrentDrawnBox], ST_Pos[CurrentDrawnBox], BottomCorner);
		AddVectors(ST_Max[CurrentDrawnBox], ST_Pos[CurrentDrawnBox], TopCorner);
		// Box
		if (UserActiveBox == CurrentDrawnBox)
		{
			ShowLaserBox(TopCorner, BottomCorner, colort[YEL]);
			ShowExtraInfo(UserActiveBox);
		}
		else
			ShowLaserBox(TopCorner, BottomCorner, colort[WHI]);
		// Origin
		DrawLaserRing(ST_Pos[CurrentDrawnBox], colort[WHI]);
	}
}

public ShowExtraInfo(int BoxIndex)
{
	static float CenterPoint[3];
	CenterPoint = view_as<float>( { 0.0, 0.0, 0.0 } );
	AddVectors(ST_Pos[BoxIndex], CenterPoint, CenterPoint);
	CenterPoint[2] += ST_Max[BoxIndex][2] / 2;
	
	static float XPoint[] =  { 100.0, 0.0, 0.0 };
	AddVectors(XAxisInfo, CenterPoint, XPoint);
	static float YPoint[] =  { 0.0, 100.0, 0.0 };
	AddVectors(YAxisInfo, CenterPoint, YPoint);
	static float ZPoint[] =  { 0.0, 0.0, 100.0 };
	AddVectors(ZAxisInfo, CenterPoint, ZPoint);
	
	IndicatorLaser(CenterPoint, XPoint, colort[RED], 10.0);
	IndicatorLaser(CenterPoint, YPoint, colort[GRE], 10.0);
	IndicatorLaser(CenterPoint, ZPoint, colort[BLU], 10.0);
	
	SetHudTextParams(0.35, 0.15, BoxFlicker, 255, 255, 255, 55);
	ShowHudText(UserTurnedOnBoxes, -1, "POS \tX:\t%0.3f\tY:\t%0.3f\tZ:\t%0.3f\nMIN \tX:\t%0.3f\tY:\t%0.3f\tZ:\t%0.3f\nMAX \tX:\t%0.3f\tY:\t%0.3f\tZ:\t%0.3f", ST_Pos[BoxIndex][0], ST_Pos[BoxIndex][1], ST_Pos[BoxIndex][2], ST_Min[BoxIndex][0], ST_Min[BoxIndex][1], ST_Min[BoxIndex][2], ST_Max[BoxIndex][0], ST_Max[BoxIndex][1], ST_Max[BoxIndex][2]);
	
	if (ST_NotSaved[BoxIndex])
		SetHudTextParams(0.35, 0.1, BoxFlicker, 255, 0, 0, 55);
	else
		SetHudTextParams(0.35, 0.1, BoxFlicker, 0, 255, 0, 55);
	
	ShowHudText(UserTurnedOnBoxes, -1, "Name: %s \t |ID: %i \t |Type: %s", ST_Name[BoxIndex], ST_UniqueID[BoxIndex], (ST_Type[BoxIndex] == 0 ? "Normal" : ST_Type[BoxIndex] == 1 ? "Bonus" : "Out of Bounds"));
	
}

public ShowLaserBox(const float upc[3], const float btc[3], const int color[4])
{
	// Stolen code, but edited to use modern syntax as well as optimized for my use.
	// https://github.com/zadroot/DoD_Zones/blob/master/scripting/sm_zones.sp
	static float tc1[3];
	tc1 = view_as<float>( { 0.0, 0.0, 0.0 } );
	static float tc2[3];
	tc2 = view_as<float>( { 0.0, 0.0, 0.0 } );
	static float tc3[3];
	tc3 = view_as<float>( { 0.0, 0.0, 0.0 } );
	static float tc4[3];
	tc4 = view_as<float>( { 0.0, 0.0, 0.0 } );
	static float tc5[3];
	tc5 = view_as<float>( { 0.0, 0.0, 0.0 } );
	static float tc6[3];
	tc6 = view_as<float>( { 0.0, 0.0, 0.0 } );
	
	AddVectors(tc1, upc, tc1);
	AddVectors(tc2, upc, tc2);
	AddVectors(tc3, upc, tc3);
	AddVectors(tc4, btc, tc4);
	AddVectors(tc5, btc, tc5);
	AddVectors(tc6, btc, tc6);
	
	tc1[0] = btc[0];
	tc2[1] = btc[1];
	tc3[2] = btc[2];
	tc4[0] = upc[0];
	tc5[1] = upc[1];
	tc6[2] = upc[2];
	
	
	// Draw all the edges
	PewPewLaser(upc, tc1, color);
	PewPewLaser(upc, tc2, color);
	PewPewLaser(upc, tc3, color);
	
	PewPewLaser(tc6, tc1, color);
	PewPewLaser(tc6, tc2, color);
	PewPewLaser(tc6, btc, color);
	
	PewPewLaser(tc4, btc, color);
	PewPewLaser(tc5, btc, color);
	PewPewLaser(tc5, tc1, color);
	
	PewPewLaser(tc5, tc3, color);
	PewPewLaser(tc4, tc3, color);
	PewPewLaser(tc4, tc2, color);
}

public PewPewLaser(const float start[3], const float end[3], const color[4])
{
	TE_SetupBeamPoints(start, end, g_sprite, 0, 0, 0, BoxFlicker / 1.5, 2.0, 2.0, 0, 0.1, color, 0);
	TE_SendToAll();
}

public IndicatorLaser(const float start[3], const float end[3], const color[4], float width)
{
	TE_SetupBeamPoints(start, end, g_sprite, 0, 0, 0, BoxFlicker / 1.5, width, width / 2, 0, 0.0, color, 0);
	TE_SendToAll();
}

public DrawLaserRing(const float start[3], const color[4])
{
	TE_SetupBeamRingPoint(start, 0.1, 250.0, g_sprite, 0, 0, 0, 1.5, 2.0, 0.0, color, 1.0, 0);
	TE_SendToAll();
}

bool IsValidClient(client)
{
	return (client > 0 && client <= MaxClients);
} 