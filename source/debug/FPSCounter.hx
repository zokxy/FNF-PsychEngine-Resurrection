package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;

class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	var _timesHead:Int = 0;
	var deltaTimeout:Float = 0.0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);

		final cutoff:Float = now - 1000;
		while (_timesHead < times.length && times[_timesHead] < cutoff)
			_timesHead++;

		if (_timesHead > 256)
		{
			times.splice(0, _timesHead);
			_timesHead = 0;
		}

		deltaTimeout += deltaTime;
		if (deltaTimeout < 200)
			return;

		var count:Int = times.length - _timesHead;
		currentFPS = count < FlxG.updateFramerate ? count : FlxG.updateFramerate;
		updateText();
		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void
	{
		var newText:String = 'FPS: ${currentFPS}\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}';
		if (text != newText)
			text = newText;

		var newColor:Int = (currentFPS < FlxG.drawFramerate * 0.5) ? 0xFFFF0000 : 0xFFFFFFFF;
		if (textColor != newColor)
			textColor = newColor;
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}