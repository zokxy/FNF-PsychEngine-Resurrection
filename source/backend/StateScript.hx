package backend;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import objects.Alphabet;
import objects.Character;
import objects.HealthIcon;
import states.FreeplayState;
import states.MainMenuState;
import states.PlayState;
import states.ScriptedState;
import states.StoryMenuState;
import states.TitleState;
import substates.ScriptedSubState;

#if sys
import sys.FileSystem;
import sys.io.File;
#else
import openfl.utils.Assets;
#end

#if HSCRIPT_ALLOWED
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig.RawIrisConfig;
#end

class StateScript
{
	public static final Function_Stop:Dynamic = "##STATE_SCRIPT_STOP";
	public static final Function_Continue:Dynamic = "##STATE_SCRIPT_CONTINUE";
	public static var allowFileSystem:Bool = #if debug true #else false #end;

	public var path:String;
	public var target:FlxState;
	public var active:Bool = true;
	public var trackedObjects:Array<FlxBasic> = [];
	public var trackedTweens:Array<FlxTween> = [];
	public var trackedTimers:Array<FlxTimer> = [];

	#if HSCRIPT_ALLOWED
	public var iris:Iris;
	#end

	public function new(path:String, target:FlxState, ?extraVars:Map<String, Dynamic>)
	{
		this.path = path;
		this.target = target;

		#if HSCRIPT_ALLOWED
		try
		{
			var code:String = #if sys File.getContent(path) #else Assets.getText(path) #end;
			var cfg:RawIrisConfig = {name: path, autoRun: false, autoPreset: true};
			iris = new Iris(code, cfg);
			bindGlobals();

			if (extraVars != null)
				for (k => v in extraVars)
					iris.set(k, v);

			iris.execute();
		}
		catch (e:IrisError)
		{
			active = false;
			Iris.error(Printer.errorToString(e, false), cast {fileName: path, showLine: false});
			destroy(false);
		}
		catch (e:Dynamic)
		{
			active = false;
			Iris.error('Failed to load: $e', cast {fileName: path, showLine: false});
			destroy(false);
		}
		#else
		active = false;
		#end
	}

	function trackTween(twn:FlxTween):FlxTween
	{
		if (twn != null && !trackedTweens.contains(twn))
			trackedTweens.push(twn);
		return twn;
	}

	function trackTimer(tmr:FlxTimer):FlxTimer
	{
		if (tmr != null && !trackedTimers.contains(tmr))
			trackedTimers.push(tmr);
		return tmr;
	}

