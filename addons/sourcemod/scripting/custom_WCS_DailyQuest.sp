// List of Includes
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;


// Config Convars
Handle cvar_GiveLevelsToRace;
Handle cvar_GiveRandomQuestReward;
Handle cvar_QuestRewardSameLevels;
Handle cvar_QuestRewardRandomMinLevels;
Handle cvar_QuestRewardRandomMaxLevels;
Handle cvar_QuestCompleteSound;

// Global char variables
char StartDate[32];
char ResetDate[MAXPLAYERS + 1][64];

// Cookie Variables
Handle cvar_QuestCookie;


// The retrievable information about the plugin itself 
public Plugin myinfo = 
{
	name		= "[CS:GO] Daily Quest",
	author		= "Manifest @Road To Glory",
	description = "Typing !quest completes the daily quest, awarding players with WCS levels.", 
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Registers the commands we wish for players to be able to use
	RegConsoleCmd("sm_quest", AcceptDailyQuest);
	RegConsoleCmd("sm_dailyquest", AcceptDailyQuest);

	// The list of convars which we'll use to adjust features through our auto generated config file
	cvar_GiveLevelsToRace = CreateConVar("Mani_GiveLevelsToRace", "1", "Give the levels awarded from completing the daily quest to the player's current race - [Give To Current Race = 1 | Give To WCS Bank = 0]");
	cvar_GiveRandomQuestReward = CreateConVar("Mani_GiveRandomQuestReward", "1", "Give players a random amount of levels when completing the daily quest - [Yes = 1 | No = 0]");
	cvar_QuestRewardRandomMinLevels = CreateConVar("Mani_QuestRewardRandomMinLevels", "5", "When random quest rewards are enabled, then this defines the minimum amount of levels a player can receive when they complete their daily quest - [Default = 5]");
	cvar_QuestRewardRandomMaxLevels = CreateConVar("Mani_QuestRewardRandomMaxLevels", "10", "When random quest rewards are enabled, then this defines the maximum amount of levels a player can receive when they complete their daily quest - [Default = 10]");
	cvar_QuestRewardSameLevels = CreateConVar("Mani_DailyQuestLevels", "5", "When random quest rewards are DISABLED, then this defines the amount of levels the player will receive when they complete their daily quest - [Default = 5]");
	cvar_QuestCompleteSound = CreateConVar("Mani_QuestCompleteSound", "1", "Play a sound for the player when the player completes the daily quest - [Yes = 1 | No = 0]");

	// Cookie Stuff
	cvar_QuestCookie = RegClientCookie("Mani_DailyQuestDate", "Cookie for daily credits last used date.", CookieAccess_Protected);

	// Loops through all of the clients on our server
	for(int i = 1 ;i <= MaxClients; i++)
	{
		// If the client's cookies isn't cached, then execute this section
		if (!AreClientCookiesCached(i))
		{
			// Calls upon our OnClientCookiesCached function to cache our client's cookies
			OnClientCookiesCached(i);
		}
	}

	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "custom_WCS_DailyQuest");

	// If the QuestCompleteSound is enabled then execute this section
	if (cvar_QuestCompleteSound)
	{
		// Precaches our sound files
		PrecacheSound("manifest/QuestCompleted.wav");
	}

	// Loads the multi-language translation file
	LoadTranslations("custom_WCS_DailyQuest.phrases");
}


// This happens when the map is loaded 
public void OnMapStart()
{
	// If the QuestCompleteSound is enabled then execute this section
	if (cvar_QuestCompleteSound)
	{
		// Precaches our sound files
		PrecacheSound("manifest/QuestCompleted.wav");

		// Adds our custom sound files to the download tables
		AddFileToDownloadsTable("sound/manifest/QuestCompleted.wav");
	}
}


public void OnClientCookiesCached(int client)
{
	// Get saved date on client connecting
	GetClientCookie(client, cvar_QuestCookie, ResetDate[client], sizeof(ResetDate[]));
}


