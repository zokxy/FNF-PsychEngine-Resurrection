package substates;

import backend.MusicBeatSubstate;

class ScriptedSubState extends MusicBeatSubstate
{
	public var scriptName:String;
	public var scriptArgs:Array<Dynamic>;

	public function new(scriptName:String, ?args:Array<Dynamic>)
	{
		this.scriptName = scriptName;
		this.scriptArgs = args != null ? args : [];
		super();
	}

	override function getScriptName():String
		return scriptName;

	override function getScriptExtraVars():Map<String, Dynamic>
		return ['scriptArgs' => scriptArgs];
}