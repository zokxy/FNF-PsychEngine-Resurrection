package backend;

import flixel.FlxState;

#if sys
import sys.FileSystem;
#end

class StateScriptManager
{
	public var target:FlxState;
	public var scriptName:String;
	public var isSubState:Bool;
	public var extraVars:Map<String, Dynamic>;
	public var scripts:Array<StateScript> = [];

	public function new(target:FlxState, scriptName:String, isSubState:Bool = false, ?extraVars:Map<String, Dynamic>)
	{
		this.target = target;
		this.scriptName = scriptName;
		this.isSubState = isSubState;
		this.extraVars = extraVars;
	}

	public function load():Void
	{
		#if (HSCRIPT_ALLOWED && sys)
		var loaded:Array<String> = [];
		var baseFolder:String = isSubState ? 'scripts/substates/' : 'scripts/states/';

		if (!isSubState)
			loadFromDirectory('scripts/global/', loaded);

		var dirs:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), baseFolder);
		trace('[StateScript] Searching $scriptName in: $dirs');

		for (rawDir in dirs)
		{
			var dir:String = haxe.io.Path.addTrailingSlash(rawDir);
			var singleFile:String = dir + scriptName + '.hx';
			if (FileSystem.exists(singleFile) && !FileSystem.isDirectory(singleFile))
				addScript(singleFile, loaded);

			var subDir:String = dir + scriptName + '/';
			if (FileSystem.exists(subDir) && FileSystem.isDirectory(subDir))
				loadFolderFiles(subDir, loaded);
		}
		#end
	}

	#if (HSCRIPT_ALLOWED && sys)
	function loadFromDirectory(relPath:String, loaded:Array<String>):Void
	{
		for (dir in Mods.directoriesWithFile(Paths.getSharedPath(), relPath))
			loadFolderFiles(dir, loaded);
	}

	function loadFolderFiles(rawDir:String, loaded:Array<String>):Void
	{
		var dir:String = haxe.io.Path.addTrailingSlash(rawDir);
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;
		var files:Array<String> = FileSystem.readDirectory(dir);
		files.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

		for (file in files)
		{
			if (!file.toLowerCase().endsWith('.hx')) continue;
			var fullPath:String = dir + file;
			if (!FileSystem.isDirectory(fullPath))
				addScript(fullPath, loaded);
		}
	}

	function addScript(fullPath:String, loaded:Array<String>):Void
	{
		var norm:String = fullPath.replace('\\', '/');
		if (loaded.contains(norm)) return;
		loaded.push(norm);

		var script:StateScript = new StateScript(norm, target, extraVars);
		if (script.active)
		{
			script.set('reloadScripts', reload);
			scripts.push(script);
			trace('[StateScript] Loaded: $norm');
		}
	}
	#end

	public function reload():Void
	{
		destroy(true);
		load();
		call('onCreate');
		call('onCreatePost');
		trace('[StateScript] Hot-reloaded $scriptName (${scripts.length} scripts)');
	}

	public function set(name:String, value:Dynamic):Void
	{
		for (script in scripts)
			if (script != null && script.active)
				script.set(name, value);
	}

	public function call(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		var ret:Dynamic = StateScript.Function_Continue;
		for (script in scripts)
		{
			if (script == null || !script.active) continue;
			var val:Dynamic = script.call(funcName, args);
			if (val == StateScript.Function_Stop)
				return StateScript.Function_Stop;
			if (val != null && val != StateScript.Function_Continue)
				ret = val;
		}
		return ret;
	}

	public function destroy(removeTracked:Bool = false):Void
	{
		for (script in scripts)
			if (script != null)
				script.destroy(removeTracked);
		scripts = [];
	}
}