public Action AcceptDailyQuest(int client, int args)
{
	// If the player matches our criterias for validation then execute this section
	if (IsValidClient(client)) 
	{
		// Save current date in variable
		FormatTime(StartDate, sizeof(StartDate), "%Y%m%d");

		// If there are not set a reset date yet, then execute this section
		if (StrEqual(ResetDate[client], ""))
		{
			// Calls upon our GrantDailyQuestReward function
			GrantDailyQuestReward(client);

			return Plugin_Handled;
		}

		// If 1 day or more has passed then execute this section
		if (StringToInt(StartDate) - StringToInt(ResetDate[client]) >= 1)
		{
			// Calls upon our GrantDailyQuestReward function
			GrantDailyQuestReward(client);

			return Plugin_Handled;
		}

		// Elsewise execute this section
		else
		{
			// Sends two messages in the chat to the player, letting the player know the daily quest only can be done once a day
			CPrintToChat(client, "%t", "Daily Quest Already Completed");
			CPrintToChat(client, "%t", "Daily Quest Unlocks Later");

			return Plugin_Handled;
		}
	}
	else
	{
		return Plugin_Handled;
	}
}


public Action GrantDailyQuestReward(int client)
{
	// Creates a variable named userid, which we'll use to award our player with experience through a source-python command
	int userid = GetClientUserId(client);

	// Creates a variable named ServerCommandMessage which we'll store our message data within
	char ServerCommandMessage[128];

	// Obtains the value of the convar GiveRandomQuestReward and store it within our variable RandomQuestReward
	int RandomQuestReward = GetConVarInt(cvar_GiveRandomQuestReward);
	
	// Creates an integer variable named QuestReward which we'll use to store our level data within
	int QuestReward;
	
	// If the amount of levels awarded for completing the quest is random then execute this section
	if (RandomQuestReward)
	{
		// Picks a random number between the two variables
		QuestReward = GetRandomInt(GetConVarInt(cvar_QuestRewardRandomMinLevels), GetConVarInt(cvar_QuestRewardRandomMaxLevels));
	}
	else
	{
		// Obtains the value of the Convar and store the value within our variable QuestReward
		QuestReward = GetConVarInt(cvar_QuestRewardSameLevels);
	}

	// Obtains the value of the convar cvar_GiveLevelsToRace and store it within our variable GiveLevelsType
	int GiveLevelsType = GetConVarInt(cvar_GiveLevelsToRace);
	
	// If the levels should be given to the player's current race then execute this section
	if (GiveLevelsType)
	{
		// Formats a message and store it within our ServerCommandMessage variable
		FormatEx(ServerCommandMessage, sizeof(ServerCommandMessage), "wcs_givelevel %i %i", userid, QuestReward);

		// Prints a message to the client's chat letting them know they received the daily quest reward
		CPrintToChat(client, "%t", "Daily Quest Reward Race", QuestReward);
	}
	else
	{
		// Formats a message and store it within our ServerCommandMessage variable
		FormatEx(ServerCommandMessage, sizeof(ServerCommandMessage), "wcs_levelbank_givelevel %i %i", userid, QuestReward);

		// Prints a message to the client's chat letting them know they received the daily quest reward
		CPrintToChat(client, "%t", "Daily Quest Reward Bank", QuestReward);
	}

	// Executes our GiveLevel server command on the player, to award them with levels
	ServerCommand(ServerCommandMessage);

	// Changes the client's cookie so he cannot just use this command again right afterwards
	SetClientCookie(client, cvar_QuestCookie, StartDate);

	// Formats the time
	Format(ResetDate[client], sizeof(ResetDate[]), StartDate);

	// If the QuestCompleteSound is enabled then execute this section
	if (cvar_QuestCompleteSound)
	{
		// Plays the quest completion sound for the player
		ClientCommand(client, "play */manifest/QuestCompleted.wav");
	}
}


// We call upon this true and false statement whenever we wish to validate our player
bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}