	function bindGlobals():Void
	{
		#if HSCRIPT_ALLOWED
		if (iris == null) return;

		iris.set('Function_Stop', Function_Stop);
		iris.set('Function_Continue', Function_Continue);

		iris.set('state', target);
		iris.set('members', target.members);
		iris.set('controls', Controls.instance);

		iris.set('add', function(obj:FlxBasic):FlxBasic
		{
			if (obj != null && !trackedObjects.contains(obj))
				trackedObjects.push(obj);
			return target.add(obj);
		});
		iris.set('insert', function(pos:Int, obj:FlxBasic):FlxBasic
		{
			if (obj != null && !trackedObjects.contains(obj))
				trackedObjects.push(obj);
			return target.insert(pos, obj);
		});
		iris.set('remove', function(obj:FlxBasic, splice:Bool = false):FlxBasic
		{
			trackedObjects.remove(obj);
			return target.remove(obj, splice);
		});
		iris.set('trackTween', trackTween);
		iris.set('trackTimer', trackTimer);
		iris.set('startTimer', function(time:Float = 1, ?onComplete:FlxTimer->Void, loops:Int = 1):FlxTimer
		{
			return trackTimer(new FlxTimer().start(time, onComplete, loops));
		});
		iris.set('openSubState', function(sub:FlxSubState):Void target.openSubState(sub));
		iris.set('closeSubState', function():Void target.closeSubState());
		if (Std.isOfType(target, FlxSubState))
			iris.set('close', function():Void cast(target, FlxSubState).close());

		iris.set('switchState', function(next:FlxState):Void MusicBeatState.switchState(next));
		iris.set('resetState', function():Void MusicBeatState.resetState());
		iris.set('openScriptedState', function(name:String, ?args:Array<Dynamic>):Void ScriptedState.open(name, args));
		iris.set('openScriptedSubState', function(name:String, ?args:Array<Dynamic>):Void target.openSubState(new ScriptedSubState(name, args)));

		iris.set('FlxG', FlxG);
		iris.set('FlxBasic', FlxBasic);
		iris.set('FlxObject', FlxObject);
		iris.set('FlxSprite', FlxSprite);
		iris.set('FlxText', FlxText);
		iris.set('FlxCamera', FlxCamera);
		iris.set('FlxGroup', FlxGroup);
		iris.set('FlxTypedGroup', FlxTypedGroup);
		iris.set('FlxSpriteGroup', FlxSpriteGroup);
		iris.set('FlxTimer', FlxTimer);
		iris.set('FlxEase', FlxEase);
		iris.set('FlxMath', FlxMath);
		iris.set('FlxSound', FlxSound);
		iris.set('FlxTween', {
			PERSIST: FlxTweenType.PERSIST,
			LOOPING: FlxTweenType.LOOPING,
			PINGPONG: FlxTweenType.PINGPONG,
			ONESHOT: FlxTweenType.ONESHOT,
			BACKWARD: FlxTweenType.BACKWARD,
			globalManager: FlxTween.globalManager,
			tween: function(obj:Dynamic, values:Dynamic, duration:Float = 1, ?options:TweenOptions):FlxTween
				return trackTween(FlxTween.tween(obj, values, duration, options)),
			num: function(fromValue:Float, toValue:Float, duration:Float = 1, ?options:TweenOptions, ?tweenFunction:Float->Void):FlxTween
				return trackTween(FlxTween.num(fromValue, toValue, duration, options, tweenFunction)),
			color: function(sprite:FlxSprite, duration:Float = 1, fromColor:FlxColor, toColor:FlxColor, ?options:TweenOptions):FlxTween
				return trackTween(FlxTween.color(sprite, duration, fromColor, toColor, options)),
			angle: function(sprite:FlxSprite, fromAngle:Float, toAngle:Float, duration:Float = 1, ?options:TweenOptions):FlxTween
				return trackTween(FlxTween.angle(sprite, fromAngle, toAngle, duration, options)),
			cancelTweensOf: FlxTween.cancelTweensOf,
			completeTweensOf: FlxTween.completeTweensOf
		});

		iris.set('FlxAxes', {X: FlxAxes.X, Y: FlxAxes.Y, XY: FlxAxes.XY});
		iris.set('FlxTextAlign', {LEFT: FlxTextAlign.LEFT, CENTER: FlxTextAlign.CENTER, RIGHT: FlxTextAlign.RIGHT, JUSTIFY: FlxTextAlign.JUSTIFY});
		iris.set('FlxTextBorderStyle', {NONE: FlxTextBorderStyle.NONE, SHADOW: FlxTextBorderStyle.SHADOW, OUTLINE: FlxTextBorderStyle.OUTLINE, OUTLINE_FAST: FlxTextBorderStyle.OUTLINE_FAST});
		iris.set('FlxColor', {
			TRANSPARENT: FlxColor.TRANSPARENT,
			WHITE: FlxColor.WHITE,
			GRAY: FlxColor.GRAY,
			BLACK: FlxColor.BLACK,
			GREEN: FlxColor.GREEN,
			LIME: FlxColor.LIME,
			YELLOW: FlxColor.YELLOW,
			ORANGE: FlxColor.ORANGE,
			RED: FlxColor.RED,
			PURPLE: FlxColor.PURPLE,
			BLUE: FlxColor.BLUE,
			BROWN: FlxColor.BROWN,
			PINK: FlxColor.PINK,
			MAGENTA: FlxColor.MAGENTA,
			CYAN: FlxColor.CYAN,
			fromRGB: FlxColor.fromRGB,
			fromRGBFloat: FlxColor.fromRGBFloat,
			fromHSB: FlxColor.fromHSB,
			fromString: FlxColor.fromString,
			interpolate: FlxColor.interpolate
		});

		iris.set('Paths', Paths);
		iris.set('ClientPrefs', ClientPrefs);
		iris.set('Conductor', Conductor);
		iris.set('Mods', Mods);
		iris.set('CoolUtil', CoolUtil);
		iris.set('Difficulty', Difficulty);
		iris.set('Song', Song);
		iris.set('Highscore', Highscore);
		iris.set('StageData', StageData);
		iris.set('MusicBeatState', MusicBeatState);
		iris.set('MusicBeatSubstate', MusicBeatSubstate);
		iris.set('PlayState', PlayState);
		iris.set('TitleState', TitleState);
		iris.set('MainMenuState', MainMenuState);
		iris.set('FreeplayState', FreeplayState);
		iris.set('StoryMenuState', StoryMenuState);
		iris.set('ScriptedState', ScriptedState);
		iris.set('ScriptedSubState', ScriptedSubState);
		iris.set('Character', Character);
		iris.set('HealthIcon', HealthIcon);
		iris.set('Alphabet', Alphabet);

		iris.set('Json', Json);
		iris.set('Std', Std);
		iris.set('Math', Math);
		iris.set('StringTools', StringTools);
		iris.set('Reflect', Reflect);
		iris.set('Type', Type);
		#if sys
		if (allowFileSystem)
		{
			iris.set('File', File);
			iris.set('FileSystem', FileSystem);
		}
		#end
		#end
	}

	public function set(name:String, value:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		if (active && iris != null)
			iris.set(name, value);
		#end
	}

	public function exists(funcName:String):Bool
	{
		#if HSCRIPT_ALLOWED
		return active && iris != null && iris.exists(funcName);
		#else
		return false;
		#end
	}

	public function call(funcName:String, ?args:Array<Dynamic>):Dynamic
	{
		#if HSCRIPT_ALLOWED
		if (!active || iris == null || !iris.exists(funcName))
			return Function_Continue;

		try
		{
			var res = iris.call(funcName, args != null ? args : []);
			return res != null ? res.returnValue : Function_Continue;
		}
		catch (e:IrisError)
		{
			Iris.error(Printer.errorToString(e, false), cast {fileName: path, showLine: false});
		}
		catch (e:Dynamic)
		{
			Iris.error('Error in $funcName: $e', cast {fileName: path, showLine: false});
		}
		#end
		return Function_Continue;
	}

	public function destroy(removeTracked:Bool = false):Void
	{
		if (active)
			call('onDestroy');

		active = false;

		for (twn in trackedTweens)
			if (twn != null && !twn.finished) twn.cancel();
		trackedTweens = [];

		for (tmr in trackedTimers)
			if (tmr != null && !tmr.finished) tmr.cancel();
		trackedTimers = [];

		if (removeTracked && target != null)
		{
			for (obj in trackedObjects)
			{
				if (obj == null) continue;
				var inState:Bool = target.members != null && target.members.contains(obj);
				if (inState) target.remove(obj, true);
				if (inState || obj.exists)
				{
					FlxTween.cancelTweensOf(obj);
					try { obj.destroy(); } catch (_:Dynamic) {}
				}
			}
		}
		trackedObjects = [];

		#if HSCRIPT_ALLOWED
		if (iris != null)
		{
			iris.destroy();
			iris = null;
		}
		#end
	}
}